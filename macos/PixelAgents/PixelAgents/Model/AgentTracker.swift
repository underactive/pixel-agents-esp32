import Foundation

/// Manages the lifecycle of Claude Code agents. Keyed by project path.
/// Agent IDs are recycled when agents are pruned (LIFO) to keep IDs low,
/// preventing the monotonic counter from exceeding the firmware's int8_t limit (0-127).
final class AgentTracker {
    private(set) var agents: [String: Agent] = [:]
    private var nextId: UInt8 = 0
    private var recycledIds: [UInt8] = []

    /// Retrieve or create an agent for the given project key (transcript file path).
    func getOrCreate(key: String, source: TranscriptSource = .claude) -> Agent {
        if let existing = agents[key] {
            return existing
        }
        let id: UInt8
        if let recycled = recycledIds.popLast() {
            id = recycled
        } else {
            id = nextId
            nextId &+= 1 // wraps at 256
        }
        let agent = Agent(id: id, source: source)
        agents[key] = agent
        return agent
    }

    /// Update an agent in place.
    func update(key: String, _ mutate: (inout Agent) -> Void) {
        guard var agent = agents[key] else { return }
        mutate(&agent)
        agents[key] = agent
    }

    /// Remove agents not seen for `timeout` seconds. Returns the removed agents.
    @discardableResult
    func pruneStale(timeout: TimeInterval) -> [Agent] {
        let cutoff = Date().addingTimeInterval(-timeout)
        var pruned: [Agent] = []
        let staleKeys = agents.filter { $0.value.lastSeen < cutoff }.map { $0.key }
        for key in staleKeys {
            if let agent = agents.removeValue(forKey: key) {
                pruned.append(agent)
                recycledIds.append(agent.id)
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
        recycledIds.removeAll()
        nextId = 0
    }
}
