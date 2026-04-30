import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device LLM adapter using Apple FoundationModels.
/// Spec §6. macOS 26+ only.
@available(macOS 26.0, *)
actor FoundationModelsAdapter: AgentSession {
    let provider: AgentProvider = .foundationModels

    private(set) var state: SessionState = .idle
    private(set) var history: [AgentMessage] = []

    nonisolated let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    private let personaPrompt: String
    private var currentTask: Task<Void, Never>?

    init(personaPrompt: String) {
        self.personaPrompt = personaPrompt
        var cont: AsyncStream<AgentEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { c in cont = c }
        self.continuation = cont
    }

    static func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return true
        default: return false
        }
        #else
        return false
        #endif
    }

    func start() async throws {
        guard state == .idle else { return }
        state = .starting

        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            let s = LanguageModelSession(instructions: personaPrompt)
            s.prewarm()
            session = s
            state = .ready
            continuation.yield(.sessionReady)
        default:
            state = .failed("FoundationModels unavailable")
            continuation.yield(.error(.providerNotAvailable(.foundationModels)))
        }
        #else
        state = .failed("FoundationModels not compiled")
        continuation.yield(.error(.providerNotAvailable(.foundationModels)))
        #endif
    }

    func send(_ message: String) async throws {
        guard state == .ready else { throw AgentError.sessionBusy }
        state = .busy
        history.append(.init(role: .user, text: message))

        #if canImport(FoundationModels)
        guard let session else {
            state = .ready
            throw AgentError.sessionDied(reason: "session missing")
        }

        currentTask = Task { [weak self] in
            await self?.streamResponse(session: session, prompt: message)
        }
        #else
        state = .ready
        continuation.yield(.error(.providerNotAvailable(.foundationModels)))
        #endif
    }

    #if canImport(FoundationModels)
    private func streamResponse(session: LanguageModelSession, prompt: String) async {
        var lastSnapshot = ""
        do {
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                guard !Task.isCancelled else {
                    state = .ready
                    return
                }
                let full = snapshot.content
                let delta = String(full.dropFirst(lastSnapshot.count))
                if !delta.isEmpty {
                    continuation.yield(.textDelta(delta))
                }
                lastSnapshot = full
            }
            continuation.yield(.turnComplete)
            state = .ready
        } catch let err as LanguageModelSession.GenerationError {
            state = .ready
            continuation.yield(.error(mapError(err)))
        } catch {
            state = .ready
            continuation.yield(.error(.other(error.localizedDescription)))
        }
    }

    private func mapError(_ err: LanguageModelSession.GenerationError) -> AgentError {
        switch err {
        case .concurrentRequests:        return .sessionBusy
        case .exceededContextWindowSize: return .contextWindowExceeded
        case .rateLimited:               return .rateLimited
        case .assetsUnavailable:         return .providerNotAvailable(.foundationModels)
        @unknown default:                return .other(String(describing: err))
        }
    }
    #endif

    nonisolated func cancelCurrentTurn() {
        Task { await self._cancel() }
    }

    private func _cancel() {
        currentTask?.cancel()
    }

    func terminate() {
        currentTask?.cancel()
        #if canImport(FoundationModels)
        session = nil
        #endif
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }

    /// /clear semantics for FM — recreate the inner LanguageModelSession.
    /// The outer adapter (and its events stream) stays alive.
    func resetContext() async {
        #if canImport(FoundationModels)
        let s = LanguageModelSession(instructions: personaPrompt)
        s.prewarm()
        session = s
        #endif
    }
}
