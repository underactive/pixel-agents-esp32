# Plan: Tabbed Usage Stats View

## Objective

Replace the vertically-stacked usage stats layout in the macOS companion app's popover with a tabbed interface. Each AI provider (Claude, Codex, Gemini, Cursor) gets its own tab showing mini progress bars at a glance. The selected tab reveals full usage detail below. This cuts vertical height from ~260-300px to ~130px.

## Changes

### UsageStatsView.swift (major rewrite)
- Add `UsageProvider` enum centralizing provider name, icon, and brand color
- Add `ProviderEntry` struct pairing provider with its stats
- Add `claudeSignInAction: (() -> Void)?` parameter for integrated sign-in prompt
- Add `@State selectedProvider` with auto-select on appear and fallback on provider removal
- Rewrite body: header toggle → tab bar HStack → detail area for selected provider
- Add `ProviderTab` view: pill-highlighted selected state, mini bars on unselected tabs
- Add `MiniBar` view: 3pt-height compact progress indicator
- Add `ProviderDetailView`: renders 1-2 full `UsageBar` instances per provider type
- Keep `UsageBar` component untouched

### MenuBarView.swift (minor update)
- Remove standalone Claude sign-in hint HStack
- Pass zeroed `UsageStatsData` for all enabled-but-no-data providers (so tabs always appear when enabled)
- Pass `claudeSignInAction` to `UsageStatsView` when Claude needs sign-in

## Dependencies
- `BrandIcons.swift` — `BrandIcon.*` paths and `BrandIconView` (reused, no changes)
- `UsageStats.swift` — `UsageStatsData` struct (no changes)

## Risks / Open Questions
- Mini bar readability at 3pt height (tunable to 4pt if needed)
- Cursor dark mode visibility (addressed with `@Environment(\.colorScheme)` fallback)
- Popover height jitter when switching between providers with different bar counts
