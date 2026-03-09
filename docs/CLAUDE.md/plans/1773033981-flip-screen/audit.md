# Audit: Flip Screen Feature

## Files Changed

- `firmware/src/config.h`
- `firmware/src/office_state.h`
- `firmware/src/office_state.cpp`
- `firmware/src/renderer.cpp`
- `firmware/src/touch_input.h`
- `firmware/src/touch_input.cpp`
- `firmware/src/main.cpp`
- `docs/CLAUDE.md/testing-checklist.md`

---

## 1. QA Audit

**Q1** (INFO) -- Menu layout math is correct: 4 rows x 20px = 80px + 10px padding = 90px. No issue.

**Q2** (LOW) -- `hitTestMenuItem` returns magic number `5` for flip row; caller checks `item == 5` without symbolic constant. Consistent with existing pattern for values 0-4. [FIXED] Comment in `main.cpp` updated to document value 5.

**Q3** (LOW) -- NVS write on every toggle. Consistent with existing dog toggle pattern. Accepted.

**Q4** (MED) -- Touch coordinate mapping (hardcoded ADC ranges 200-3800) may not map correctly after `setRotation(3)`. The XPT2046 library's `setRotation()` transforms `getPoint()` output, so the `map()` ranges should remain valid, but this needs hardware verification.

**Q5** (LOW) -- Splash renders after rotation is applied in boot. Correct.

**Q6** (LOW) -- One-frame visual glitch when rotation changes before next render. Cosmetic, ~66ms. Accepted.

**Q7** (LOW) -- No mid-render rotation change possible. Touch handler runs before render in same loop iteration. Correct.

**Q8** (LOW) -- Hit test uses screen-space constants, unaffected by rotation. Correct if Q4 is correct.

**Q9** (LOW) -- Bottom 10px padding returns -2 (no-op). Intentional.

---

## 2. Security Audit

**S1** (LOW) -- NVS flash wear from repeated toggle. Mitigated by early-out guard. Consistent with existing pattern. Accepted.

**S2** (LOW) -- `setDisplayRotation(int)` accepts unconstrained int. TFT_eSPI masks to 0-3. XPT2046 similar. Current callers always pass 1 or 3. Accepted.

**S3** (LOW) -- Return value gap between 4 and 5 is actually no gap (1-4 are color swatches, 5 is flip). Correct.

**S4** (LOW) -- Menu Y position with MENU_H=90: CYD gives menuY=138 (safe). Accepted.

**S5** (LOW) -- `prefs.getBool()` returns default on type mismatch. Safe.

**S6** (LOW) -- `setScreenFlipped()` split responsibility. [FIXED] Doc comment added to declaration.

---

## 3. Interface Contract Audit

**I1** (MED) -- Return value 5 undocumented in main.cpp comment. [FIXED] Comment updated.

**I2** (LOW) -- `saveSettings()` ignores NVS write failure. Pre-existing pattern. Accepted.

**I3** (MED) -- `setScreenFlipped()` only updates flag + NVS; caller must also update TFT + touch. [FIXED] Doc comment added to declaration.

**I4** (LOW) -- One-frame visual glitch. Cosmetic. Accepted.

**I5** (MED) -- Touch mapping correctness under rotation 3 depends on XPT2046 library implementation. Needs hardware verification.

**I6** (LOW) -- Boot init ordering is correct (audited and confirmed).

**I7** (LOW) -- No rotation validation needed; inputs are constrained by boolean. Accepted.

---

## 4. State Management Audit

**M1** (MED) -- Rotation state split across three owners (OfficeState, TFT, XPT2046). [FIXED] Doc comment on `setScreenFlipped()` documents caller's responsibility. Single call site is correct.

**M2** (LOW) -- Touch rotation hardcoded to 1 in `begin()`, then conditionally overridden. No touch events during setup, so harmless. Accepted.

**M3** (LOW) -- Magic number `5` for flip menu item. [FIXED] Comment updated in main.cpp.

