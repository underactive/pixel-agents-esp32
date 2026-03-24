# Audit: Add Sound Support to CYD Board

## Files Changed

- `firmware/src/sound.cpp` — All audit categories reviewed this file
- `firmware/src/config.h` — QA, Security, Resource audits
- `firmware/platformio.ini` — QA audit
- `firmware/src/main.cpp` — State management, interface contract audits (dependent)
- `firmware/src/office_state.cpp` — Interface contract, state management audits (dependent)
- `firmware/src/touch_input.cpp` — Resource audit (dependent, I2C bus sharing on CYD-S3)

## Consolidated Findings

### 1. QA Audit
No critical issues. All core workflows correct. Bounds checks, loop termination, and edge cases handled properly. The `len & ~1u` truncation at `startClip()` guarantees even-length buffers, preventing off-by-one in the sample loop.

### 2. Security Audit
**S1 (Medium, pre-existing):** ES8311 codec handle not freed if `es8311_init()` fails after successful `es8311_create()` — CYD-S3 code path only, not introduced by this change.

**S2 (Medium, pre-existing):** I2S driver not uninstalled on ES8311 init failure — CYD-S3 code path only, not introduced by this change.

**S3 (Low, pre-existing):** Wire I2C bus not deinitialized on ES8311 init failure — CYD-S3 only.

**S4 (Low):** Type mismatch between `_byteOffset` (size_t) and `_pcmLen` (uint32_t) — cosmetic, safe on ESP32 where both are 32-bit.

### 3. Interface Contract Audit
No critical issues. Single-slot sound queue (last-writer-wins) is intentional and documented. `SoundId::COUNT` sentinel correctly bounds array access. No-op stubs for boards without `HAS_SOUND` provide clean degradation.

### 4. State Management Audit
No issues. Mutation discipline is clean — all state changes go through designated methods. Single-threaded main loop eliminates concurrency concerns. `_pet.pendingSound` initialized to `SoundId::COUNT` in `initPet()`.

### 5. Resource & Concurrency Audit
**R1 (flagged Critical, actually pre-existing):** I2C bus shared between ES8311 codec and FT6336G capacitive touch on CYD-S3. Both use pins 15/16. This is a pre-existing hardware design constraint, not introduced by this change. The CYD board (which this change adds sound to) uses internal DAC with no I2C.

**R2 (flagged Critical, by design):** No `i2s_driver_uninstall()` call. SoundPlayer is a program-lifetime singleton with `if (_ready) return;` guard preventing double-init. No cleanup needed.

**R3 (flagged Medium, false positive):** Non-atomic state mutation. All SoundPlayer methods are called from the single-threaded main loop. `i2s_write()` copies data to DMA buffers synchronously — no ISR reads SoundPlayer state.

**R4 (flagged Medium, pre-existing):** Blocking `delay(10)` in `startClip()` for amp stabilization — CYD-S3 only (`#if SOUND_HAS_AMP_ENABLE`), not introduced by this change.

**R5 (Low):** DMA buffer sizing on CYD (8x256) provides ~85ms of buffering at 24kHz. Adequate for 15 FPS main loop (~66ms/frame).

### 6. Testing Coverage Audit
[FIXED] **T1 (High):** `i2s_set_dac_mode()` return value not checked in CYD `initI2S()`. Fixed: added error check with `i2s_driver_uninstall()` cleanup on failure.

**T2 (Medium):** No checklist item for DAC initialization failure recovery. Acceptable — hardware testing checklist covers observable behavior; internal error paths are verified by code review.

**T3 (Low):** No boundary value testing for `SOUND_VOLUME_SHIFT` signed right-shift. Safe: arithmetic right-shift is guaranteed on ESP32 (GCC), and shift value of 2 is well within int16_t range.

### 7. DX & Maintainability Audit
**D1 (Medium):** Conditional compilation coupling across `SOUND_DAC_INTERNAL` — two I2S backends with different init paths. Acceptable complexity for a two-board abstraction; both paths are clearly separated with comments.

**D2 (Low-Medium):** Several documentation suggestions (PCM endianness assumption, amp delay rationale, backend selection comment). These are nice-to-haves for the existing code structure.

## Summary

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| QA | 0 | 0 | 0 | 0 |
| Security | 0 | 0 | 2 (pre-existing) | 2 |
| Interface Contract | 0 | 0 | 0 | 0 |
| State Management | 0 | 0 | 0 | 0 |
| Resource & Concurrency | 0 | 0 | 0 (all pre-existing/false positive) | 1 |
| Testing Coverage | 0 | 0 (1 fixed) | 1 | 1 |
| DX & Maintainability | 0 | 0 | 1 | 1 |

**One actionable fix applied:** Added `i2s_set_dac_mode()` error check with I2S driver cleanup on failure (T1).

All other findings are either pre-existing in the CYD-S3 code path, by design, or false positives. No new critical or high-severity issues introduced by this change.
