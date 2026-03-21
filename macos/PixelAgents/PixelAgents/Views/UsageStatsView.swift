import SwiftUI

/// Displays Claude Code and Codex usage statistics with progress bars.
/// Supports "used" (default) and "remaining" display modes, toggled via the header.
struct UsageStatsView: View {
    let stats: UsageStatsData?
    let codexStats: UsageStatsData?
    @Binding var showRemaining: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { showRemaining.toggle() }) {
                HStack(spacing: 4) {
                    Text(showRemaining ? "Remaining" : "Usage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            if let stats = stats {
                // Claude section
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("Claude")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                let currentUsed = Int(stats.currentPct)
                let weeklyUsed = Int(stats.weeklyPct)
                UsageBar(
                    label: "Current",
                    displayPct: showRemaining ? 100 - currentUsed : currentUsed,
                    usedPct: currentUsed,
                    resetMin: stats.currentResetMin
                )
                UsageBar(
                    label: "Weekly",
                    displayPct: showRemaining ? 100 - weeklyUsed : weeklyUsed,
                    usedPct: weeklyUsed,
                    resetMin: stats.weeklyResetMin
                )
            }

            if let codexStats = codexStats {
                // Codex section
                HStack(spacing: 4) {
                    Image(systemName: "apple.terminal")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("Codex")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                let primaryUsed = Int(codexStats.currentPct)
                let secondaryUsed = Int(codexStats.weeklyPct)
                UsageBar(
                    label: "Primary",
                    displayPct: showRemaining ? 100 - primaryUsed : primaryUsed,
                    usedPct: primaryUsed,
                    resetMin: codexStats.currentResetMin
                )
                UsageBar(
                    label: "Secondary",
                    displayPct: showRemaining ? 100 - secondaryUsed : secondaryUsed,
                    usedPct: secondaryUsed,
                    resetMin: codexStats.weeklyResetMin
                )
            }

            if stats == nil && codexStats == nil {
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
    let displayPct: Int
    let usedPct: Int
    let resetMin: UInt16

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                Spacer()
                Text("\(displayPct)%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(displayPct) / 100.0))
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

    /// Color is always based on usedPct so warning semantics stay correct:
    /// red = almost out of quota, regardless of display mode.
    private var barColor: Color {
        if usedPct >= 90 { return .red }
        if usedPct >= 70 { return .orange }
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
