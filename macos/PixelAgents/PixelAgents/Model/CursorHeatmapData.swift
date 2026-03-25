import Foundation

/// Per-day activity for the Cursor usage heatmap.
struct CursorHeatmapDay: Equatable {
    let date: Date     // midnight-aligned (start of day)
    let edits: Int     // acceptedLinesAdded + acceptedLinesDeleted
}

/// Aggregated heatmap data for Cursor's "AI Line Edits" contribution grid.
struct CursorHeatmapData: Equatable {
    /// Sparse map of midnight-aligned date → line edits count.
    let days: [Date: Int]
    let totalEdits: Int
    let mostActiveDay: CursorHeatmapDay?
    let currentStreak: Int   // consecutive days with edits ending today or yesterday
    let longestStreak: Int

    /// Pre-computed quartile thresholds (p25, p50, p75) for 4-level color mapping.
    /// Cached at construction time to avoid re-sorting on every cell render.
    let thresholdP25: Int
    let thresholdP50: Int
    let thresholdP75: Int

    /// Map an edit count to a color level (0-4).
    func level(for edits: Int) -> Int {
        guard edits > 0 else { return 0 }
        if edits >= thresholdP75 { return 4 }
        if edits >= thresholdP50 { return 3 }
        if edits >= thresholdP25 { return 2 }
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
}

// MARK: - Builder

extension CursorHeatmapData {
    /// Build from the Cursor analytics API response dailyMetrics array.
    /// Each metric has `date` (epoch ms string), `acceptedLinesAdded`, `acceptedLinesDeleted`.
    static func from(dailyMetrics: [[String: Any]]) -> CursorHeatmapData {
        let calendar = Calendar(identifier: .gregorian)
        var days: [Date: Int] = [:]
        var total = 0
        var bestDay: CursorHeatmapDay?

        for metric in dailyMetrics {
            guard let dateStr = metric["date"] as? String,
                  let epochMs = Double(dateStr) else { continue }

            let added = (metric["acceptedLinesAdded"] as? NSNumber)?.intValue ?? 0
            let deleted = (metric["acceptedLinesDeleted"] as? NSNumber)?.intValue ?? 0
            let edits = added + deleted
            guard edits > 0 else { continue }

            let rawDate = Date(timeIntervalSince1970: epochMs / 1000)
            let midnight = calendar.startOfDay(for: rawDate)

            days[midnight] = (days[midnight] ?? 0) + edits
            total += edits

            let dayTotal = days[midnight]!
            if bestDay == nil || dayTotal > bestDay!.edits {
                bestDay = CursorHeatmapDay(date: midnight, edits: dayTotal)
            }
        }

        let (current, longest) = computeStreaks(days: days, calendar: calendar)
        let (p25, p50, p75) = CursorHeatmapData.computeThresholds(from: days)

        return CursorHeatmapData(
            days: days,
            totalEdits: total,
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
        var current = 0
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
        var checkDate = today
        if days[checkDate] == nil {
            // Check yesterday
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
