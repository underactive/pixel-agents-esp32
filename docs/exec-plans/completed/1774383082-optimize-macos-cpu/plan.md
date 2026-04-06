# Plan: Optimize macOS Software Mode CPU Usage

## Objective

Reduce CPU usage of the macOS companion app in software display mode from ~20%+ to near-zero when the popover is closed, and reduce per-frame rendering cost when visible — without sacrificing the 15 FPS framerate.

## Root Cause

The 15 FPS scene timer runs unconditionally in software mode, rendering full CGBitmapContext frames and publishing them via `@Published var officeFrame` even when the popover is closed and nothing displays the output. Secondary costs include per-frame sprite cropping, NSAttributedString recreation, unnecessary `Task` wrappers, and `@Published` properties on `OfficeScene` that nobody observes.

## Changes

1. **Track popover visibility, skip rendering when not visible** — Add NSPopoverDelegate to AppDelegate, expose visibility to BridgeService. Two timer rates: 15 FPS when visible, 4 FPS background sim-only. Skip render + officeFrame assignment when not visible.
2. **Pre-cache cropped sprite frames** — Pre-crop all 126 character + 100 dog frames at SpriteCache init. Dictionary lookup instead of per-frame `cgImage.cropping(to:)`.
3. **Cache speech bubble NSAttributedStrings** — Only 2 variants ("!" and "..."), create once at OfficeRenderer init.
4. **Dirty-frame detection** — SceneFingerprint struct captures visual state of all entities. Skip re-rendering when nothing changed.
5. **Remove unnecessary Task wrappers** — Replace `Task { @MainActor in }` with `MainActor.assumeIsolated` on timer callbacks.
6. **Remove unused @Published from OfficeScene** — Drop ObservableObject conformance and @Published wrappers.

## Dependencies

Changes are independent and can be implemented in any order. Suggested order: 1 → 2+3 → 4 → 5 → 6.

## Risks / Open Questions

- NSPopoverDelegate `popoverDidShow`/`popoverDidClose` fire asynchronously via Task hop — brief window of stale visibility state (imperceptible).
- SceneFingerprint must be updated when new visual properties are added to Character/Pet structs.
- `MainActor.assumeIsolated` traps at runtime if called off main thread — safe for RunLoop.main timers but fragile if timer scheduling changes.
