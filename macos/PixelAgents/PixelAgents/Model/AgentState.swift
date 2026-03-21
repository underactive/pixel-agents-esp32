import Foundation

/// Character states matching firmware CharState enum in config.h
enum CharState: UInt8, CaseIterable {
    case offline = 0
    case idle    = 1
    case walk    = 2
    case type    = 3
    case read    = 4
    case spawn   = 5
    case despawn = 6

    var label: String {
        switch self {
        case .offline: return "Off"
        case .idle:    return "Ready"
        case .walk:    return "Walking"
        case .type:    return "Typing"
        case .read:    return "Reading"
        case .spawn:   return "Spawning"
        case .despawn: return "Despawning"
        }
    }
}

/// Identifies the source of a transcript file.
enum TranscriptSource: Equatable {
    case claude
    case codex
}

/// Tracks a single Claude Code agent session
struct Agent: Identifiable, Equatable {
    let id: UInt8
    var state: CharState = .idle
    var toolName: String = ""
    var source: TranscriptSource = .claude
    var lastSeen: Date = Date()
    var activeTools: Set<String> = []
    var hadToolInTurn: Bool = false

    /// Compare only display-relevant fields; internal tracking state (lastSeen, activeTools, hadToolInTurn) is excluded.
    static func == (lhs: Agent, rhs: Agent) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state && lhs.toolName == rhs.toolName && lhs.source == rhs.source
    }
}
