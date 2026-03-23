import SwiftUI

// Brand colors for usage bars
private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)  // #D97856
private let codexBlue = Color(red: 0.24, green: 0.47, blue: 0.96)     // #3D78F5

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
                    resetMin: stats.currentResetMin,
                    tintColor: claudeOrange
                )
                UsageBar(
                    label: "Weekly",
                    displayPct: showRemaining ? 100 - weeklyUsed : weeklyUsed,
                    usedPct: weeklyUsed,
                    resetMin: stats.weeklyResetMin,
                    tintColor: claudeOrange
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
                    resetMin: codexStats.currentResetMin,
                    tintColor: codexBlue
                )
                UsageBar(
                    label: "Secondary",
                    displayPct: showRemaining ? 100 - secondaryUsed : secondaryUsed,
                    usedPct: secondaryUsed,
                    resetMin: codexStats.weeklyResetMin,
                    tintColor: codexBlue
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
    var tintColor: Color = .green

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

    /// Color is based on usedPct with brand tint as the default fill.
    /// Red override at ≥90% preserves warning semantics regardless of display mode.
    private var barColor: Color {
        if usedPct >= 90 { return .red }
        return tintColor
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
