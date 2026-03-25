import Foundation

/// Usage statistics for an AI provider (Claude, Codex, Gemini, Cursor).
struct UsageStatsData: Equatable {
    let currentPct: UInt8
    let weeklyPct: UInt8
    let currentResetMin: UInt16
    let weeklyResetMin: UInt16

    /// Sentinel value for enabled providers with no data yet.
    static let zero = UsageStatsData(currentPct: 0, weeklyPct: 0, currentResetMin: 0, weeklyResetMin: 0)
}

/// Reads ~/.claude/rate-limits-cache.json and produces UsageStatsData.
enum UsageStatsReader {
    private static let cachePath: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/rate-limits-cache.json")

    /// Read and parse the rate limits cache. Returns nil if file missing or invalid.
    static func read() -> UsageStatsData? {
        guard let data = try? Data(contentsOf: cachePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let currentPct = clampPct(json["current_pct"])
        let weeklyPct = clampPct(json["weekly_pct"])
        let currentResetMin = minutesUntilReset(json["current_resets_at"])
        let weeklyResetMin = minutesUntilReset(json["weekly_resets_at"])

        return UsageStatsData(
            currentPct: currentPct,
            weeklyPct: weeklyPct,
            currentResetMin: currentResetMin,
            weeklyResetMin: weeklyResetMin
        )
    }

    private static func clampPct(_ value: Any?) -> UInt8 {
        guard let num = value as? NSNumber else { return 0 }
        return UInt8(min(max(num.intValue, 0), 100))
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func minutesUntilReset(_ value: Any?) -> UInt16 {
        guard let str = value as? String else { return 0 }

        let date = isoFormatter.date(from: str) ?? isoFormatterNoFrac.date(from: str)
        guard let resetDate = date else { return 0 }

        let minutes = resetDate.timeIntervalSinceNow / 60.0
        let clamped = max(0.0, min(minutes, Double(UInt16.max)))
        return UInt16(clamped)
    }
}
