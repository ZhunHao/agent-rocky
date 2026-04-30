import Foundation

/// Wraps the `claude` CLI process kept alive for the app's lifetime.
/// Mirrors the reference (lil-agents) IO pattern: pipes' readabilityHandler
/// fires on a background thread, then dispatches to a serial queue for
/// in-order line buffering and parsing. The actor receives complete lines.
actor ClaudeCLIAdapter: AgentSession {
    let provider: AgentProvider = .claude

    nonisolated let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var state: SessionState = .idle

    private let parser = StreamJsonParser()
    private let personaPrompt: String

    /// Serial queue that owns line-buffer ordering. All readabilityHandler
    /// chunks land here in arrival order, get appended to the buffer, and any
    /// complete lines are forwarded to the actor.
    private nonisolated(unsafe) var lineBuffer = ""
    private nonisolated let ioQueue = DispatchQueue(
        label: "agentrocky.claude.io", qos: .userInitiated
    )

    init(personaPrompt: String) {
        self.personaPrompt = personaPrompt
        var cont: AsyncStream<AgentEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { c in cont = c }
        self.continuation = cont
    }

    func start() async throws {
        guard state == .idle else { return }
        state = .starting

        let path = await ShellEnvironment.findBinary(
            name: "claude",
            fallbackPaths: [
                "~/.local/bin/claude",
                "~/.claude/local/bin/claude",
                "/usr/local/bin/claude",
                "/opt/homebrew/bin/claude",
            ]
        )
        guard let path else {
            state = .failed("claude not found")
            continuation.yield(.error(.providerNotAvailable(.claude)))
            return
        }
        try launchProcess(at: path)
    }

    func send(_ message: String) async throws {
        guard state == .ready else { throw AgentError.sessionBusy }
        state = .busy

        let payload: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": [["type": "text", "text": message]]
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            state = .ready
            throw AgentError.streamCorrupt(detail: "could not encode user message")
        }
        let line = json + "\n"
        guard let pipe = stdinPipe else {
            state = .ready
            throw AgentError.sessionDied(reason: "stdin pipe missing")
        }
        do {
            try pipe.fileHandleForWriting.write(contentsOf: Data(line.utf8))
        } catch {
            state = .ready
            throw AgentError.streamCorrupt(detail: "stdin write failed: \(error.localizedDescription)")
        }
    }

    func cancelCurrentTurn() async {
        process?.interrupt()
    }

    func terminate() async {
        process?.terminate()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        try? stdinPipe?.fileHandleForWriting.close()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }

    // MARK: - Private

    private func launchProcess(at binaryPath: String) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose",
            "--dangerously-skip-permissions",
            "--append-system-prompt", personaPrompt,
        ]
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        proc.environment = ShellEnvironment.processEnvironment()

        let inP = Pipe(), outP = Pipe(), errP = Pipe()
        proc.standardInput = inP
        proc.standardOutput = outP
        proc.standardError = errP

        // Capture nonisolated state for the readability closures.
        let queue = ioQueue
        let cont = continuation
        let parser = parser
        let bufferRef = LineBufferRef()

        outP.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            queue.async { [weak self] in
                bufferRef.buffer.append(text)
                while let nl = bufferRef.buffer.firstIndex(of: "\n") {
                    let line = String(bufferRef.buffer[..<nl])
                    bufferRef.buffer.removeSubrange(...nl)
                    if line.isEmpty { continue }
                    for event in parser.feed(line + "\n") {
                        cont.yield(event)
                        // Hop to the actor to keep `state` in sync.
                        Task { [weak self] in await self?.observeEventForState(event) }
                    }
                }
            }
        }
        errP.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData    // drain so pipe doesn't fill
        }
        proc.terminationHandler = { [weak self] _ in
            Task { [weak self] in await self?.handleTermination() }
        }

        do {
            try proc.run()
        } catch {
            state = .failed("process failed to start")
            continuation.yield(.error(.processStartFailed(detail: error.localizedDescription)))
            return
        }

        process = proc
        stdinPipe = inP
        stdoutPipe = outP
        stderrPipe = errP
        state = .ready
    }

    /// Update internal state based on observed events. Called from the IO queue's
    /// Task hop — runs on the actor so it can mutate `state` safely.
    fileprivate func observeEventForState(_ event: AgentEvent) {
        switch event {
        case .sessionReady, .turnComplete:
            state = .ready
        case .sessionEnded:
            state = .terminated
        default: break
        }
    }

    private func handleTermination() {
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }
}

/// Reference-typed wrapper so the line buffer can be mutated from inside a
/// nonescaping serial-queue closure without making the whole adapter Sendable-unsafe.
/// Synchronization comes from the queue itself (serial), not from the box.
private final class LineBufferRef: @unchecked Sendable {
    var buffer: String = ""
}
