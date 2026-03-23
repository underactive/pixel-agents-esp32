import Foundation

/// Derives agent state from Gemini CLI session records.
///
/// Gemini sessions are stored as monolithic JSON files (not JSONL). The TranscriptWatcher
/// extracts individual messages from the `messages` array and passes them here one at a time.
///
/// Tool calls appear in the `toolCalls` array within gemini-type messages. Reading tools
/// (web_fetch, google_web_search, read_file, list_directory) produce READ state; all other
/// tools produce TYPE state. Text-only gemini responses also produce TYPE (agent generating).
enum GeminiStateDeriver {

    private static let readingTools: Set<String> = [
        "web_fetch", "google_web_search", "read_file", "list_directory"
    ]

    /// Derive the agent state from a single Gemini session message record.
    /// Returns (state, toolName) or nil if no state change.
    static func derive(from record: [String: Any], agent: inout Agent) -> (CharState, String)? {
        guard let type = record["type"] as? String else { return nil }

        if type == "gemini" {
            // Check for tool calls
            if let toolCalls = record["toolCalls"] as? [[String: Any]], !toolCalls.isEmpty {
                // Use the last tool call for display
                let lastTool = toolCalls[toolCalls.count - 1]
                let toolName = (lastTool["displayName"] as? String)
                    ?? (lastTool["name"] as? String)
                    ?? "Tool"
                let truncated = String(toolName.prefix(24))

                // Classify as read or type based on tool name
                let rawName = (lastTool["name"] as? String) ?? ""
                if readingTools.contains(rawName) {
                    agent.hadToolInTurn = true
                    agent.activeTools.insert(rawName)
                    return (.read, truncated)
                }
                agent.hadToolInTurn = true
                agent.activeTools.insert(rawName)
                return (.type, truncated)
            }

            // Gemini message without tool calls — agent is generating text
            agent.hadToolInTurn = true
            return (.type, "Gemini")
        }

        if type == "user" {
            // User message means the agent's turn is over
            agent.hadToolInTurn = false
            agent.activeTools.removeAll()
            return (.idle, "")
        }

        return nil
    }
}
