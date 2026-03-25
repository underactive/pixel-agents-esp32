import SwiftUI

// Brand colors for usage bars
private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)  // #D97856
private let codexBlue = Color(red: 0.24, green: 0.47, blue: 0.96)     // #3D78F5
private let geminiPink = Color(red: 0.769, green: 0.545, blue: 0.690) // #C48BB0
private let cursorDark = Color(red: 0.15, green: 0.15, blue: 0.15)    // Near-black

/// Converts a used percentage to a display value, applying the remaining-mode inversion.
/// Clamps to 0-100 to guard against negative values when usedPct exceeds 100.
private func displayPct(_ usedPct: Int, showRemaining: Bool) -> Int {
    let value = showRemaining ? 100 - usedPct : usedPct
    return max(0, min(100, value))
}

// MARK: - Provider Model

enum UsageProvider: String, CaseIterable, Identifiable {
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

    var brandIcon: String {
        switch self {
        case .claude: return BrandIcon.claude
        case .codex:  return BrandIcon.codex
        case .gemini: return BrandIcon.gemini
        case .cursor: return BrandIcon.cursor
        }
    }

    var brandColor: Color {
        switch self {
        case .claude: return claudeOrange
        case .codex:  return codexBlue
        case .gemini: return geminiPink
        case .cursor: return cursorDark
        }
    }
}

private struct ProviderEntry: Identifiable {
    let provider: UsageProvider
    let stats: UsageStatsData?  // nil = loading/no data yet
    var id: String { provider.id }
}

// MARK: - Tabbed Usage Stats View

/// Displays Claude Code, Codex, Gemini, and Cursor usage statistics as a tabbed interface.
/// Each tab shows mini progress bars at a glance; the selected tab reveals full detail below.
/// Supports "used" (default) and "remaining" display modes, toggled via the header.
struct UsageStatsView: View {
    let stats: UsageStatsData?
    let codexStats: UsageStatsData?
    let geminiStats: UsageStatsData?
    let cursorStats: UsageStatsData?
    let enabled: Set<UsageProvider>
    @Binding var showRemaining: Bool
    var claudeSignInAction: (() -> Void)? = nil

    @State private var selectedProvider: UsageProvider?

