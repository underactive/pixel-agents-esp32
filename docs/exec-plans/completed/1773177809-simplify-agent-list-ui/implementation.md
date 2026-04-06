# Implementation: Simplify Agent List UI

## Files Changed

- `macos/PixelAgents/PixelAgents/Views/AgentListView.swift` — removed count from header, removed empty-state branch, removed `#id` column from `AgentRow`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — build fixed 6-slot `displayAgents` array with offline defaults

## Summary

Implemented exactly as planned with no deviations. The agent list now always shows 6 rows (one per character slot). Active agents fill the first N slots; remaining slots show gray "Offline". The `#id` column is removed from each row.

## Verification

- `xcodebuild -scheme PixelAgents build` — **BUILD SUCCEEDED**
- `xcodebuild -scheme PixelAgents test -destination 'platform=macOS'` — **25 tests passed, 0 failures**

## Follow-ups

- T1/T3: `BridgeService` has no test coverage; the 6-slot display logic should be extracted into a testable function.
- SM-4: `tracker.reset()` is never called on reconnect, causing ghost agents for 30s.
- SM-5/C1: `requestScreenshot()` violates `@MainActor` isolation from a background thread.

## Audit Fixes

### Fixes applied

1. **Q1/IC2 — Duplicate `Identifiable.id` in display slots (Critical):** Replaced overlay-by-index approach with a `map` that constructs all display agents using the slot index as the `id`, guaranteeing unique IDs for SwiftUI's `ForEach`.
2. **Q2/IC1 — Empty initial `displayAgents` (Low):** Changed initializer from `[]` to 6 offline placeholder agents so the UI is consistent from first render.
3. **Q3/DX-A2 — `default` branch in `stateColor` (Medium):** Replaced `default` with explicit `case .spawn, .despawn` for compiler exhaustiveness checking on future `CharState` additions.
4. **DX-B2 — Magic number `6` (Low):** Extracted `static let maxDisplaySlots = 6` on `BridgeService` and used it in both the initializer and `processTranscripts()`.

### Verification checklist

- [x] Build succeeds after fixes
- [x] All 25 tests pass after fixes
- [ ] Verify no duplicate rows appear in agent list when agents have IDs > 5
- [ ] Verify agent list shows 6 "Offline" rows immediately on app launch (before first poll)

### Unresolved items

- All remaining audit findings are pre-existing issues not introduced by this change. They are documented in the audit report for future reference.
