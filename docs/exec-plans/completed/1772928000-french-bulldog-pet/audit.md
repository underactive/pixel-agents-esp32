# Audit Report: French Bulldog Pet

## Files changed

- `firmware/src/config.h`
- `firmware/src/office_state.h`
- `firmware/src/office_state.cpp`
- `firmware/src/renderer.h`
- `firmware/src/renderer.cpp`
- `firmware/src/sprites/dog.h`
- `tools/convert_dog.py`

---

## 1. QA Audit

**Q1 (Critical):** [FIXED] Out-of-bounds `chars[-1]` access in bubble-drawing loop when dog sentinel index `-1` is not filtered. Fixed by adding `if (indices[i] < 0) continue;` guard at `renderer.cpp:188`.

**Q2 (Low):** [FIXED] Confusing split control flow in `drawDog()` with early return inside else branch. Refactored to flat if/else structure with single draw call.

**Q3 (Low):** `repathTimer` relies on `memset` zero-initialization rather than explicit assignment. Accepted — `memset` in `initPet()` is the designated initializer and zeroing timers is intentional.

**Q4 (Medium):** `petPickTarget()` doesn't reset `followTarget` to `-1` when no alive candidates exist. Accepted — all characters are always alive after `spawnAllCharacters()`, so the zero-candidate path is unreachable.

**Q6 (Low):** WANDER-to-FOLLOW transition doesn't validate whether existing `followTarget` is still alive. Accepted — characters never die in this codebase.

**Q8 (Low):** Dog is not included in touch hit-testing on CYD. Accepted — touch interaction is character-specific; tapping the dog has no defined behavior.

**Q12 (Low):** Pet struct adds ~160 bytes of fixed overhead regardless of feature use. Accepted — minimal impact on CYD (no PSRAM) given total RAM budget.

---

## 2. Security Audit

**S1 (Informational):** Unclamped `Dir` enum value could produce out-of-range `frameIdx`. Already guarded by bounds check at `renderer.cpp:335` (`if (frameIdx < 0 || frameIdx >= DOG_FRAME_COUNT) frameIdx = 1`).

**S2 (Informational):** Pre-existing inconsistency — `CHAR_SPRITES` accessed without `pgm_read_ptr` while `DOG_SPRITES` correctly uses it. Not introduced by this feature; ESP32 PROGMEM is memory-mapped so no crash risk.

**S3 (Low):** `memcpy` of pet path buffer without separate bounds check. Both source (`pathBuf[64]`) and destination (`_pet.path[64]`) are exactly 64 elements, and `findPath()` caps `outLen` at 64. Safe.

---

## 3. Interface Contract Audit

**I1 (Medium):** Pet state not reset on serial disconnect. Accepted — the pet is connection-agnostic by design. Characters remain alive through disconnects, so `followTarget` remains valid. The pet's behavior is purely cosmetic and doesn't depend on agent assignment state.

**I2 (Low):** [FIXED] Double `memset` of `_pet` — once in `init()` and again in `initPet()`. Removed the redundant initialization from `init()` since `initPet()` fully handles pet setup.

---

## 4. State Management Audit

**M1 (Medium):** Pet state not reset on disconnect. Same as I1 — accepted by design.

**M2 (Low):** [FIXED] Same as I2 — removed redundant `memset` from `init()`.

**M3 (Medium):** `followTarget` can reference a dead character between repathfind intervals. Accepted — characters are always alive after spawn in this codebase.

---

## 5. Resource & Concurrency Audit

**R1 (Informational):** No concurrency issues — single-threaded Arduino loop model, all state mutations sequential.

**R2 (Medium):** BFS `findPath()` stack usage (~1.4KB per call) now has an additional consumer (pet). Pre-existing pattern; calls are sequential (never nested), peak stack depth unchanged. ESP32 default 8KB stack provides adequate margin.

**R3 (Low):** Same as I1/M1 — pet not reset on disconnect. Accepted by design.

---

## 6. Testing Coverage Audit

**T1 (High):** [FIXED] No manual test checklist items for dog pet feature. Added comprehensive dog testing items to `testing-checklist.md`.

**T2 (Medium):** No visual verification of dog sprites in `sprite_validation.html`. Accepted — sprites verified via `convert_dog.py` row-width assertions and manual inspection of generated hex data. Future improvement: integrate dog frames into validation HTML.

**T3 (Medium):** [FIXED] No test item for `convert_dog.py` execution. Added to testing checklist.

**T4 (Medium):** No long-running test for dog behavior timers spanning hours. Accepted — existing stress test item ("Long-running session 1+ hour") covers general stability. Dog-specific timer verification requires accelerated testing, noted as future improvement.

---

## 7. DX & Maintainability Audit

**D1 (Medium):** Control flow in `drawDog()` described as confusing. The auditor appears to have analyzed a pre-fix version — the current code is already flat (if/else → compute frameIdx → bounds check → single draw call). No action needed.

**D2 (Critical):** [FIXED] Same as Q1 — out-of-bounds bubble loop access. Already fixed.

**D3 (Medium):** [FIXED] Magic numbers `3` and `9` in `drawDog()` frame layout. Added `DOG_FRAMES_PER_DIR` and `DOG_NAP_FRAME_IDX` constants to `config.h` and updated renderer.

**D4 (Medium):** [FIXED] Magic timer values `2.0f`, `6.0f`, `3.0f`, `10.0f` in pet FSM. Added `DOG_WANDER_PAUSE_MIN_SEC`, `DOG_WANDER_PAUSE_MAX_SEC`, `DOG_WANDER_MOVE_MIN_SEC`, `DOG_WANDER_MOVE_MAX_SEC` constants to `config.h` and updated office_state.

**D5 (Medium):** `updatePet()` exceeds 50-line guideline (~139 lines). Accepted — the function is a self-contained FSM with clear switch/case structure. Extracting walk movement would add indirection without improving clarity for a two-use pattern.

**D6 (Medium):** Duplicated walk-movement physics between pet and character. Accepted — extracting a shared helper would require a generic walk-state struct abstraction for only two consumers. The duplication is explicit and localized.

**D7 (Low):** Unused color `P` (pink) in `convert_dog.py` palette. Accepted — retained for potential future sprite iteration (tongue/inner ear detail).

**D8 (Low):** `DOG_FRAME_PIXELS` define in `dog.h` is unused. Accepted — generated metadata, consistent with similar patterns in other sprite headers.

**D9 (Low):** No doc comments on `Pet` struct fields. The fields follow the same naming conventions as `Character` struct. Accepted.

**D10 (Low):** Fallback placement in `initPet()` uses magic coordinates `(5, 3)`. Accepted — this is a last-resort fallback after 40 random attempts; the specific tile is less important than having any valid position.

**D11 (Low):** `convert_dog.py` not integrated into `sprite_converter.py`. Accepted — the dog sprite has a different format (direct RGB565 vs indexed template+palette) and a separate generator avoids coupling. Build instructions updated.