    /// Tabs for all enabled providers. Stats may be nil (loading).
    private var enabledProviders: [ProviderEntry] {
        var entries: [ProviderEntry] = []
        if enabled.contains(.claude) { entries.append(ProviderEntry(provider: .claude, stats: stats)) }
        if enabled.contains(.codex) { entries.append(ProviderEntry(provider: .codex, stats: codexStats)) }
        if enabled.contains(.gemini) { entries.append(ProviderEntry(provider: .gemini, stats: geminiStats)) }
        if enabled.contains(.cursor) { entries.append(ProviderEntry(provider: .cursor, stats: cursorStats)) }
        return entries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header toggle
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

            if enabledProviders.isEmpty {
                Text("No usage data")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                // Tab bar
                HStack(spacing: 0) {
                    ForEach(enabledProviders) { entry in
                        ProviderTab(
                            entry: entry,
                            isSelected: selectedProvider == entry.provider,
                            showRemaining: showRemaining
                        ) {
                            selectedProvider = entry.provider
                        }
                    }
                }

                // Detail area for selected provider
                if let selected = selectedProvider,
                   let entry = enabledProviders.first(where: { $0.provider == selected }) {
                    if selected == .claude, claudeSignInAction != nil, entry.stats == nil {
                        // Claude sign-in prompt
                        HStack {
                            Text("Sign in to see Claude usage")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Sign In") { claudeSignInAction?() }
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                                .buttonStyle(.plain)
                        }
                    } else if let entryStats = entry.stats {
                        ProviderDetailView(
                            provider: selected,
                            stats: entryStats,
                            showRemaining: showRemaining
                        )
                    } else {
                        // Loading state — stats not yet fetched
                        Text("Loading\u{2026}")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .onAppear {
            if selectedProvider == nil {
                selectedProvider = enabledProviders.first?.provider
            }
        }
        .onChange(of: enabledProviders.map(\.provider)) { _, newProviders in
            if let current = selectedProvider, !newProviders.contains(current) {
                selectedProvider = newProviders.first
            } else if selectedProvider == nil {
                selectedProvider = newProviders.first
            }
        }
    }
}

// MARK: - Provider Tab

private struct ProviderTab: View {
    let entry: ProviderEntry
    let isSelected: Bool
    let showRemaining: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// Foreground color for icon and name, with Cursor dark-mode fix.
    private var foregroundColor: Color {
        if isSelected {
            if entry.provider == .cursor && colorScheme == .dark { return .primary }
            return entry.provider.brandColor
        }
        return .secondary
    }

    /// Brand color safe for mini bars and tab background.
    private var safeColor: Color {
        if entry.provider == .cursor && colorScheme == .dark { return .primary }
        return entry.provider.brandColor
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BrandIconView(icon: entry.provider.brandIcon, size: 12, color: foregroundColor)
                Text(entry.provider.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(foregroundColor)

                VStack(spacing: 2) {
                    miniBars
                }
                .opacity(isSelected ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? safeColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var miniBars: some View {
        if let stats = entry.stats {
            let currentUsed = Int(stats.currentPct)
            let weeklyUsed = Int(stats.weeklyPct)

            MiniBar(pct: displayPct(currentUsed, showRemaining: showRemaining), usedPct: currentUsed, color: safeColor)

            switch entry.provider {
            case .claude, .codex:
                MiniBar(pct: displayPct(weeklyUsed, showRemaining: showRemaining), usedPct: weeklyUsed, color: safeColor)
            case .gemini:
                EmptyView()
            case .cursor:
                if weeklyUsed > 0 || stats.weeklyResetMin > 0 {
                    MiniBar(pct: displayPct(weeklyUsed, showRemaining: showRemaining), usedPct: weeklyUsed, color: safeColor)
                }
            }
        } else {
            // Loading — show empty track bars as placeholder
            MiniBar(pct: 0, usedPct: 0, color: safeColor)
        }
    }
}

// MARK: - Mini Bar (compact 3pt progress indicator)

private struct MiniBar: View {
    let pct: Int
    let usedPct: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(usedPct >= 90 ? Color.red : color)
                    .frame(width: max(0, geo.size.width * CGFloat(pct) / 100.0))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Provider Detail View

private struct ProviderDetailView: View {
    let provider: UsageProvider
    let stats: UsageStatsData
    let showRemaining: Bool

    var body: some View {
        let currentUsed = Int(stats.currentPct)
        let weeklyUsed = Int(stats.weeklyPct)
        let color = provider.brandColor

        VStack(alignment: .leading, spacing: 2) {
            switch provider {
            case .claude:
                UsageBar(
                    label: "Current",
                    displayPct: displayPct(currentUsed, showRemaining: showRemaining),
                    usedPct: currentUsed,
                    resetMin: stats.currentResetMin,
                    tintColor: color
                )
                UsageBar(
                    label: "Weekly",
                    displayPct: displayPct(weeklyUsed, showRemaining: showRemaining),
                    usedPct: weeklyUsed,
                    resetMin: stats.weeklyResetMin,
                    tintColor: color
                )

            case .codex:
                UsageBar(
                    label: "Primary",
                    displayPct: displayPct(currentUsed, showRemaining: showRemaining),
                    usedPct: currentUsed,
                    resetMin: stats.currentResetMin,
                    tintColor: color
                )
                UsageBar(
                    label: "Secondary",
                    displayPct: displayPct(weeklyUsed, showRemaining: showRemaining),
                    usedPct: weeklyUsed,
                    resetMin: stats.weeklyResetMin,
                    tintColor: color
                )

            case .gemini:
                UsageBar(
                    label: "Primary",
                    displayPct: displayPct(currentUsed, showRemaining: showRemaining),
                    usedPct: currentUsed,
                    resetMin: stats.currentResetMin,
                    tintColor: color
                )

            case .cursor:
                UsageBar(
                    label: "Primary",
                    displayPct: displayPct(currentUsed, showRemaining: showRemaining),
                    usedPct: currentUsed,
                    resetMin: stats.currentResetMin,
                    tintColor: color
                )
                if weeklyUsed > 0 || stats.weeklyResetMin > 0 {
                    UsageBar(
                        label: "Secondary",
                        displayPct: displayPct(weeklyUsed, showRemaining: showRemaining),
                        usedPct: weeklyUsed,
                        resetMin: stats.weeklyResetMin,
                        tintColor: color
                    )
                }
            }
        }
    }
}

// MARK: - Usage Bar (full-size progress bar with label and reset countdown)

private struct UsageBar: View {
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
            } else if usedPct == 0 {
                Text("No usage this period")
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
