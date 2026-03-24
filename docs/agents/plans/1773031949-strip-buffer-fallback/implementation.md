# Implementation: Strip-Buffer Fallback Rendering

## Files changed

- `firmware/src/config.h` -- Added `STRIP_HEIGHT = 30` constant
- `firmware/src/renderer.h` -- Replaced `_halfMode`/`_halfHeight` with `_stripMode`/`_stripHeight`/`_stripCount`; added `_clipYMin`/`_clipYMax` for per-strip Y-range clipping
- `firmware/src/renderer.cpp` -- Replaced half-screen buffer fallback with strip-buffer rendering; added Y-range clip checks to all draw functions; updated screenshot capture for strip mode
- `CLAUDE.md` -- Updated renderer subsystem description (half-height -> strip-buffer)
- `docs/CLAUDE.md/future-improvements.md` -- Marked strip-buffer item as complete

## Summary

Replaced the 2-pass half-screen buffer fallback (320x120, ~75KB) with an 8-pass strip-buffer approach (320x30, ~19KB) for CYD boards without PSRAM. No deviations from plan.

Key changes:
- **`begin()`**: Fallback chain is now full-screen -> strip (320x30) -> direct. Strip buffer uses 19KB vs 75KB.
- **`renderFrame()`**: Strip mode iterates 8 strips, setting `_clipYMin`/`_clipYMax` per strip.
- **Clip checks**: Added Y-range early-outs to `drawFloor`, `drawRGB565Sprite`, `drawRGB565SpriteFlip`, `drawCharacter`, `drawDog`, `drawSpawnEffect`, `drawBubble`, `drawStatusBar`, and gap fill. In full-screen mode, clip bounds are [0, SCREEN_H) so these checks are trivially true.
- **Screenshot capture**: `sendScreenshotFromDisplay()` and `sendSplashScreenshot()` updated from 2-pass to N-pass strip iteration.
- **drawCharacter refactor**: Moved sitting offset computation before the clip check, eliminating the duplicate computation that existed before.

## Verification

- CYD (`cyd-2432s028r`) builds clean: RAM 12.3%, Flash 82.5%
- LILYGO (`lilygo-t-display-s3`) builds clean: RAM 6.6%, Flash 11.3%
- No remaining references to `_halfMode` or `_halfHeight` in codebase
- Full-screen mode (LILYGO) path unchanged — clip bounds set to [0, SCREEN_H)

## Follow-ups

- Hardware testing needed: verify strip-buffer rendering produces correct output on CYD with no visible tearing between strips
- Performance profiling: measure actual FPS improvement from clip checks vs old half-mode
- Row-level clipping optimization: add per-row early-out in `drawRGB565Sprite`/`drawRGB565SpriteFlip`/`drawSpawnEffect` to skip rows outside strip (QA-1, QA-2)

## Audit Fixes

### Fixes applied

1. **Null guard for `_currentOffice`** (S-1, IC-2, SM-2) — Added null check at top of `sendScreenshotFromDisplay()`; sends empty screenshot response if office state not yet set.
2. **Restore clip state after screenshot** (SM-1, S-2, IC-4, QA-5) — Save/restore `_clipYMin`, `_clipYMax`, `_yOffset` around strip iteration in `sendScreenshotFromDisplay()`.
3. **Initialize clip bounds in strip begin path** (IC-1, DX-4) — Added `_clipYMin = 0; _clipYMax = SCREEN_H;` in strip-mode branch of `begin()`, matching full-screen and direct-mode paths.
4. **Static assert for STRIP_HEIGHT divisibility** (S-5) — Added `static_assert(SCREEN_H % STRIP_HEIGHT == 0)` under `#if defined(BOARD_CYD)` in `config.h`.
5. **Null check on `getPointer()`** (S-6) — Added null guard for `_canvas->getPointer()` in both `sendScreenshotFromDisplay()` and `sendSplashScreenshot()`.
6. **Strip-buffer member grouping comment** (DX-8) — Added `// Strip-buffer rendering state` section comment in `renderer.h`.
7. **Stale CLAUDE.md references** (DX-1) — Updated CYD env description (line 218) and Known Issues (line 278) from "half-height buffer"/"half-buffer" to "strip-buffer".
8. **Testing checklist** (T-3) — Added 10 strip-buffer rendering test items to `docs/CLAUDE.md/testing-checklist.md`.

### Deferred items

- QA-1, QA-2: Row-level clipping optimization in sprite draw functions. Performance enhancement, not a bug. Added to follow-ups.
- QA-7, DX-3: Magic number `20` for bubble height estimate. Low risk; current bubble sprites are all < 20px.
- DX-2: `drawStatusBar` length (126 lines). Pre-existing; not introduced by this change.
- DX-5: Sitting-offset calculation duplication. Pre-existing; not introduced by this change.
- DX-6: `drawScene` length (82 lines). Acceptable given clear sequential structure.
- DX-7: RLE flush threshold magic numbers. Pre-existing code.
- DX-9: Strip iteration duplication across screenshot functions. Only two sites; extract if a third is added.
- T-1: No unit tests. Systemic gap tracked separately.

### Verification checklist

- [ ] CYD build compiles clean after audit fixes
- [ ] LILYGO build compiles clean after audit fixes
- [ ] Screenshot request before first renderFrame() returns empty response (not crash)
- [ ] Clip state (_clipYMin/_clipYMax/_yOffset) is correct after screenshot capture
- [ ] `static_assert` fires if CYD SCREEN_H changed to non-multiple of STRIP_HEIGHT
