import Foundation
import Observation
import AppKit

/// Mediates between an AgentSession (event stream) and the SwiftUI TerminalView (transcript).
/// Single consumer of `session.events`. Spec §5.
@Observable
@MainActor
final class ChatViewModel {

    private(set) var transcript: [AgentMessage] = []
    private(set) var isBusy: Bool = false
    private(set) var inputDisabled: Bool = false
    var inputText: String = ""

    /// Append a message from outside the view model (e.g. setup-time errors).
    func appendSystem(_ text: String, role: AgentMessage.Role = .error) {
        transcript.append(.init(role: role, text: text))
    }

    private var session: (any AgentSession)?
    private var consumeTask: Task<Void, Never>?
    private var inProgressAssistantID: AgentMessage.ID?

    private let dispatcher = CommandDispatcher()

    func attach(_ session: any AgentSession) {
        consumeTask?.cancel()
        self.session = session
        let stream = session.events
        consumeTask = Task { @MainActor [weak self] in
            for await event in stream {
                self?.handle(event)
            }
        }
    }

    func submit() async {
        let raw = inputText
        inputText = ""

        switch dispatcher.interpret(raw) {
        case .command(.clear):
            transcript = []
            inProgressAssistantID = nil
            // Forward a real /clear to Claude so its conversation context resets too.
            // The adapter sends it as a normal user message; Claude Code recognizes it.
            if let session {
                Task { try? await session.send("/clear") }
            }
        case .command(.copy):
            if let last = transcript.last(where: { $0.role == .assistant }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(last.text, forType: .string)
            }
        case .command(.help):
            transcript.append(.init(role: .system, text: CommandDispatcher.helpMessage))
        case .unknownCommand(let s):
            transcript.append(.init(role: .system, text: "unknown command: \(s) — try /help"))
        case .message(""):
            return
        case .message(let s):
            await sendToSession(s)
        }
    }

    private func sendToSession(_ message: String) async {
        guard let session else { return }
        transcript.append(.init(role: .user, text: message))
        isBusy = true
        inputDisabled = true
        do {
            try await session.send(message)
        } catch let err as AgentError {
            transcript.append(.init(role: .error, text: errorDescription(err)))
            isBusy = false
            inputDisabled = false
        } catch {
            transcript.append(.init(role: .error, text: "Unexpected error: \(error)"))
            isBusy = false
            inputDisabled = false
        }
    }

    private func handle(_ event: AgentEvent) {
        switch event {
        case .sessionReady:
            isBusy = false
            inputDisabled = false

        case .textDelta(let s):
            if inProgressAssistantID == nil {
                let msg = AgentMessage(role: .assistant, text: "")
                inProgressAssistantID = msg.id
                transcript.append(msg)
            }
            if let id = inProgressAssistantID,
               let idx = transcript.firstIndex(where: { $0.id == id }) {
                transcript[idx].text += s
            }

        case .turnComplete:
            inProgressAssistantID = nil
            isBusy = false
            inputDisabled = false

        case .error(let err):
            transcript.append(.init(role: .error, text: errorDescription(err)))
            inProgressAssistantID = nil
            isBusy = false
            inputDisabled = false

        case .toolCall, .toolResult:
            // v1: silently ignore. v2: render inline.
            break

        case .sessionEnded:
            isBusy = false
            inputDisabled = true
        }
    }

    private func errorDescription(_ err: AgentError) -> String {
        switch err {
        case .providerNotAvailable(let p): return p.installInstructions
        case .sessionBusy:                 return "Rocky's still working on the previous question."
        case .contextWindowExceeded:       return "Rocky's memory is full — type /clear to start fresh."
        case .rateLimited:                 return "Rocky needs a moment — try again."
        case .processStartFailed(let d):   return "Couldn't start Rocky's connection: \(d)"
        case .sessionDied(let r):          return "Rocky's connection died: \(r)"
        case .streamCorrupt(let d):        return "Communication problem with Rocky: \(d)"
        case .other(let s):                return s
        }
    }
}
