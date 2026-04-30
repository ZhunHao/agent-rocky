import Foundation

/// Async availability probe for AgentProviders. Cached on first call; call invalidate() to re-probe.
actor ProviderDetector {
    private var availability: [AgentProvider: Bool] = [:]

    func detectAvailable() async -> [AgentProvider: Bool] {
        if !availability.isEmpty { return availability }

        async let claudeAvail = probeClaude()
        async let fmAvail = probeFoundationModels()

        availability[.claude] = await claudeAvail
        availability[.foundationModels] = await fmAvail
        return availability
    }

    func invalidate() { availability.removeAll() }

    private func probeClaude() async -> Bool {
        let path = await ShellEnvironment.findBinary(
            name: "claude",
            fallbackPaths: [
                "~/.local/bin/claude",
                "~/.claude/local/bin/claude",
                "/usr/local/bin/claude",
                "/opt/homebrew/bin/claude",
            ]
        )
        return path != nil
    }

    private func probeFoundationModels() async -> Bool {
        // M4 will fill this in. For now, FoundationModels is unavailable.
        return false
    }
}
