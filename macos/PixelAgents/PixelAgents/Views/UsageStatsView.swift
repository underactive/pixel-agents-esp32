import SwiftUI

// Brand colors for usage bars (internal — also used by AgentListView)
let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)  // #D97856
let codexBlue = Color(red: 0.24, green: 0.47, blue: 0.96)     // #3D78F5
let geminiPink = Color(red: 1.0, green: 0.420, blue: 0.612)   // #FF6B9C
let cursorGreen = Color(red: 0.224, green: 0.827, blue: 0.325) // #39D353 (matches heatmap "More")

// Per-provider heatmap color palettes (5 levels: no activity → low → med-low → med-high → high)
private let claudeHeatmapColors: [Color] = [
    Color.gray.opacity(0.15),                              // 0: no activity
    Color(red: 0.361, green: 0.145, blue: 0.094),         // 1: low (#5C2518)
    Color(red: 0.545, green: 0.220, blue: 0.125),         // 2: medium-low (#8B3820)
    Color(red: 0.753, green: 0.353, blue: 0.204),         // 3: medium-high (#C05A34)
    Color(red: 0.850, green: 0.470, blue: 0.340),         // 4: high (#D97856)
]

private let codexHeatmapColors: [Color] = [
    Color.gray.opacity(0.15),
    Color(red: 0.059, green: 0.118, blue: 0.290),         // 1: #0F1E4A
    Color(red: 0.106, green: 0.208, blue: 0.471),         // 2: #1B3578
    Color(red: 0.173, green: 0.361, blue: 0.773),         // 3: #2C5CC5
    Color(red: 0.240, green: 0.470, blue: 0.960),         // 4: #3D78F5
]

private let geminiHeatmapColors: [Color] = [
    Color.gray.opacity(0.15),
    Color(red: 0.353, green: 0.098, blue: 0.176),         // 1: #5A192D
    Color(red: 0.576, green: 0.176, blue: 0.318),         // 2: #932D51
    Color(red: 0.820, green: 0.310, blue: 0.478),         // 3: #D14F7A
    Color(red: 1.0, green: 0.420, blue: 0.612),           // 4: #FF6B9C
]

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
        case .cursor: return cursorGreen
        }
    }

    var heatmapColors: [Color] {
        switch self {
        case .claude: return claudeHeatmapColors
        case .codex:  return codexHeatmapColors
        case .gemini: return geminiHeatmapColors
        case .cursor: return cursorHeatmapColors
        }
    }

    var heatmapMetricLabel: String {
        switch self {
        default: return "CLI Tool Calls"
        }
    }
}

private struct ProviderEntry: Identifiable {
    let provider: UsageProvider
    let stats: UsageStatsData?  // nil = loading/no data yet
    var hasFetched: Bool = true // false = first fetch not yet complete (show "Loading…")
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
    var fetchedProviders: Set<UsageProvider> = []
    @Binding var showRemaining: Bool
    var claudeSignInAction: (() -> Void)? = nil
    var claudeHeatmap: ActivityHeatmapData? = nil
    var codexHeatmap: ActivityHeatmapData? = nil
    var geminiHeatmap: ActivityHeatmapData? = nil
    var cursorHeatmap: CursorHeatmapData? = nil
    var cursorAgentHeatmap: ActivityHeatmapData? = nil

    @State private var selectedProvider: UsageProvider?

    /// Returns the local activity heatmap data for a given provider.
    private func activityHeatmapFor(_ provider: UsageProvider) -> ActivityHeatmapData? {
        switch provider {
        case .claude: return claudeHeatmap
        case .codex:  return codexHeatmap
        case .gemini: return geminiHeatmap
        case .cursor: return cursorAgentHeatmap
        }
    }

