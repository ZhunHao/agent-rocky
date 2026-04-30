import Foundation

// MARK: - Public protocol

/// One adapter per LLM provider. M2 ships only the models + a mock impl;
/// real Claude/FoundationModels adapters land in M3/M4.
///
/// The `events` stream is single-consumer (typical for AsyncStream) and stays open
/// for the entire session lifetime. terminate() closes it.
nonisolated protocol AgentSession: AnyObject, Sendable {
    var provider: AgentProvider { get }
    var events: AsyncStream<AgentEvent> { get }

    func start() async throws
    func send(_ message: String) async throws
    func cancelCurrentTurn() async
    func terminate() async
}

// MARK: - Models (all nonisolated — pure value types crossing actor boundaries)

nonisolated enum SessionState: Sendable, Equatable {
    case idle, starting, ready, busy, terminated
    case failed(String)
}

nonisolated enum AgentEvent: Sendable {
    case sessionReady
    case textDelta(String)
    case toolCall(name: String, summary: String)
    case toolResult(name: String, success: Bool)
    case turnComplete
    case error(AgentError)
    case sessionEnded
}

nonisolated struct AgentMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date

    nonisolated enum Role: String, Sendable, Equatable {
        case user, assistant, system, error
    }

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

nonisolated enum AgentError: Error, Sendable, Equatable {
    case providerNotAvailable(AgentProvider)
    case sessionBusy
    case contextWindowExceeded
    case rateLimited
    case processStartFailed(detail: String)
    case sessionDied(reason: String)
    case streamCorrupt(detail: String)
    case other(String)
}
