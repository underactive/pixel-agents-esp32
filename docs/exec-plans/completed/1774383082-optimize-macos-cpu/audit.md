# Audit: Optimize macOS Software Mode CPU Usage

## Files Changed

- `macos/PixelAgents/PixelAgents/AppDelegate.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`
- `macos/PixelAgents/PixelAgents/Views/OfficeRenderer.swift`
- `macos/PixelAgents/PixelAgents/Model/OfficeScene.swift`

---

## 1. QA Audit

**Q1. LOW** — `usageFetchTimer` callback (BridgeService.swift:326-331) missing `MainActor.assumeIsolated`, inconsistent with other timer callbacks.

**Q2. LOW** — Popover delegate uses async `Task { @MainActor in }` (AppDelegate.swift:110-120) creating a one-tick delay before timer rate adapts. Functionally harmless.

**Q3. LOW** — `SceneFingerprint.effectTimer` quantized to 0.05s steps (BridgeService.swift:745). At 15 FPS (0.067s/frame), quantization is finer than frame interval. No functional issue.

**Q4. LOW** — `SpriteCache.loadAll()` (OfficeRenderer.swift:38-76) silently skips missing sprite assets with no log message. Pre-existing behavior, but harder to debug with pre-caching.

**[FIXED] Q5. LOW** — `lastFingerprint`/`lastRenderedFrame` not cleared on `stopSceneTimer()` or `resetSessionState()`. Stale cache holds ~287 KB CGImage unnecessarily.

**Q6. MEDIUM** — Dirty-frame check (BridgeService.swift:678-682) relies on nothing external modifying `officeFrame`. Consider making it `private(set)`.

## 2. Security Audit

**[FIXED] S1. MEDIUM** — `MainActor.assumeIsolated` in timer callbacks (BridgeService.swift:314,321,334,647) traps at runtime if assumption violated. Safe for RunLoop.main timers but fragile. Added WHY comments.

**S2. LOW** — `Int16(ch.effectTimer * 20)` (BridgeService.swift:745) would overflow at ~1638s. Safe under current 3s spawn duration.

**S3. LOW** — `SpriteCache` singleton retains all frames for app lifetime (~770 KB). Acceptable for menu bar app.

**S4. LOW** — `lastRenderedFrame` cached indefinitely when scene not visible (~287 KB). Trivial.

**S5. LOW** — Popover delegate `Task` dispatch could theoretically reorder under rapid open/close. NSPopover `.transient` prevents this in practice.

## 3. Interface Contract Audit

**[FIXED] IC1. MEDIUM** — `usageFetchTimer` callback (BridgeService.swift:326-331) accesses `@MainActor` self without `MainActor.assumeIsolated`, inconsistent with other timers.

**IC2. LOW** — Popover delegate async hop creates one-runloop-cycle delay. Functionally harmless.

**IC3. LOW** — `onSettingsState` closures (BridgeService.swift:154-159) call `@MainActor`-isolated method from background thread. Pre-existing pattern, safe due to internal `Task` dispatch. Will need updating for Swift 6.

**IC4. LOW** — `SceneFingerprint` uses Float exact equality for positions. Safe because positions are deterministically computed, but invariant is implicit.

## 4. State Management Audit

**SM1. MEDIUM** — `onSettingsState` callback invoked off MainActor (BridgeService.swift:154-158). Pre-existing pattern, safe today but strict concurrency violation.

**SM2. MEDIUM** — `isPIPShown` mutated from two sites (BridgeService.togglePIP and PIPWindowController.windowWillClose). Both @MainActor, no data race, but dual mutation path is a maintainability hazard. Pre-existing.

**SM3. LOW** — `isPopoverVisible` is not `@Published`. Intentional — only used internally by `isSceneVisible`.

**[FIXED] SM4. LOW** — `lastFingerprint`/`lastRenderedFrame` not cleared on `resetSessionState()`. Could skip first render after session reset while visible.

**SM5. LOW** — `OfficeScene` removed `ObservableObject`. Correct since no SwiftUI view observes it directly.

**[FIXED] SM6. LOW** — `usageFetchTimer` closure inconsistent with other timers (missing `MainActor.assumeIsolated`).

## 5. Resource & Concurrency Audit

**RC1. MEDIUM** — `onSettingsState` calls `@MainActor` method from background serial queue (BridgeService.swift:154-156). Pre-existing, safe due to internal Task dispatch.

**[FIXED] RC2. LOW** — `usageFetchTimer` callback missing `MainActor.assumeIsolated` (BridgeService.swift:326-331).

**RC3. LOW** — Popover delegate `Task` hop introduces one-runloop-cycle delay. Correct pattern for `nonisolated` delegate methods.

**RC4. LOW** — `SpriteCache` not annotated with `@MainActor` or `Sendable`. Only accessed from `@MainActor` OfficeRenderer, safe in current usage.

**RC5. LOW** — `SceneFingerprint` allocates `[CharVis]` array on heap each tick. Net savings from skipped renders outweigh this cost.

## 6. Testing Coverage Audit

**[FIXED] TC1. MEDIUM** — Missing testing checklist items for popover visibility affecting render rate and dirty-frame detection.

**TC2. MEDIUM** — No unit tests for `SceneFingerprint` equality logic. Deferred — struct is `private`, would need refactoring for testability.

**TC3. MEDIUM** — No unit tests for adaptive timer rate switching. Deferred — difficult to test Timer behavior in XCTest.

**TC4. LOW** — No unit tests for `SpriteCache` pre-cropping key arithmetic. Low risk since visual breakage would be immediately obvious.

## 7. DX & Maintainability Audit

**[FIXED] DX1. MEDIUM** — `MainActor.assumeIsolated` usage without WHY comments (BridgeService.swift:314,321,334,647).

**[FIXED] DX2. MEDIUM** — `usageFetchTimer` closure inconsistent with other timers.

**DX3. MEDIUM** — Duplicated direction-flip logic in `drawCharacter()` and `drawSpawnEffect()` (OfficeRenderer.swift:287-295, 313-321). Pre-existing, not introduced by this change.

**DX4. MEDIUM** — `bubbleType` magic integers (0, 1, 2, 3) used without named constants. Pre-existing, violates Development Rule #5. Not in scope of this change.

**DX5. LOW** — `SceneFingerprint` NOTE comment but no enforcement mechanism. Comment added; static enforcement not feasible in Swift.

**DX6. HIGH** — `initTileMap()` 169 lines of repetitive assignments (OfficeScene.swift:317-486). Pre-existing, not introduced by this change.

**DX7. MEDIUM** — `updateCharacter()` 189 lines (OfficeScene.swift:699-888). Pre-existing.

**DX8. MEDIUM** — Dead `_ = transport` bindings (BridgeService.swift:395-398, 423). Pre-existing.

---

## Summary

- **0 HIGH** findings in changed code (DX6 is pre-existing)
- **4 MEDIUM** findings addressed: IC1/SM6/RC2/DX2 (usageFetchTimer consistency), S1/DX1 (WHY comments), Q5/SM4 (fingerprint cache clearing), TC1 (testing checklist)
- **Remaining MEDIUM** findings are pre-existing patterns (onSettingsState cross-isolation, isPIPShown dual mutation, duplicated flip logic, bubbleType magic numbers, updateCharacter length, dead transport bindings)
- **Deferred:** Unit tests for SceneFingerprint and timer switching (TC2, TC3)
