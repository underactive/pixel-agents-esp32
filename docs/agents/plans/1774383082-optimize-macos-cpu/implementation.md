# Implementation: Optimize macOS Software Mode CPU Usage

## Files Changed

- `macos/PixelAgents/PixelAgents/AppDelegate.swift` — Added `NSPopoverDelegate` conformance, wired `popoverDidShow`/`popoverDidClose` to BridgeService
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — Popover visibility tracking (`isPopoverVisible`, `isSceneVisible`), adaptive timer (15→4 FPS), skip render when not visible, dirty-frame detection via `SceneFingerprint`, `MainActor.assumeIsolated` on timer callbacks
- `macos/PixelAgents/PixelAgents/Views/OfficeRenderer.swift` — Pre-cropped all 226 sprite frames at SpriteCache init (dictionary lookup), cached 2 speech bubble `NSAttributedString`s
- `macos/PixelAgents/PixelAgents/Model/OfficeScene.swift` — Removed `ObservableObject` conformance and `@Published` wrappers

## Summary

All 6 planned changes were implemented as specified, with no deviations from the plan.

## Verification

- `xcodegen && xcodebuild -scheme PixelAgents -configuration Debug build` — **BUILD SUCCEEDED** with zero warnings in changed files.
- Manual verification pending (see testing checklist items added).

## Follow-ups

- Unit tests for `SceneFingerprint` equality logic (currently `private`, would need to be made `internal` for testing)
- Unit tests for adaptive timer rate switching
- Consider making `officeFrame` `private(set)` to enforce the invariant that only `tickScene()` writes it

## Audit Fixes

### Fixes Applied

1. **Fixed `usageFetchTimer` missing `MainActor.assumeIsolated`** — Wrapped callback body in `MainActor.assumeIsolated { ... }` for consistency with all other timer callbacks (addresses IC1, SM6, RC2, DX2).
2. **Added WHY comment for `MainActor.assumeIsolated` pattern** — Added explanatory comment above `startTimers()` explaining why `assumeIsolated` is safe for RunLoop.main timers (addresses S1, DX1).
3. **Clear `lastFingerprint`/`lastRenderedFrame` on session reset** — Added cache clearing to `resetSessionState()` to prevent stale frame after mode switch while visible (addresses Q5, SM4).
4. **Added testing checklist items** — 7 new items in Performance section covering popover visibility behavior, PIP interaction, dirty-frame detection, and speech bubbles (addresses TC1).

### Verification Checklist

- [x] Build succeeds with zero errors and zero warnings in changed files after audit fixes
- [ ] Verify popover open/close correctly switches timer rate (Activity Monitor CPU drop)
- [ ] Verify PIP open/close independently controls render state
- [ ] Verify characters position correctly after popover reopen (no stale frame)
- [ ] Verify agent state changes cause redraws when popover is open (dirty-frame not over-aggressive)
- [ ] Verify speech bubbles render correctly with cached strings
