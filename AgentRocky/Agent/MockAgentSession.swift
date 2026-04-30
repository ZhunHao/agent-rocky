import Foundation

/// In-memory mock that echoes user messages back as fake streamed responses.
/// Used in M2 for UI iteration without CLI complexity.
actor MockAgentSession: AgentSession {
    let provider: AgentProvider = .claude
    private(set) var state: SessionState = .idle
    private(set) var history: [AgentMessage] = []

    nonisolated let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    init() {
        var cont: AsyncStream<AgentEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { c in cont = c }
        self.continuation = cont
    }

    func start() async throws {
        state = .starting
        try await Task.sleep(nanoseconds: 200_000_000)
        state = .ready
        continuation.yield(.sessionReady)
    }

    func send(_ message: String) async throws {
        guard state == .ready else { throw AgentError.sessionBusy }
        state = .busy
        history.append(.init(role: .user, text: message))

        let response = "Questioner. You said: \"\(message)\". Understood. Good. Good."
        for char in response {
            try await Task.sleep(nanoseconds: 30_000_000)   // ~33 chars/sec
            continuation.yield(.textDelta(String(char)))
        }
        history.append(.init(role: .assistant, text: response))
        continuation.yield(.turnComplete)
        state = .ready
    }

    func cancelCurrentTurn() async {
        // Mock has nothing to cancel mid-stream; no-op.
    }

    func terminate() async {
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }
}
