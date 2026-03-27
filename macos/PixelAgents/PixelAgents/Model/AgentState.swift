import Foundation
import SwiftUI

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
    case gemini
    case cursor

    /// Database provider key for local activity heatmap storage.
    var heatmapKey: String? {
        switch self {
        case .claude: return "claude"
        case .codex:  return "codex"
        case .gemini: return "gemini"
        case .cursor: return "cursor_agent"
        }
    }
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

    /// SVG path data for the agent's source brand icon.
    var brandIcon: String {
        switch source {
        case .claude: return BrandIcon.claude
        case .codex:  return BrandIcon.codex
        case .gemini: return BrandIcon.gemini
        case .cursor: return BrandIcon.cursor
        }
    }

    /// Brand color matching the provider's usage progress bar.
    var brandColor: Color {
        switch source {
        case .claude: return claudeOrange
        case .codex:  return codexBlue
        case .gemini: return geminiPink
        case .cursor: return cursorGreen
        }
    }

    /// Compare only display-relevant fields; internal tracking state (lastSeen, activeTools, hadToolInTurn) is excluded.
    static func == (lhs: Agent, rhs: Agent) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state && lhs.toolName == rhs.toolName && lhs.source == rhs.source
    }
}
