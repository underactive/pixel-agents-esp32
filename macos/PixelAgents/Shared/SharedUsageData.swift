import Foundation
import SwiftUI

/// Codable mirror of UsageStatsData for App Group transfer.
struct SharedProviderUsage: Codable, Equatable {
    let currentPct: UInt8
    let weeklyPct: UInt8
    let currentResetMin: UInt16
    let weeklyResetMin: UInt16
}

/// Provider identity shared between main app and widget.
enum WidgetProvider: String, CaseIterable, Codable, Identifiable {
    case claude, codex, gemini, cursor
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex:  return "Codex"
        case .gemini: return "Gemini"
        case .cursor: return "Cursor"
        }
    }

    var usageDefaultsKey: String {
        switch self {
        case .claude: return SharedUsageKeys.claudeUsage
        case .codex:  return SharedUsageKeys.codexUsage
        case .gemini: return SharedUsageKeys.geminiUsage
        case .cursor: return SharedUsageKeys.cursorUsage
        }
    }

    var heatmapDBKey: String {
        switch self {
        case .claude: return "claude"
        case .codex:  return "codex"
        case .gemini: return "gemini"
        case .cursor: return "cursor_agent"
        }
    }

    var brandColor: Color {
        switch self {
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:  return Color(red: 0.24, green: 0.47, blue: 0.96)
        case .gemini: return Color(red: 1.0, green: 0.42, blue: 0.61)
        case .cursor: return Color(red: 0.22, green: 0.83, blue: 0.33)
        }
    }

    var heatmapColors: [Color] {
        switch self {
        case .claude: return [
            Color.gray.opacity(0.15),
            Color(red: 0.361, green: 0.145, blue: 0.094),
            Color(red: 0.545, green: 0.220, blue: 0.125),
            Color(red: 0.753, green: 0.353, blue: 0.204),
            Color(red: 0.850, green: 0.470, blue: 0.340),
        ]
        case .codex: return [
            Color.gray.opacity(0.15),
            Color(red: 0.059, green: 0.118, blue: 0.290),
            Color(red: 0.106, green: 0.208, blue: 0.471),
            Color(red: 0.173, green: 0.361, blue: 0.773),
            Color(red: 0.240, green: 0.470, blue: 0.960),
        ]
        case .gemini: return [
            Color.gray.opacity(0.15),
            Color(red: 0.353, green: 0.098, blue: 0.176),
            Color(red: 0.576, green: 0.176, blue: 0.318),
            Color(red: 0.820, green: 0.310, blue: 0.478),
            Color(red: 1.0, green: 0.420, blue: 0.612),
        ]
        case .cursor: return [
            Color.gray.opacity(0.15),
            Color(red: 0.055, green: 0.267, blue: 0.161),
            Color(red: 0.0, green: 0.427, blue: 0.196),
            Color(red: 0.149, green: 0.651, blue: 0.255),
            Color(red: 0.224, green: 0.827, blue: 0.325),
        ]
        }
    }

    /// Brand icon SVG path data for this provider.
    var brandIcon: String {
        switch self {
        case .claude: return BrandIcon.claude
        case .codex:  return BrandIcon.codex
        case .gemini: return BrandIcon.gemini
        case .cursor: return BrandIcon.cursor
        }
    }
}
