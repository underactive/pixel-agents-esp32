import Foundation

/// Derives agent state from Cursor IDE JSONL transcript records.
///
/// Cursor transcripts are chat-only (role: user/assistant with text content).
/// Unlike Claude Code or Codex CLI, Cursor does not log tool_use events,
/// so we can only detect "agent is responding" vs "waiting for user input".
enum CursorStateDeriver {

    /// Derive the agent state from a single Cursor JSONL record.
    /// Returns (state, toolName) or nil if no state change.
    static func derive(from record: [String: Any], agent: inout Agent) -> (CharState, String)? {
        guard let role = record["role"] as? String else { return nil }

        if role == "assistant" {
            // Verify there's actual content (not an empty message)
            if let message = record["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]],
               content.contains(where: { ($0["type"] as? String) == "text" }) {
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