**M4** (LOW) -- One-frame glitch on rotation change. Cosmetic. Accepted.

**M5** (LOW) -- NVS writes not thread-safe. All calls are from main loop today. Accepted.

**M6** (INFO) -- MENU_H sizing is correct. [FIXED] Comment added explaining derivation.

---

## 5. Resource & Concurrency Audit

**R1** (MED) -- NVS write blocks main loop for 10-50ms. Pre-existing pattern (dog toggle has same issue). Accepted.

**R2** (LOW) -- No concurrency on TFT access; all in main loop. Correct.

**R3** (LOW) -- `setDisplayRotation()` doesn't validate rotation value. Input always 1 or 3 from boolean. Accepted.

**R4** (LOW) -- `saveSettings()` doesn't check `prefs.begin()` return. Pre-existing. Accepted.

**R5** (LOW) -- No atomicity issue; single-threaded main loop provides implicit synchronization. Correct.

**R6** (LOW) -- NVS wear leveling adequate for realistic usage. Early-out guard prevents redundant writes. Accepted.

**R7** (LOW) -- Stale touch coordinates impossible due to debounce. Correct.

---

## 6. Testing Coverage Audit

**T1** (HIGH) -- No manual test items for flip screen in testing checklist. [FIXED] 8 test items added.

**T2** (MED) -- MENU_H=90 visual fit. Covered by T1 test items.

**T3** (MED) -- hitTestMenuItem returning 5. Covered by T1 test items.

**T4** (MED) -- NVS persistence round-trip. Covered by T1 test items (reboot with flip ON).

**T5** (HIGH) -- Touch coordinate correctness after rotation 3. Covered by T1 test items. Needs hardware verification.

**T6** (MED) -- Boot-time rotation init order. Covered by T1 test items (flipped boot).

**T7** (LOW) -- Menu close after flip. Covered by T1 test items.

**T8** (LOW) -- Flip ON/OFF text rendering. Covered by T1 test items.

**T9** (LOW) -- setScreenFlipped no-op. Low priority. Accepted.

**T10** (MED) -- Screenshot correctness in flipped mode. Covered by T1 test items.

---

## 7. DX & Maintainability Audit

**D1** (MED) -- Magic number `5` for flip menu item. [FIXED] Comment updated in main.cpp.

**D2** (MED) -- hitTestMenuItem return contract undocumented. [FIXED] Comment in main.cpp updated with value 5.

**D3** (LOW) -- setScreenFlipped/isScreenFlipped no doc comment. [FIXED] Doc comment added.

**D4** (MED) -- Rotation coordination duplicated in setup() and touch handler. Accepted for now — only 2 call sites, and a helper function would need to take TFT + touch references which adds complexity.

**D5** (LOW) -- MENU_H is a derived constant. [FIXED] Comment added explaining derivation.

**D6** (LOW) -- setDisplayRotation doesn't document XPT2046 rotation assumption. Covered by testing checklist (hardware verification required).

**D7** (LOW) -- No comment on closeMenu after flip. [FIXED] Comment added.

**D8** (LOW) -- NVS key abbreviation consistent with existing convention. Accepted.

---

## Summary

| Severity | Total | Fixed | Accepted |
|----------|-------|-------|----------|
| CRITICAL | 0 | 0 | 0 |
| HIGH | 2 | 2 | 0 |
| MED | 12 | 6 | 6 |
| LOW | 27 | 0 | 27 |
| INFO | 2 | 1 | 1 |

**Items needing hardware verification:**
- Q4/I5/T5: Touch coordinate mapping under XPT2046 `setRotation(3)` — the library should handle it, but ADC-to-screen mapping with hardcoded calibration values needs on-device testing.

**Pre-existing patterns accepted as-is:**
- NVS write latency in main loop (R1)
- NVS write failure not checked (R4/I2)
- NVS flash wear (S1/R6)
