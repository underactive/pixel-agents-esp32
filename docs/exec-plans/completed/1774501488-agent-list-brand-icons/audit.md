# Audit: Replace agent list colored dots with provider brand icons

## Files changed
- `macos/PixelAgents/PixelAgents/Model/AgentState.swift`
- `macos/PixelAgents/PixelAgents/Views/AgentListView.swift`
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift`

## 1. QA Audit
No issues found. Exhaustive enum switches, max 6 agents, trivial computed properties.

## 2. Security Audit
No issues found. No external input, compile-time constants only.

## 3. Interface Contract Audit
No issues found. `brandColor` derived from `source` (already in `==`), no equality impact.

## 4. State Management Audit
No issues found. No new mutable state; `brandColor` is purely derived.

## 5. Resource & Concurrency Audit
No issues found. Pure SwiftUI view changes, no concurrency or resource allocation.

## 6. Testing Coverage Audit
No issues found. Compiler-enforced exhaustive switches. Existing test suite covers `Agent` model.

## 7. DX & Maintainability Audit
- **P3 (Low):** Duplicated color-to-brand mapping in `Agent.brandColor` and `UsageProvider.brandColor`. Both map to the same 4 constants but via different enums (`TranscriptSource` vs `UsageProvider`). Acceptable given the small scope; a shared mapping would add indirection for minimal benefit.
- **P3 (Low):** `import SwiftUI` in model file `AgentState.swift`. Acceptable in a small SwiftUI app.
- **P3 (Low):** Four top-level `let` color constants in module namespace. Could be namespaced under a `BrandColors` enum but low impact given module size.

All P3 items accepted as-is — the added abstraction would outweigh the benefit at this project's scale.
