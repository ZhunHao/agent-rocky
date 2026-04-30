import Foundation

/// Discovers the user's shell PATH and locates CLI binaries.
/// Ported from lil-agents (MIT) — same approach, modernized to use async/await.
nonisolated enum ShellEnvironment {

    /// Environment dictionary suitable for spawning child processes.
    /// Includes a PATH that mirrors the user's interactive shell so commands
    /// like `claude`, `node`, `python` etc. resolve the same way they do in
    /// Terminal.app.
    static func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let shell = env["SHELL"],
           let interactivePath = capturePathFromShell(shell),
           !interactivePath.isEmpty {
            env["PATH"] = interactivePath
        }
        return env
    }

    /// Locates `name` in PATH; falls back to user-provided paths if not found.
    static func findBinary(name: String, fallbackPaths: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = locateBinaryBlocking(name: name, fallbackPaths: fallbackPaths)
                continuation.resume(returning: result)
            }
        }
    }

    private static func locateBinaryBlocking(name: String, fallbackPaths: [String]) -> String? {
        // Try `which` with the interactive shell PATH
        if let whichOut = runProcessSync(
            executable: "/usr/bin/which",
            arguments: [name],
            env: processEnvironment()
        ),
        !whichOut.isEmpty,
        FileManager.default.isExecutableFile(atPath: whichOut) {
            return whichOut
        }
        // Fallback paths
        for candidate in fallbackPaths {
            let expanded = (candidate as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }
        return nil
    }

    private static func capturePathFromShell(_ shell: String) -> String? {
        runProcessSync(
            executable: shell,
            arguments: ["-l", "-i", "-c", "echo $PATH"],
            env: ProcessInfo.processInfo.environment
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runProcessSync(
        executable: String,
        arguments: [String],
        env: [String: String]
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = env
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
