# Audit: Strip-Buffer Fallback Rendering

## Files changed

Findings were flagged in the following files:
- `firmware/src/renderer.cpp`
- `firmware/src/renderer.h`
- `firmware/src/config.h`
- `CLAUDE.md`

---

## 1. QA Audit

### QA-1 (Medium)
**File:** `renderer.cpp` lines 736-748, 938-950 (`drawRGB565SpriteFlip`, `drawRGB565Sprite`)
**Issue:** Per-pixel row iteration not clipped to strip Y-range. Sprites partially spanning a strip boundary iterate all rows; library rejects out-of-range pixels, but CPU is wasted.
**Recommendation:** Add row-level clipping: `if (y + row < _clipYMin || y + row >= _clipYMax) continue;`

### QA-2 (Medium)
**File:** `renderer.cpp` lines 414-438 (`drawSpawnEffect`)
**Issue:** Expensive per-pixel float color blending computed for rows outside the current strip. Per-pixel bounds check uses `SCREEN_H` instead of clip range.
**Recommendation:** Add row-level clip check before color blend computation.

### QA-3 (Low)
**File:** `renderer.cpp` lines 434, 743, 946
**Issue:** Per-pixel bounds checks use `SCREEN_H` instead of `_clipYMin`/`_clipYMax`. Library handles actual clipping, but renderer checks are misleading in strip mode.
**Recommendation:** Update checks to use clip range or add comment explaining library handles clipping.

### QA-4 (Low)
**File:** `renderer.cpp` lines 908-936 (`sendScreenshotFromDisplay`)
**Issue:** Screenshot capture re-renders scene 8 times (once per strip), blocking main loop. Heartbeat watchdog (6s) provides margin but this is a lengthy operation.
**Recommendation:** Acceptable trade-off. Add comment noting blocking duration.

### QA-5 (Low)
**File:** `renderer.cpp` line 930
**Issue:** `_clipYMin`/`_clipYMax`/`_yOffset` not restored after `sendScreenshotFromDisplay()`. Safe because `renderFrame()` resets them, but fragile ordering dependency.
**Recommendation:** Restore clip state after screenshot loop. [FIXED]

### QA-6 (Low)
**File:** `renderer.h` line 27
**Issue:** `_yOffset` default 0 is correct but not explicitly set in `begin()` for full-screen/direct paths.
**Recommendation:** No change needed; default is correct.

### QA-7 (Medium)
**File:** `renderer.cpp` line 444
**Issue:** Magic number `20` as estimated max bubble height for clip check. Fragile if larger bubble types added.
**Recommendation:** Define named constant in config.h.

---

## 2. Security Audit

### S-1 (High)
**File:** `renderer.cpp` line 930
**Issue:** `sendScreenshotFromDisplay()` dereferences `_currentOffice` without null check. If called before first `renderFrame()`, causes hard crash.
**Recommendation:** Add null guard, send empty screenshot response if null. [FIXED]

### S-2 (Medium)
**File:** `renderer.cpp` lines 908-936
**Issue:** Clipping state not restored after `sendScreenshotFromDisplay()`. Same as QA-5.
**Recommendation:** Save/restore clip state. [FIXED]

### S-3 (Low)
**File:** `renderer.cpp` lines 800, 812
**Issue:** Flush threshold `bufPos > 248` in `rleFlushEnd` is effectively dead code (`bufPos` always <= 248 on entry). No actual overflow.
**Recommendation:** No action needed; buffer arithmetic is correct.

### S-4 (Low)
**File:** `renderer.h` lines 25-26
**Issue:** `_stripHeight` initialized to 0; safe because only used when `_stripMode` is true.
**Recommendation:** No action needed.

### S-5 (Low)
**File:** `config.h`
**Issue:** No static assertion that `SCREEN_H` is divisible by `STRIP_HEIGHT`. Current values (240/30) are fine.
**Recommendation:** Add `static_assert`. [FIXED]

### S-6 (Low)
**File:** `renderer.cpp` lines 889, 915
**Issue:** No null check on `_canvas->getPointer()` in screenshot paths. Unlikely to fail but defensive gap.
**Recommendation:** Add null check. [FIXED]

---

## 3. Interface Contract Audit

