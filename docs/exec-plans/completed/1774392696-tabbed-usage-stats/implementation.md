# Implementation: Tabbed Usage Stats View

## Files Changed
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift` — Full rewrite: tabbed UI with ProviderTab, MiniBar, ProviderDetailView
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift` — Updated usageStatsSection: removed sign-in hint, pass zeroed stats for enabled providers, pass claudeSignInAction
- `macos/PixelAgents/PixelAgents/Model/UsageStats.swift` — Added `UsageStatsData.zero` static constant, updated doc comment

## Summary

Replaced the stacked VStack usage layout with a tabbed interface. Each enabled provider appears as a tab with brand icon, name, and mini progress bars (3pt height). Selecting a tab shows its full UsageBar detail below. Added `.contentShape(Rectangle())` for full-area tap targets. All enabled providers now show tabs even with zero usage data.

Deviations from plan:
- Plan originally only passed zeroed stats for Claude sign-in case. Updated to pass zeroed stats for ALL enabled-but-no-data providers so tabs always appear when enabled in settings.

## Verification
- `xcodebuild build -scheme PixelAgents -configuration Debug -quiet` — compiles cleanly
- Visual verification: tabs render, switching works, mini bars display, detail area shows correct bars

## Audit Fixes

Fixes applied:
1. **D1 — Extracted `displayPct()` helper** to replace 9 repeated `showRemaining ? 100 - value : value` ternaries. Also adds clamping to 0-100, fixing Q1 (negative percentage display when usedPct > 100).
2. **D2 — Made `UsageBar` private** since it is only consumed within `UsageStatsView.swift`.
3. **D3/I2 — Centralized zero-stats sentinel** to `UsageStatsData.zero` static constant in `UsageStats.swift`. Updated both `UsageStatsView.swift` (sign-in check) and `MenuBarView.swift` (fallback stats) to use it. Also updated stale doc comment on `UsageStatsData` (D5).

Unresolved items:
- **Q3** (unreachable "No usage data" in UsageStatsView): Kept as safety net for potential reuse outside MenuBarView.
- **Q4** (duplicated Cursor secondary bar heuristic): Accepted — only 2 occurrences, extracting would over-abstract.
- **I1** (zeroed stats ambiguity for non-Claude providers): Accepted — design trade-off; adding a "no data" state enum to UsageStatsData would be a larger refactor for minimal UX benefit.
- **I3** (nested ObservableObject observation): Pre-existing pattern, not introduced by this change.
- **T1-T12** (testing coverage): No view-layer test infrastructure exists; adding SwiftUI view tests is a separate effort.

Verification checklist:
- [x] `xcodebuild build -scheme PixelAgents -configuration Debug -quiet` compiles cleanly after all fixes
- [ ] Verify `displayPct()` clamps correctly: set a breakpoint or log when `usedPct > 100` to confirm 0% display in remaining mode
- [ ] Verify `UsageBar` is no longer accessible outside `UsageStatsView.swift` (would be a compile error if referenced elsewhere)

## Follow-ups
- Mini bar height (3pt) may need tuning after real-world use — bump to 4pt if too thin
- Consider persisting selected tab across popover open/close via @AppStorage if users prefer sticky selection
