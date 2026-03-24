# Boot Splash Screen — Screenshot Capture Audit

Consolidated audit report for the screenshot capture changes added to the boot splash screen feature (post-commit `a5b5bec`).

## Files changed

- `firmware/src/config.h` — SPLASH_FOOTER_Y, COLOR_SPLASH_FOOTER, layout adjustments, temp hold time
- `firmware/src/splash.h` — drawTo(), drawFooter(), _drawYOffset
- `firmware/src/splash.cpp` — drawTo(), drawFooter(), _drawYOffset in all draw methods
- `firmware/src/main.cpp` — splash screenshot handling in splash loop branch
- `firmware/src/renderer.h` — forward declaration of Splash, sendSplashScreenshot()
- `firmware/src/renderer.cpp` — sendSplashScreenshot() implementation

## Findings

### HIGH

**[FIXED] S1. `sendSplashScreenshot()` null dereference when `_canvas` is null (direct mode)**
- File: `renderer.cpp:830`
- `_canvas->getSwapBytes()` called unconditionally. In direct mode, `_canvas` is `nullptr` (deleted in `begin()` line 83-84). If a screenshot request arrives during splash on a device that fell through to direct mode, the firmware will hard crash. The regular `sendScreenshot()` handles this case at lines 807-817 but `sendSplashScreenshot()` does not.
- Flagged by: QA, Security, Interface, State, Resource, Testing, DX (all 7 audits)

**[FIXED] S2. `SPLASH_CONNECTED_HOLD_MS` set to 15000 (temporary debug value)**
- File: `config.h:255`
- Comment says "TEMP: 15s for screenshot (normally 3000)". This development artifact should be reverted before release. A 15-second splash hold after connection degrades the boot experience.
- Flagged by: QA, State, Resource, Interface, DX

### MEDIUM

**[FIXED] S3. `clearCharArea()` does not apply `_drawYOffset`**
- File: `splash.cpp:46`
- Uses `SPLASH_CHAR_Y` directly without `_drawYOffset`, while `drawCharFrame()` at line 56 does apply it. Currently safe because `clearCharArea()` is only called from `tick()` where `_drawYOffset == 0`, but inconsistent with the pattern used by all other draw methods. Latent defect if the call graph changes.
- Flagged by: QA, Security, State, Interface, Resource, DX

**[FIXED] S4. `addLog()` does not apply `_drawYOffset` in single-line draw path**
- File: `splash.cpp:88`
- The non-scrolling path computes `lineY` without `_drawYOffset`, while `redrawLogArea()` at line 107 correctly includes it. Currently safe because `addLog()` is only called during setup where `_drawYOffset == 0`.
- Flagged by: QA, Security, State, Interface, DX

**[FIXED] S5. Version string hardcoded in `drawFooter()` — not in version bump recipe**
- File: `splash.cpp:38`
- "v0.7.0" is hardcoded in the footer string. CLAUDE.md's version bump recipe lists 2 files; this is a third location that will be missed during future version bumps. Should be a `#define` in `config.h`.
- Flagged by: QA, Interface, DX

**S6. `drawTo()` temporarily mutates `_tft` and `_drawYOffset` without reentrancy guard**
- File: `splash.cpp:142-152`
- Saves and restores `_tft` and `_drawYOffset` around four draw calls. Safe in single-threaded Arduino loop, but fragile if any interrupt or callback accesses Splash during the swap window. The `stepCallback` in `fadeOut`/`fadeIn` can trigger `splash.onHeartbeat()` via protocol callbacks, but this only writes `_connected`/`_connectedMs` (not `_tft`), so no corruption occurs in practice.
- Flagged by: State, Security, DX, Resource

**[FIXED] S7. Missing testing checklist items for splash screenshot, footer, and fade callback**
- File: `docs/CLAUDE.md/testing-checklist.md`
- No checklist items for: (a) splash screenshot capture producing valid image, (b) footer text visibility and positioning, (c) serial drain during fade preventing UART overflow.
- Flagged by: Testing

**S8. `isScreenshotPending()` consume-on-read semantics**
- File: `renderer.cpp:720-725` (via `main.cpp:118,195`)
- Flag is cleared as a side effect of reading. If `sendSplashScreenshot()` fails partway, the request is lost with no retry. Pre-existing pattern inherited by the new splash path. Not a regression but worth noting.
- Flagged by: State, Interface

### LOW

**S9. Footer string nearly fills 320px screen width**
- File: `splash.cpp:38`
- 52 chars at ~6px/char = ~312px on a 320px screen. Any string growth will clip. No truncation guard.
- Flagged by: DX

**S10. LEDC PWM magic numbers for backlight fade**
- File: `splash.cpp:159`
- `ledcSetup(BL_LEDC_CH, 5000, 8)` — frequency 5000 and resolution 8 are not named constants, though `config.h` defines `LED_PWM_FREQ` and `LED_PWM_RES` for CYD LED (inside `#if defined(BOARD_CYD)` guard).
- Flagged by: DX

**S11. Forward declaration coupling between Renderer and Splash**
- File: `renderer.h:6`
- Renderer now depends on Splash (a boot-only transient subsystem). Architecturally acceptable since it's a single method, but creates bidirectional awareness.
- Flagged by: DX

**S12. `_screenshotRequested` not volatile or atomic**
- File: `renderer.h:21`
- Set in protocol callback, read in main loop. Safe in single-threaded Arduino loop model. Would need `volatile` or atomic if protocol processing moved to a separate core.
- Flagged by: Resource

**S13. `fadeOut`/`fadeIn` callback parameter undocumented**
- File: `splash.h:12`
- `void (*stepCallback)() = nullptr` — no doc comment explaining its purpose (draining serial during blocking delay).
- Flagged by: DX

**S14. No unit test infrastructure exists**
- File: `firmware/test/`
- Empty test directory. Pure computational functions (RLE encoding, protocol framing) could be unit tested without hardware.
- Flagged by: Testing

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 2     |
| MEDIUM   | 6     |
| LOW      | 6     |

**Action required:**
- S1: Add null guard for `_canvas` in `sendSplashScreenshot()` (crash fix)
- S2: Revert `SPLASH_CONNECTED_HOLD_MS` to 3000 (temp value cleanup)
- S3/S4: Add `_drawYOffset` to `clearCharArea()` and `addLog()` for consistency
- S5: Add version string constant to `config.h` and update version bump recipe
- S7: Add testing checklist items
