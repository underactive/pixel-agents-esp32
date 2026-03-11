import Foundation

/// Derives agent state from OpenAI Codex CLI rollout JSONL records.
/// Handles both `codex exec --json` event format and `RolloutLine` envelope format.
enum CodexStateDeriver {

    /// Shell commands that indicate reading behavior.
    private static let readingCommands: Set<String> = [
        "cat", "head", "tail", "less", "more", "grep", "rg",
        "find", "ls", "tree", "wc", "file", "stat", "diff"
    ]

    /// Maximum tool name length (must match protocol limit).
    private static let maxToolNameLen = 24

    /// Derive the agent state from a single Codex rollout JSONL record.
    /// Returns (state, toolName) or nil if no state change.
    static func derive(from record: [String: Any], agent: inout Agent) -> (CharState, String)? {
        guard let type = record["type"] as? String else { return nil }

        // ── codex exec --json format ──────────────────────────
        if type == "item.started" || type == "item.completed" {
            guard let item = record["item"] as? [String: Any],
                  let itemType = item["type"] as? String else { return nil }

            switch itemType {
            case "command_execution":
                let command = item["command"] as? String ?? ""
                let label = toolLabel(from: command)
                agent.hadToolInTurn = true
                agent.activeTools.insert(label)
                if isReadCommand(command) {
                    return (.read, label)
                }
                return (.type, label)

            case "file_change":
                agent.hadToolInTurn = true
                agent.activeTools.insert("Edit")
                return (.type, "Edit")

            case "mcp_tool_call":
                let tool = item["tool"] as? String ?? "tool"
                let label = String(tool.prefix(maxToolNameLen))
                agent.hadToolInTurn = true
                agent.activeTools.insert(label)
                return (.type, label)

            case "web_search":
                agent.hadToolInTurn = true
                agent.activeTools.insert("WebSearch")
                return (.read, "WebSearch")

            default:
                // agent_message, reasoning, todo_list — no state change
                return nil
            }
        }

        if type == "turn.completed" {
            agent.hadToolInTurn = false
            agent.activeTools.removeAll()
            return (.idle, "")
        }

        if type == "turn.started" {
            return nil
        }

        // ── RolloutLine envelope format ───────────────────────
        if type == "ResponseItem" {
            let payload = record["payload"] as? [String: Any] ?? record
            if let payloadType = payload["type"] as? String, payloadType == "function_call" {
                let name = payload["name"] as? String ?? "tool"
                let label = String(name.prefix(maxToolNameLen))
                agent.hadToolInTurn = true
                agent.activeTools.insert(label)
                return (.type, label)
            }
            return nil
        }

        if type == "EventMsg" {
            let payload = record["payload"] as? [String: Any] ?? record
            let msgType = payload["type"] as? String ?? ""
            if msgType == "turn_complete" || msgType == "turn.completed" {
                agent.hadToolInTurn = false
                agent.activeTools.removeAll()
                return (.idle, "")
            }
            return nil
        }

        return nil
    }

    // MARK: - Helpers

    /// Strip bash prefix and surrounding quotes from a Codex shell command.
    private static func stripCommand(_ command: String) -> String {
        var cmd = command
        if cmd.hasPrefix("bash ") {
            let parts = cmd.split(separator: " ", maxSplits: 2).map(String.init)
            cmd = parts.last ?? cmd
        }
        cmd = cmd.trimmingCharacters(in: .whitespaces)
        if cmd.count >= 2 {
            let first = cmd.first!, last = cmd.last!
            if (first == "'" && last == "'") || (first == "\"" && last == "\"") {
                cmd = String(cmd.dropFirst().dropLast())
            }
        }
        return cmd
    }

    /// Extract a short label from a Codex shell command for display.
    private static func toolLabel(from command: String) -> String {
        let cmd = stripCommand(command)
        let firstWord = cmd.trimmingCharacters(in: .whitespaces)
            .split(separator: " ").first.map(String.init) ?? "shell"
        let baseName = firstWord.split(separator: "/").last.map(String.init) ?? firstWord
        return String(baseName.prefix(maxToolNameLen))
    }

    /// Check if a Codex shell command is a read-like operation.
    private static func isReadCommand(_ command: String) -> Bool {
        let cmd = stripCommand(command)
        let firstWord = cmd.trimmingCharacters(in: .whitespaces)
            .split(separator: " ").first.map(String.init) ?? ""
        let baseName = firstWord.split(separator: "/").last.map(String.init) ?? firstWord
        return readingCommands.contains(baseName)
    }
}
