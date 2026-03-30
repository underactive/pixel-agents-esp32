import Foundation
import WidgetKit

/// Writes usage stats to the App Group shared container so the widget extension can read them.
@MainActor
enum WidgetDataWriter {

    private static let encoder = JSONEncoder()
    private static var lastWritten: [String: SharedProviderUsage] = [:]

    /// Write all current usage stats to shared UserDefaults and trigger widget refresh.
    static func writeUsageStats(
        claude: UsageStatsData?,
        codex: UsageStatsData?,
        gemini: UsageStatsData?,
        cursor: UsageStatsData?
    ) {
        guard let defaults = AppGroupConstants.sharedDefaults else { return }

        var changed = false
        changed = writeProvider(claude, key: SharedUsageKeys.claudeUsage, defaults: defaults) || changed
        changed = writeProvider(codex, key: SharedUsageKeys.codexUsage, defaults: defaults) || changed
        changed = writeProvider(gemini, key: SharedUsageKeys.geminiUsage, defaults: defaults) || changed
        changed = writeProvider(cursor, key: SharedUsageKeys.cursorUsage, defaults: defaults) || changed

        if changed {
            defaults.set(Date().timeIntervalSince1970, forKey: SharedUsageKeys.lastUpdated)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func writeProvider(_ stats: UsageStatsData?, key: String, defaults: UserDefaults) -> Bool {
        let shared: SharedProviderUsage? = stats.map {
            SharedProviderUsage(currentPct: $0.currentPct, weeklyPct: $0.weeklyPct,
                                currentResetMin: $0.currentResetMin, weeklyResetMin: $0.weeklyResetMin)
        }

        // Skip write if unchanged
        if shared == lastWritten[key] { return false }
        lastWritten[key] = shared

        if let shared = shared {
            defaults.set(try? encoder.encode(shared), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        return true
    }
}
