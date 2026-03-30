import Foundation

/// Per-day activity for the local tool-call heatmap.
struct ActivityHeatmapDay: Equatable {
    let date: Date     // midnight-aligned (start of day)
    let count: Int     // tool calls recorded that day
}

/// Aggregated heatmap data for Claude/Codex/Gemini tool-call contribution grids.
/// Parallel to CursorHeatmapData but built from local SQLite storage instead of an external API.
struct ActivityHeatmapData: Equatable {
    /// Sparse map of midnight-aligned date → tool call count.
    let days: [Date: Int]
    let totalCount: Int
    let mostActiveDay: ActivityHeatmapDay?
    let currentStreak: Int   // consecutive days with activity ending today or yesterday
    let longestStreak: Int

    /// Pre-computed quartile thresholds (p25, p50, p75) for 4-level color mapping.
    let thresholdP25: Int
    let thresholdP50: Int
    let thresholdP75: Int

    /// Map a tool call count to a color level (0-4).
    func level(for count: Int) -> Int {
        guard count > 0 else { return 0 }
        if count >= thresholdP75 { return 4 }
        if count >= thresholdP50 { return 3 }
        if count >= thresholdP25 { return 2 }
        return 1
    }

    /// Compute quartile thresholds from non-zero day values.
    static func computeThresholds(from days: [Date: Int]) -> (Int, Int, Int) {
        let nonZero = days.values.filter { $0 > 0 }.sorted()
        guard !nonZero.isEmpty else { return (1, 2, 3) }
        let p25 = nonZero[nonZero.count / 4]
        let p50 = nonZero[nonZero.count / 2]
        let p75 = nonZero[nonZero.count * 3 / 4]
        return (max(1, p25), max(2, p50), max(3, p75))
    }

    /// Empty heatmap (no data recorded yet).
    static let empty = ActivityHeatmapData(
        days: [:], totalCount: 0, mostActiveDay: nil,
        currentStreak: 0, longestStreak: 0,
        thresholdP25: 1, thresholdP50: 2, thresholdP75: 3
    )
}

// MARK: - Builder

extension ActivityHeatmapData {
    /// Build from SQLite rows of (date string "YYYY-MM-DD", count).
    static func from(rows: [(String, Int)]) -> ActivityHeatmapData {
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        var days: [Date: Int] = [:]
        var total = 0
        var bestDay: ActivityHeatmapDay?

        for (dateStr, count) in rows {
            guard count > 0, let parsed = formatter.date(from: dateStr) else { continue }
            let midnight = calendar.startOfDay(for: parsed)

            days[midnight] = (days[midnight] ?? 0) + count
            total += count

            let dayTotal = days[midnight]!
            if bestDay == nil || dayTotal > bestDay!.count {
                bestDay = ActivityHeatmapDay(date: midnight, count: dayTotal)
            }
        }

        let (current, longest) = computeStreaks(days: days, calendar: calendar)
        let (p25, p50, p75) = computeThresholds(from: days)

        return ActivityHeatmapData(
            days: days,
            totalCount: total,
            mostActiveDay: bestDay,
            currentStreak: current,
            longestStreak: longest,
            thresholdP25: p25,
            thresholdP50: p50,
            thresholdP75: p75
        )
    }

    /// Compute current and longest streaks from the days map.
    private static func computeStreaks(days: [Date: Int], calendar: Calendar) -> (current: Int, longest: Int) {
        guard !days.isEmpty else { return (0, 0) }

        let sorted = days.keys.sorted()
        let today = calendar.startOfDay(for: Date())

        var longest = 0
        var streak = 1

        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            let diff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if diff == 1 {
                streak += 1
            } else {
                longest = max(longest, streak)
                streak = 1
            }
        }
        longest = max(longest, streak)

        // Current streak: walk backwards from today (or yesterday)
        var current = 0
        var checkDate = today
        if days[checkDate] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return (0, longest)
            }
            checkDate = yesterday
            if days[checkDate] == nil {
                return (0, longest)
            }
        }
        current = 1
        while true {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            if days[prev] != nil {
                current += 1
                checkDate = prev
            } else {
                break
            }
        }

        return (current, longest)
    }
}