    /// Tabs for all enabled providers. Stats may be nil (loading or not configured).
    private var enabledProviders: [ProviderEntry] {
        var entries: [ProviderEntry] = []
        if enabled.contains(.claude) { entries.append(ProviderEntry(provider: .claude, stats: stats)) }
        if enabled.contains(.codex) { entries.append(ProviderEntry(provider: .codex, stats: codexStats, hasFetched: fetchedProviders.contains(.codex))) }
        if enabled.contains(.gemini) { entries.append(ProviderEntry(provider: .gemini, stats: geminiStats, hasFetched: fetchedProviders.contains(.gemini))) }
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
                    if selected == .claude, claudeSignInAction != nil {
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
                            showRemaining: showRemaining,
                            activityHeatmap: activityHeatmapFor(selected),
                            cursorHeatmap: selected == .cursor ? cursorHeatmap : nil
                        )
                    } else if entry.hasFetched {
                        // Fetcher ran but found no credentials
                        Text("Not configured")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        // First fetch not yet complete
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
    @AppStorage(SettingsKeys.showMiniBarsWhenSelected) private var showMiniBarsWhenSelected = true
    private var foregroundColor: Color {
        isSelected ? entry.provider.brandColor : .secondary
    }

    private var safeColor: Color {
        entry.provider.brandColor
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
                .opacity(isSelected && !showMiniBarsWhenSelected ? 0 : 1)
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
    var activityHeatmap: ActivityHeatmapData? = nil
    var cursorHeatmap: CursorHeatmapData? = nil

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
                if let heatmap = activityHeatmap {
                    ActivityHeatmapView(data: heatmap, provider: provider)
                }

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
                if let heatmap = activityHeatmap {
                    ActivityHeatmapView(data: heatmap, provider: provider)
                }

            case .gemini:
                UsageBar(
                    label: "Primary",
                    displayPct: displayPct(currentUsed, showRemaining: showRemaining),
                    usedPct: currentUsed,
                    resetMin: stats.currentResetMin,
                    tintColor: color
                )
                if let heatmap = activityHeatmap {
                    ActivityHeatmapView(data: heatmap, provider: provider)
                }

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
                // Show whichever heatmap is busier first
                let toolCalls = activityHeatmap?.totalCount ?? 0
                let lineEdits = cursorHeatmap?.totalEdits ?? 0
                if toolCalls >= lineEdits {
                    if let heatmap = activityHeatmap {
                        ActivityHeatmapView(data: heatmap, provider: provider)
                    }
                    if let heatmap = cursorHeatmap {
                        CursorHeatmapView(data: heatmap)
                    }
                } else {
                    if let heatmap = cursorHeatmap {
                        CursorHeatmapView(data: heatmap)
                    }
                    if let heatmap = activityHeatmap {
                        ActivityHeatmapView(data: heatmap, provider: provider)
                    }
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

// MARK: - Heatmap (GitHub-style contribution grid)

/// Cursor heatmap color palette (5 levels, GitHub-style greens).
private let cursorHeatmapColors: [Color] = [
    Color.gray.opacity(0.15),                              // 0: no activity
    Color(red: 0.055, green: 0.267, blue: 0.161),         // 1: low
    Color(red: 0.0, green: 0.427, blue: 0.196),           // 2: medium-low
    Color(red: 0.149, green: 0.651, blue: 0.255),         // 3: medium-high
    Color(red: 0.224, green: 0.827, blue: 0.325),         // 4: high
]

/// Pre-computed grid layout data for the heatmap Canvas.
private struct HeatmapGridData {
    let weeks: [Date]     // 53 Sunday-start week dates
    let today: Date
    let calendar: Calendar
}

// MARK: - Shared Heatmap Grid View

/// Generic heatmap grid used by both Cursor (API-driven) and Claude/Codex/Gemini (local DB-driven).
/// Renders a 53-week × 7-day contribution grid with provider-specific colors and metric labels.
private struct HeatmapGridView: View {
    let days: [Date: Int]
    let totalCount: Int
    let mostActiveDate: Date?
    let currentStreak: Int
    let longestStreak: Int
    let metricLabel: String
    let colors: [Color]
    let levelForCount: (Int) -> Int
    @Binding var isExpanded: Bool

    private static let weekCount = 53
    private static let rowCount = 7
    private static let gap: CGFloat = 1
    private static let monthLabelHeight: CGFloat = 10
    private static let dayLabelWidth: CGFloat = 12

    /// Pre-compute the grid data once per render.
    private var gridData: HeatmapGridData {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let sundayOffset = -(weekday - 1)
        guard let thisSunday = calendar.date(byAdding: .day, value: sundayOffset, to: today) else {
            return HeatmapGridData(weeks: [], today: today, calendar: calendar)
        }
        var weeks: [Date] = []
        for i in stride(from: -52, through: 0, by: 1) {
            if let week = calendar.date(byAdding: .weekOfYear, value: i, to: thisSunday) {
                weeks.append(week)
            }
        }
        return HeatmapGridData(weeks: weeks, today: today, calendar: calendar)
    }

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header (entire row is tappable)
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    Text(metricLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCount(totalCount))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Collapsible content — always rendered, height animated via clip
            VStack(alignment: .leading, spacing: 4) {
                // Canvas-based heatmap grid — renders within proposed size, never overflows
                let grid = gridData
                Canvas { ctx, size in
                    let cellStep = (size.width - Self.dayLabelWidth) / CGFloat(Self.weekCount)
                    let cell = max(2, cellStep - Self.gap)
                    let topOffset = Self.monthLabelHeight

                    // Draw month labels
                    drawMonthLabels(ctx: ctx, grid: grid, cellStep: cellStep)

                    // Draw 7 rows of cells
                    for row in 0..<Self.rowCount {
                        let wd = row + 1  // weekday: 1=Sun ... 7=Sat
                        let y = topOffset + CGFloat(row) * cellStep

                        for col in 0..<grid.weeks.count {
                            let x = Self.dayLabelWidth + CGFloat(col) * cellStep
                            let date = grid.calendar.date(byAdding: .day, value: wd - 1, to: grid.weeks[col])
                            let isFuture = date.map { $0 > grid.today } ?? true
                            guard !isFuture else { continue }

                            let count = date.flatMap { days[$0] } ?? 0
                            let level = levelForCount(count)
                            let color = colors[level]

                            let rect = CGRect(x: x, y: y, width: cell, height: cell)
                            let path = Path(roundedRect: rect, cornerRadius: 1)
                            ctx.fill(path, with: .color(color))
                        }

                        // Day labels (Mon/Wed/Fri only, matching GitHub style)
                        if wd == 2 || wd == 4 || wd == 6 {
                            let label = wd == 2 ? "M" : wd == 4 ? "W" : "F"
                            let text = Text(label).font(.system(size: 7)).foregroundColor(.secondary)
                            let resolved = ctx.resolve(text)
                            let labelY = y + cell / 2
                            ctx.draw(resolved, at: CGPoint(x: Self.dayLabelWidth - 3, y: labelY), anchor: .trailing)
                        }
                    }
                }
                .frame(height: Self.monthLabelHeight + CGFloat(Self.rowCount) * ((300 - Self.dayLabelWidth) / CGFloat(Self.weekCount)))
                .fixedSize(horizontal: false, vertical: true)

                // Legend
                legendRow

                // Stats
                statsRow
            }
            .background(GeometryReader { geo in
                Color.clear.onChange(of: geo.size.height) { _, h in contentHeight = h }
                    .onAppear { contentHeight = geo.size.height }
            })
            .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
            .clipped()
        }
        .padding(.top, 4)
    }

    // MARK: - Canvas Drawing

    private func drawMonthLabels(ctx: GraphicsContext, grid: HeatmapGridData, cellStep: CGFloat) {
        let monthAbbrevs = ["", "J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        var lastMonth = -1
        for i in 0..<grid.weeks.count {
            let month = grid.calendar.component(.month, from: grid.weeks[i])
            if month != lastMonth {
                let label = (month >= 1 && month <= 12) ? monthAbbrevs[month] : ""
                let text = Text(label).font(.system(size: 7)).foregroundColor(.secondary)
                let resolved = ctx.resolve(text)
                let x = Self.dayLabelWidth + CGFloat(i) * cellStep
                ctx.draw(resolved, at: CGPoint(x: x, y: 0), anchor: .topLeading)
                lastMonth = month
            }
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 2) {
            Text("Less")
                .font(.system(size: 7))
                .foregroundColor(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[level])
                    .frame(width: 8, height: 8)
            }
            Text("More")
                .font(.system(size: 7))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(label: "Most Active", value: mostActiveDate.map { formatDate($0) } ?? "-")
            statItem(label: "Current", value: "\(currentStreak)d")
            statItem(label: "Longest", value: "\(longestStreak)d")
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 9, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Formatting

    private func formatCount(_ n: Int) -> String {
        if n >= 1000 {
            let k = Double(n) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(n)"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

// MARK: - Cursor Heatmap (wraps HeatmapGridView with Cursor API data)

private struct CursorHeatmapView: View {
    let data: CursorHeatmapData
    @AppStorage("heatmapExpanded_cursorLineEdits") private var isExpanded = true

    var body: some View {
        HeatmapGridView(
            days: data.days,
            totalCount: data.totalEdits,
            mostActiveDate: data.mostActiveDay?.date,
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            metricLabel: "IDE Line Edits",
            colors: UsageProvider.cursor.heatmapColors,
            levelForCount: { data.level(for: $0) },
            isExpanded: $isExpanded
        )
    }
}

// MARK: - Activity Heatmap (wraps HeatmapGridView with local DB data)

private struct ActivityHeatmapView: View {
    let data: ActivityHeatmapData
    let provider: UsageProvider
    @AppStorage private var isExpanded: Bool

    init(data: ActivityHeatmapData, provider: UsageProvider) {
        self.data = data
        self.provider = provider
        self._isExpanded = AppStorage(wrappedValue: true, "heatmapExpanded_\(provider.rawValue)")
    }

    var body: some View {
        HeatmapGridView(
            days: data.days,
            totalCount: data.totalCount,
            mostActiveDate: data.mostActiveDay?.date,
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            metricLabel: provider.heatmapMetricLabel,
            colors: provider.heatmapColors,
            levelForCount: { data.level(for: $0) },
            isExpanded: $isExpanded
        )
    }
}
