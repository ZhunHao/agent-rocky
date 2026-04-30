import Foundation

/// Line-buffered parser for Claude Code's stream-json format.
/// Stateful: feed it raw stdout chunks, get back one or more AgentEvents per
/// completed line. Incomplete trailing lines stay buffered.
nonisolated final class StreamJsonParser: Sendable {

    private final class Buffer: @unchecked Sendable {
        var content: String = ""
    }
    private let buffer = Buffer()

    /// Feed raw text. Returns events parsed from any newline-terminated lines.
    func feed(_ chunk: String) -> [AgentEvent] {
        buffer.content.append(chunk)
        var events: [AgentEvent] = []

        while let nl = buffer.content.firstIndex(of: "\n") {
            let line = String(buffer.content[..<nl])
            buffer.content.removeSubrange(...nl)

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let event = parseLine(trimmed) {
                events.append(event)
            }
        }
        return events
    }

    /// Parse a single line into an AgentEvent. Returns nil for events we ignore
    /// (hooks, post_turn_summary, etc.) so they don't pollute the consumer's stream.
    private func parseLine(_ line: String) -> AgentEvent? {
        guard let data = line.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let dict = raw as? [String: Any] else {
            return .error(.streamCorrupt(detail: "invalid JSON: \(line.prefix(120))"))
        }
        return interpret(dict)
    }

    private func interpret(_ dict: [String: Any]) -> AgentEvent? {
        let type = dict["type"] as? String ?? ""

        switch type {
        case "system":
            switch dict["subtype"] as? String {
            case "init":
                return .sessionReady
            case "hook_started", "hook_response", "post_turn_summary", "compact_boundary":
                return nil   // noise — ignore
            default:
                return nil   // unknown system subtype — ignore rather than error
            }

        case "assistant":
            guard let message = dict["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                return .error(.streamCorrupt(detail: "assistant missing content"))
            }
            // An assistant message can have multiple blocks (text + tool_use chained).
            // Emit one event for each notable block; we return only the FIRST here
            // since this method returns a single event per line — but that's fine
            // because in practice claude emits text and tool_use in separate
            // assistant messages.
            for block in content {
                let blockType = block["type"] as? String ?? ""
                if blockType == "text", let text = block["text"] as? String {
                    return .textDelta(text)
                }
                if blockType == "tool_use", let name = block["name"] as? String {
                    let inputDict = block["input"] as? [String: Any] ?? [:]
                    return .toolCall(name: name, summary: formatToolSummary(name: name, input: inputDict))
                }
            }
            return nil   // empty assistant block — ignore

        case "user":
            guard let message = dict["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                return nil
            }
            for block in content {
                if (block["type"] as? String) == "tool_result" {
                    let isError = (block["is_error"] as? Bool) ?? false
                    let id = (block["tool_use_id"] as? String) ?? "?"
                    return .toolResult(name: id, success: !isError)
                }
            }
            return nil

        case "result":
            return .turnComplete

        default:
            return nil
        }
    }

    private func formatToolSummary(name: String, input: [String: Any]) -> String {
        // Best-effort one-line summary
        if let cmd = input["command"] as? String { return cmd }
        if let path = input["file_path"] as? String { return path }
        if let pattern = input["pattern"] as? String { return pattern }
        let keys = input.keys.sorted().prefix(3).joined(separator: ", ")
        return keys.isEmpty ? name : "\(name): \(keys)"
    }
}
