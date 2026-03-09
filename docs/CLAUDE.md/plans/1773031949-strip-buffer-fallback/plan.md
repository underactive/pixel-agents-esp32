# Plan: Strip-Buffer Fallback Rendering

## Objective

Replace the half-screen buffer fallback (320x120, 2 passes, ~75KB) with strip-buffer rendering (320x30, 8 passes, ~19KB) for CYD boards without PSRAM. The current half-mode calls `drawScene()` twice with no clipping — every entity is drawn in both passes regardless of visibility. Strip-buffer with per-strip Y-range clipping skips entities outside each strip, reducing wasted CPU work and lowering memory usage (19KB vs 75KB).

## Changes

### `firmware/src/config.h`
- Add `STRIP_HEIGHT = 30` constant (320x30x2 = 19,200 bytes per strip)

### `firmware/src/renderer.h`
- Remove `_halfMode`, `_halfHeight` members
- Add `_stripMode`, `_stripHeight`, `_stripCount` members
- Add `_clipYMin`, `_clipYMax` members for strip-aware Y-range clipping

### `firmware/src/renderer.cpp`
- **`begin()`**: Replace half-screen buffer allocation with strip buffer (320x30). Fallback chain: full-screen -> strip -> direct.
- **`renderFrame()`**: Replace 2-pass half-mode loop with N-pass strip loop. Each pass sets `_clipYMin`/`_clipYMax` and `_yOffset`, fills sprite, draws scene, pushes sprite.
- **`drawFloor()`**: Add per-row Y-range skip when row is entirely outside `[_clipYMin, _clipYMax)`.
- **`drawRGB565Sprite()`**: Add early-out if sprite Y-range doesn't overlap clip region.
- **`drawRGB565SpriteFlip()`**: Same early-out.
- **`drawCharacter()`**: Add Y-range clip check before sprite lookup.
- **`drawDog()`**: Add Y-range clip check.
- **`drawSpawnEffect()`**: Add Y-range clip check.
- **`drawBubble()`**: Add Y-range clip check.
- **`drawStatusBar()`**: Add Y-range clip check.
- **`drawScene()`**: Add Y-range clip check for grid-bottom gap fill.
- **`sendScreenshotFromDisplay()`**: Replace 2-pass half capture with N-pass strip capture.
- **`sendSplashScreenshot()`**: Replace 2-pass half capture with N-pass strip capture.
- Set `_clipYMin=0`, `_clipYMax=SCREEN_H` for full-screen and direct modes so clip checks are trivially true.

## Dependencies

- No external dependencies. Changes are self-contained within the renderer.
- Screenshot capture (sendScreenshotFromDisplay, sendSplashScreenshot) must be updated in lockstep with the rendering changes.

## Risks / Open Questions

1. **CPU overhead of 8 passes vs 2**: Mitigated by per-entity clip checks that skip most work per strip. Net CPU should be lower than current half-mode which draws everything twice.
2. **CYD 240/30 = 8 exactly**: No partial-strip handling needed for CYD. LILYGO uses PSRAM so never enters strip mode. Code handles arbitrary SCREEN_H for robustness.
3. **TFT_eSprite automatic clipping**: The sprite buffer itself clips any drawing outside its bounds, so correctness doesn't depend on the manual clip checks — those are purely for performance.
