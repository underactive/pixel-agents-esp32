import Foundation

/// Derives agent state from OpenAI Codex CLI rollout JSONL records.
/// Handles three formats: `codex exec --json` events, current snake_case rollout,
/// and legacy PascalCase `RolloutLine` envelopes.
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

        // ── Current rollout format (snake_case) ───────────────
        if type == "response_item" {
            let payload = record["payload"] as? [String: Any] ?? record
            guard let payloadType = payload["type"] as? String else { return nil }

            if payloadType == "function_call" {
                let name = payload["name"] as? String ?? "tool"
                if name == "exec_command" {
                    let command = parseExecCommandArgs(payload)
                    let label = command.isEmpty ? "exec_command" : toolLabel(from: command)
                    agent.hadToolInTurn = true
                    agent.activeTools.insert(label)
                    if !command.isEmpty && isReadCommand(command) {
                        return (.read, label)
                    }
                    return (.type, label)
                } else {
                    let label = String((name.isEmpty ? "tool" : name).prefix(maxToolNameLen))
                    agent.hadToolInTurn = true
                    agent.activeTools.insert(label)
                    return (.type, label)
                }
            }

            if payloadType == "custom_tool_call" {
                let name = payload["name"] as? String ?? "tool"
                let label = String((name.isEmpty ? "tool" : name).prefix(maxToolNameLen))
                agent.hadToolInTurn = true
                agent.activeTools.insert(label)
                return (.type, label)
            }

            if payloadType == "web_search_call" {
                agent.hadToolInTurn = true
                agent.activeTools.insert("WebSearch")
                return (.read, "WebSearch")
            }

            // reasoning, message, *_output — no state change
            return nil
        }

        if type == "event_msg" {
            let payload = record["payload"] as? [String: Any] ?? record
            let payloadType = payload["type"] as? String ?? ""
            if payloadType == "task_complete" || payloadType == "turn_aborted" {
                agent.hadToolInTurn = false
                agent.activeTools.removeAll()
                return (.idle, "")
            }
            // task_started, agent_reasoning, token_count, etc. — no state change
            return nil
        }

        // session_meta, turn_context, compacted — no state change
        if type == "session_meta" || type == "turn_context" || type == "compacted" {
            return nil
        }

        // ── Legacy RolloutLine envelope format (PascalCase) ───
        if type == "ResponseItem" {
            let payload = record["payload"] as? [String: Any] ?? record
            if let payloadType = payload["type"] as? String, payloadType == "function_call" {
                let name = payload["name"] as? String ?? "tool"
                let label = String((name.isEmpty ? "tool" : name).prefix(maxToolNameLen))
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

    /// Parse the `cmd` field from an `exec_command` function_call's `arguments`.
    /// The `arguments` field may be a JSON string or a dict.
    private static func parseExecCommandArgs(_ payload: [String: Any]) -> String {
        if let argsStr = payload["arguments"] as? String, !argsStr.isEmpty {
            guard let data = argsStr.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cmd = parsed["cmd"] as? String else {
                return ""
            }
            return cmd
        }
        if let argsDict = payload["arguments"] as? [String: Any] {
            return argsDict["cmd"] as? String ?? ""
        }
        return ""
    }

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
