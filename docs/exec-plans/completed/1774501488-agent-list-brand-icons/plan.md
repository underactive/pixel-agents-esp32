# Plan: Replace agent list colored dots with provider brand icons

## Objective
Replace the colored state-indicator dots in the agent list with provider brand icons (Claude, Codex, Gemini, Cursor), colored using each provider's progress bar brand color. Offline (empty) slots retain a plain gray dot.

## Changes
1. **`UsageStatsView.swift`** — Make 4 brand color constants internal (remove `private`)
2. **`AgentState.swift`** — Add `import SwiftUI` and `brandColor` computed property mapping `source` to brand color
3. **`AgentListView.swift`** — Replace `Circle()` + conditional `BrandIconView` with: gray dot for offline, brand-colored icon for active agents. Remove unused `stateColor`.

## Dependencies
- Brand color constants must be internal before `AgentState.swift` can reference them.

## Risks / open questions
- Offline agents default `source = .claude`, so must not show brand icon for offline state.
