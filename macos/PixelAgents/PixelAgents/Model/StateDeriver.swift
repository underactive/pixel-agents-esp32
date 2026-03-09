import Foundation

/// Derives agent state from JSONL transcript records.
/// Direct port of derive_state() from pixel_agents_bridge.py.
enum StateDeriver {

    /// Tools that indicate reading behavior (vs typing/writing)
    static let readingTools: Set<String> = ["Read", "Grep", "Glob", "WebFetch", "WebSearch"]

    /// Derive the agent state from a single JSONL record.
    /// Returns (state, toolName) or nil if no state change.
    static func derive(from record: [String: Any], agent: inout Agent) -> (CharState, String)? {
        guard let type = record["type"] as? String else { return nil }

        if type == "assistant" {
            guard let message = record["message"] as? [String: Any] else { return nil }
            let content = message["content"] as? [[String: Any]] ?? []

            // Check for tool_use blocks
            for block in content {
                if let blockType = block["type"] as? String, blockType == "tool_use" {
                    let toolName = block["name"] as? String ?? ""
                    agent.hadToolInTurn = true
                    agent.activeTools.insert(toolName)

                    if readingTools.contains(toolName) {
                        return (.read, toolName)
                    } else {
                        return (.type, toolName)
                    }
                }
            }

            // Check for end_turn stop reason
            if let stopReason = message["stop_reason"] as? String, stopReason == "end_turn" {
                agent.hadToolInTurn = false
                agent.activeTools.removeAll()
                return (.idle, "")
            }

            return nil
        }

        if type == "system" {
            // turn_duration present means turn is complete
            if record["turn_duration"] != nil {
                agent.hadToolInTurn = false
                agent.activeTools.removeAll()
                return (.idle, "")
            }
        }

        return nil
    }
}
