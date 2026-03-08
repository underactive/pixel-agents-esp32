# Audit: Hamburger Menu + Multi-Color Dog Settings

## Files Changed

Files where findings were flagged (including immediate dependents):

| File | Audits with findings |
|------|---------------------|
| `firmware/src/config.h` | QA, IC, DX |
| `firmware/src/office_state.h` | SM, DX |
| `firmware/src/office_state.cpp` | QA, Security, IC, SM, RC, DX |
| `firmware/src/renderer.h` | SM |
| `firmware/src/renderer.cpp` | Security, IC, DX |
| `firmware/src/main.cpp` | SM, DX |
| `firmware/src/sprites/dog.h` | QA, IC |
| `tools/convert_dog.py` | QA, Security |

---

## 1. QA Audit

**Q1.** [FIXED] `DOG_COLOR_COUNT` defined as both `static constexpr int` in `config.h` and `#define` in generated `dog.h`. The `#define` would macro-expand over the constexpr name. **Fix:** Removed `#define DOG_COLOR_COUNT` from generated output, replaced with comment.

**Q4.** [FIXED] `hitTestMenuItem` returned -1 for taps inside the menu but not on actionable items (title row, swatch gaps, bottom padding), which closed the menu. **Fix:** Returns -2 for "inside menu, no action" and -1 only for "outside menu". Updated main.cpp to only close on -1.

**Q7.** [FIXED] `convert_dog.py` exited with code 0 on missing input files. **Fix:** Added `sys.exit(1)`.

---

## 2. Security Audit

**S1.** (Low) `seatIdx` used as index into `WORKSTATIONS[]` without upper bounds check against `NUM_WORKSTATIONS`. Safe in practice because `findFreeSeat()` returns valid indices, but violates Development Rule #2. Pre-existing; not introduced by this change.

**S4.** (Low) `uint8_t` to `int8_t` cast for `agentId` comparison is fragile for values >= 128. Guarded by `MAX_AGENTS` check. Pre-existing.

**S6.** [FIXED] (Low) `spriteTable` pointer from PROGMEM not null-checked before dereference in `drawDog()`. Would cause hard crash if `DOG_COLOR_SPRITES` entry were null. **Fix:** Added null check on `spriteTable`.

**S7.** (Critical, **pre-existing**) `initTileMap()` writes to `_tiles[12][*]` and `_tiles[13][*]` — out of bounds on LILYGO where `GRID_ROWS=10`. Not introduced by this change; the tile map layout predates this implementation.

**S8.** (Critical, **pre-existing**) `WORKSTATIONS` layout references rows 11-12, outside LILYGO grid. Related to S7.

**S2, S3, S5, S9, S10, S11.** (Informational) No action required. See full audit output for details.

---

## 3. Interface Contract Audit

**IC-1.** [FIXED] (via Q1) `DOG_COLOR_COUNT` dual definition risk.

**IC-2.** [FIXED] (Medium) `DogColor` enum ordering must match `COLORS` list in `convert_dog.py` — no cross-reference. **Fix:** Added comment on `DogColor` enum: "Order must match COLORS list in tools/convert_dog.py".

**IC-4.** (Low) NVS `saveSettings()` does not check `putBool`/`putUChar` return values. Settings could silently fail to persist on flash failure. Accepted: NVS failures are extremely rare and non-fatal.

**IC-6.** [FIXED] (Medium) Swatch layout constants (`swatchAreaX=10`, `swatchW=16`, `swatchGap=6`) duplicated between `hitTestMenuItem()` and `drawMenuOverlay()`. **Fix:** Extracted to shared constants `SWATCH_AREA_X`, `SWATCH_W`, `SWATCH_GAP` in `config.h`.

**IC-7.** [FIXED] (via Q4) Title row tap closing menu.

**IC-8.** (Low) Hamburger hit zone extends beyond icon bounds (~15x10 vs 7x5 icon). By design — improves touch target size for small icon.

**IC-3, IC-5, IC-9, IC-10, IC-11.** (Informational/Low) No action required. See full audit output.

---

## 4. State Management Audit

**SM-4.** (Low) NVS writes block main loop for ~5-30ms per settings change. Accepted: only occurs on user tap (infrequent), within 66ms frame budget.

**SM-6.** (Low) Stale `_pet` state remains when dog disabled. All readers guard on `getDogSettings().enabled`. Accepted as safe.

**SM-7.** (Low) Read-negate-write pattern for toggle (`!office.getDogSettings().enabled`). Safe in single-threaded context. A dedicated `toggleDogEnabled()` would be more robust but is over-engineering for current architecture.

**SM-8.** [FIXED] (via IC-6) Menu hit-test swatch constants duplicated.

**SM-1, SM-2, SM-3, SM-5, SM-9, SM-10.** (Low/Informational) No action required. See full audit output.

---

## 5. Resource & Concurrency Audit

**R1.** (Low) `Preferences::begin()` return value not checked in `loadSettings()`/`saveSettings()`. On ESP32, failed `begin()` causes no-ops on subsequent calls. Accepted.

**R2.** (Low) Same as SM-4 — NVS write blocks rendering. Accepted.

**R3, R4, R5, R6, R7, R8.** (Informational/None) No action required. See full audit output.

---

## 6. Testing Coverage Audit

**T1-T5.** (Low) Sprite generation edge cases not covered in testing checklist (wrong dimensions, missing files, per-color verification). The build process implicitly validates most of these.

**T6-T9.** (Low) NVS edge cases (first boot, corruption, write failure, redundant write guard). Defensive code is in place; formal test items are aspirational for embedded.

**T10-T12.** (Low) Dog state lifecycle edge cases (re-enable after disable, rapid toggling). `initPet()` does full `memset` reset.

**T13-T16.** (Low) Menu hit-test edge cases (title row tap, swatch gaps, character behind menu). Q4 fix addressed the most impactful case (title row).

**T17-T25.** (Low/Informational) Rendering mode coverage, per-color visual verification, integration gaps. Accepted: hardware-dependent testing is in the testing checklist.

---

## 7. DX & Maintainability Audit

**D1.** [FIXED] (via Q1) Duplicate `DOG_COLOR_COUNT`.

**D11.** [FIXED] (Low) Redundant `isPeeing` check inside already-guarded `!_pet.isPeeing` block. **Fix:** Removed redundant inner check.

**D12.** [FIXED] (via IC-6) Swatch constants duplicated.

**D20.** [FIXED] (Low) Unused `timestamp` parameter in `onHeartbeat()`. **Fix:** Added `(void)timestamp;` cast.

**D2-D10, D13-D19, D21.** (Low/Informational) Pre-existing code quality items (long functions, magic numbers, dead code). Not introduced by this change; deferred to future cleanup.

---

## Summary

| Severity | Total | Fixed | Accepted | Pre-existing |
|----------|-------|-------|----------|--------------|
| Critical | 2 | 0 | 0 | 2 (S7, S8) |
| Medium | 2 | 2 | 0 | 0 |
| Low | ~25 | 5 | ~10 | ~10 |
| Info | ~15 | 0 | ~15 | 0 |

**Fixes applied:** Q1, Q4, Q7, S6, IC-2, IC-6/D12/SM-8, D11, D20 (8 total)

**Pre-existing critical (S7/S8):** The LILYGO tile map and workstation layout reference rows beyond `GRID_ROWS=10`, causing out-of-bounds writes. This predates the hamburger menu implementation and should be addressed in a separate fix (the LILYGO board has its own layout defined via `#if defined(BOARD_CYD)` conditionals, but the shared `initTileMap` code writes CYD-only row indices unconditionally).
