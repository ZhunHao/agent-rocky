import Foundation

nonisolated enum SlashCommand: String, CaseIterable, Equatable, Sendable {
    case clear = "/clear"
    case copy  = "/copy"
    case help  = "/help"

    var helpText: String {
        switch self {
        case .clear: return "/clear — wipe the transcript and reset the agent's context"
        case .copy:  return "/copy — copy Rocky's last response to the clipboard"
        case .help:  return "/help — show available slash commands"
        }
    }
}

nonisolated enum DispatchResult: Equatable, Sendable {
    case command(SlashCommand)
    case unknownCommand(String)
    case message(String)
}

/// Pure routing function: take a raw user input string, classify as either a slash
/// command (recognized or unknown) or a plain message that should go to the agent.
nonisolated struct CommandDispatcher: Sendable {
    func interpret(_ input: String) -> DispatchResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .message(trimmed)
        }
        if let cmd = SlashCommand(rawValue: trimmed) {
            return .command(cmd)
        }
        return .unknownCommand(trimmed)
    }

    static var helpMessage: String {
        SlashCommand.allCases.map(\.helpText).joined(separator: "\n")
    }
}
