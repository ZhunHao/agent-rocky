import Foundation

nonisolated enum AgentProvider: String, CaseIterable, Sendable, Equatable {
    case claude
    case foundationModels

    var displayName: String {
        switch self {
        case .claude:           return "Claude Code"
        case .foundationModels: return "FoundationModels (on-device)"
        }
    }

    var installInstructions: String {
        switch self {
        case .claude:
            return """
            Claude Code CLI not found. Install with:

              curl -fsSL https://claude.ai/install.sh | sh

            Then quit and relaunch AgentRocky.
            """
        case .foundationModels:
            return """
            Apple FoundationModels requires macOS 26+ on Apple Silicon
            with Apple Intelligence enabled in System Settings.
            """
        }
    }
}
