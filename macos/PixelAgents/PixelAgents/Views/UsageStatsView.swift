import SwiftUI

/// Displays Claude Code usage statistics with progress bars.
struct UsageStatsView: View {
    let stats: UsageStatsData?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Usage")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            if let stats = stats {
                UsageBar(label: "Current", pct: Int(stats.currentPct), resetMin: stats.currentResetMin)
                UsageBar(label: "Weekly", pct: Int(stats.weeklyPct), resetMin: stats.weeklyResetMin)
            } else {
                Text("No usage data")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
    }
}

struct UsageBar: View {
    let label: String
    let pct: Int
    let resetMin: UInt16

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(pct) / 100.0))
                }
            }
            .frame(height: 6)

            if resetMin > 0 {
                Text("Resets in \(formatMinutes(resetMin))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var barColor: Color {
        if pct >= 90 { return .red }
        if pct >= 70 { return .orange }
        return .green
    }

    private func formatMinutes(_ minutes: UInt16) -> String {
        let mins = Int(minutes)
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        let remainMins = mins % 60
        if hours < 24 { return "\(hours)h \(remainMins)m" }
        let days = hours / 24
        let remainHours = hours % 24
        return "\(days)d \(remainHours)h"
    }
}
