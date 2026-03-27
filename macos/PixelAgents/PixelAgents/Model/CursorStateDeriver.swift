import Foundation

/// Derives agent state from Cursor agent CLI JSONL transcript records.
///
/// Cursor agent transcripts use the same tool_use content block format as Claude Code:
/// `{"role":"assistant","message":{"content":[{"type":"tool_use","name":"Shell",...}]}}`.
/// For non-agent Cursor sessions (text-only, no tool_use blocks), falls back to
/// returning (.type, "Cursor") to animate the character without counting tool calls.
enum CursorStateDeriver {

    /// Tools that indicate reading behavior (vs typing/writing).
    /// Matches StateDeriver.readingTools for consistency.
    static let readingTools: Set<String> = ["Read", "Grep", "Glob", "WebFetch", "WebSearch"]

    /// Derive the agent state from a single Cursor JSONL record.
    /// Returns (state, toolName) or nil if no state change.
    static func derive(from record: [String: Any], agent: inout Agent) -> (CharState, String)? {
        guard let role = record["role"] as? String else { return nil }

        if role == "assistant" {
            guard let message = record["message"] as? [String: Any] else { return nil }
            let content = message["content"] as? [[String: Any]] ?? []

            // Check for tool_use blocks first (agent CLI sessions)
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

            // Fallback: text-only content (non-agent Cursor sessions)
            if content.contains(where: { ($0["type"] as? String) == "text" }) {
                agent.hadToolInTurn = true
                return (.type, "Cursor")
            }

            return nil
        }

        if role == "user" {
            // User message means the agent's turn is over
            agent.hadToolInTurn = false
            agent.activeTools.removeAll()
            return (.idle, "")
        }

        return nil
    }
}
