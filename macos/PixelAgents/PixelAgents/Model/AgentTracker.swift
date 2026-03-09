import Foundation

/// Manages the lifecycle of Claude Code agents. Keyed by project path.
final class AgentTracker {
    private(set) var agents: [String: Agent] = [:]
    private var nextId: UInt8 = 0

    /// Retrieve or create an agent for the given project key (transcript file path).
    func getOrCreate(key: String) -> Agent {
        if let existing = agents[key] {
            return existing
        }
        let agent = Agent(id: nextId)
        nextId &+= 1 // wraps at 256
        agents[key] = agent
        return agent
    }

    /// Update an agent in place.
    func update(key: String, _ mutate: (inout Agent) -> Void) {
        guard agents[key] != nil else { return }
        mutate(&agents[key]!)
    }

    /// Remove agents not seen for `timeout` seconds. Returns the removed agents.
    @discardableResult
    func pruneStale(timeout: TimeInterval) -> [Agent] {
        let cutoff = Date().addingTimeInterval(-timeout)
        var pruned: [Agent] = []
        for (key, agent) in agents {
            if agent.lastSeen < cutoff {
                pruned.append(agent)
                agents.removeValue(forKey: key)
            }
        }
        return pruned
    }

    /// Number of tracked agents.
    var count: Int { agents.count }

    /// All agents sorted by ID for display.
    var sortedAgents: [Agent] {
        agents.values.sorted { $0.id < $1.id }
    }

    /// Reset all tracking state (on reconnect).
    func reset() {
        agents.removeAll()
        nextId = 0
    }
}