### IC-1 (Medium)
**File:** `renderer.cpp` lines 73-83
**Issue:** Strip-mode path in `begin()` does not set `_clipYMin`/`_clipYMax`. Full-screen and direct paths do. Asymmetric initialization.
**Recommendation:** Set `_clipYMin = 0; _clipYMax = SCREEN_H;` in strip path. [FIXED]

### IC-2 (Low)
**File:** `renderer.cpp` line 930
**Issue:** `_currentOffice` null dereference risk. Same as S-1.
**Recommendation:** Add null guard. [FIXED]

### IC-4 (Low)
**File:** `renderer.cpp` lines 925-933
**Issue:** Stale clip state after screenshot loop. Same as QA-5/S-2.
**Recommendation:** Restore clip state. [FIXED]

---

## 4. State Management Audit

### SM-1 (Medium)
**File:** `renderer.cpp` lines 908-936
**Issue:** Clip state (`_clipYMin`/`_clipYMax`/`_yOffset`) not restored after `sendScreenshotFromDisplay()`. Same as QA-5/S-2/IC-4.
**Recommendation:** Save/restore. [FIXED]

### SM-2 (Low)
**File:** `renderer.cpp` line 930
**Issue:** `_currentOffice` null dereference. Same as S-1/IC-2.
**Recommendation:** Add null guard. [FIXED]

---

## 5. Resource & Concurrency Audit

No new issues found. Pre-existing notes only (e.g., `TFT_eSprite` single-threaded assumption is correct for this architecture).

---

## 6. Testing Coverage Audit

### T-1 (Critical — systemic)
**Issue:** No unit tests exist for the project. This is a systemic gap, not specific to this change.
**Recommendation:** Deferred. Systemic issue tracked separately.

### T-3 (Significant)
**Issue:** Testing checklist missing strip-buffer-specific items.
**Recommendation:** Add CYD strip-buffer rendering test items to testing checklist. [FIXED]

---

## 7. DX & Maintainability Audit

### DX-1 (Medium)
**File:** `CLAUDE.md` lines 218, 278
**Issue:** Build config section (line 218) and Known Issues (line 278) still say "half-height buffer"/"half-buffer" instead of "strip-buffer".
**Recommendation:** Update both to reference strip-buffer. [FIXED]

### DX-2 (Medium)
**File:** `renderer.cpp` lines 504-629
**Issue:** `drawStatusBar` is 126 lines, exceeding ~50-line guideline. Pre-existing; not introduced by this change.
**Recommendation:** Deferred. Could extract per-mode helpers in a future refactor.

### DX-3 (Low)
**File:** `renderer.cpp` line 444
**Issue:** Magic number `20` for bubble height estimate. Same as QA-7.
**Recommendation:** Define named constant.

### DX-4 (Low)
**File:** `renderer.cpp` lines 76-82
**Issue:** Strip-mode path in `begin()` doesn't set `_clipYMin`/`_clipYMax`. Same as IC-1.
**Recommendation:** Set explicitly. [FIXED]

### DX-5 (Low)
**File:** `renderer.cpp` lines 315, 443, 461, 497
**Issue:** Sitting-offset calculation duplicated 4 times. Maintenance risk if sitting states change.
**Recommendation:** Deferred. Could extract helper in future refactor.

### DX-6 (Low)
**File:** `renderer.cpp` lines 140-221
**Issue:** `drawScene` is 82 lines, modestly over guideline. Structured clearly as sequential pipeline.
**Recommendation:** Deferred. Acceptable given clear structure.

### DX-7 (Low)
**File:** `renderer.cpp` lines 800, 812
**Issue:** Magic numbers `252` and `248` in RLE buffer flush thresholds.
**Recommendation:** Deferred. Pre-existing code, not introduced by this change.

### DX-8 (Low)
**File:** `renderer.h` lines 24-29
**Issue:** Strip-buffer members lack a grouping comment.
**Recommendation:** Add section comment. [FIXED]

### DX-9 (Low)
**File:** `renderer.cpp` lines 860-906, 908-936
**Issue:** Strip iteration boilerplate duplicated in `sendSplashScreenshot` and `sendScreenshotFromDisplay`.
**Recommendation:** Deferred. Only two sites; extract if a third is added.
