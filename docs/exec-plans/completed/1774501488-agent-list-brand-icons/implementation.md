# Implementation: Replace agent list colored dots with provider brand icons

## Files changed
- `macos/PixelAgents/PixelAgents/Model/AgentState.swift` — Added `import SwiftUI`, added `brandColor` computed property
- `macos/PixelAgents/PixelAgents/Views/AgentListView.swift` — Replaced colored dot + conditional icon with: gray dot (offline) or brand-colored icon (active). Removed `stateColor`.
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift` — Changed 4 brand color constants from `private` to internal

## Summary
Implemented as planned. Active agents now display their provider's brand icon colored with the provider's progress bar color. Offline (empty) slots show a plain gray dot to avoid showing a misleading Claude icon (since `Agent.source` defaults to `.claude`).

## Verification
- Build macOS app in Xcode
- Confirm active agents show provider-colored brand icons
- Confirm offline slots show small gray dots (not brand icons)

## Follow-ups
None.
