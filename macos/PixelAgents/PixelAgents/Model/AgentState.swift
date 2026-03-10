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

/// Tracks a single Claude Code agent session
struct Agent: Identifiable {
    let id: UInt8
    var state: CharState = .idle
    var toolName: String = ""
    var lastSeen: Date = Date()
    var activeTools: Set<String> = []
    var hadToolInTurn: Bool = false
}
