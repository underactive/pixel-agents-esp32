# Implementation: Microphone Loopback Proof-of-Concept (CYD-S3)

## Files Changed

| File | Change |
|------|--------|
| `firmware/src/config.h` | Added `HAS_MIC` define, mic constants (`SOUND_MIC_RECORD_MAX_MS`, `SOUND_MIC_BUF_SAMPLES`, `SOUND_MIC_BUF_BYTES`), conditional `MENU_H` increase to 130 |
| `firmware/src/sound.h` | Added `MicTestPhase` enum, recording methods (`startRecording`, `stopRecording`, `playRecording`, `micTestPhase`), private recording state |
| `firmware/src/sound.cpp` | Changed I2S to full-duplex (TX+RX), connected `data_in_num` to GPIO 6, added mic init via ES8311 API (42dB PGA), blocking recording drain in `update()`, PSRAM buffer lifecycle via `heap_caps_malloc`, 8x software gain in `playRecording()`, auto-play on recording completion |
| `firmware/src/office_state.cpp` | Added menu item 7 hit-test for mic test row |
| `firmware/src/renderer.h` | Added `setMicTestPhase()` method and `_micPhase` private member |
| `firmware/src/renderer.cpp` | Added "Mic Test" label row in `drawMenuOverlay()`, floating "REC"/"PLAY" indicator in `drawScene()` |
| `firmware/src/main.cpp` | Menu item 7 handler, `renderer.setMicTestPhase()` call for PLAY indicator overlay |

## Summary

All 7 files from the plan were modified. The implementation follows the plan's design decisions:

1. **Full-duplex I2S (TX+RX on same port)** — `I2S_MODE_MASTER | I2S_MODE_TX | I2S_MODE_RX` with `SOUND_I2S_DINT` connected
2. **Record mono from stereo I2S RX** — Left channel extracted from interleaved stereo frames
3. **PSRAM buffer on demand** — `heap_caps_malloc(MALLOC_CAP_SPIRAM)` on mic test start, `free()` after playback in `endClip()`
4. **Blocking recording drain** — Tight `for(;;)` loop in `update()` drains all I2S RX DMA buffers for ~2 seconds, then auto-calls `playRecording()`
5. **Software gain amplification** — 42dB hardware PGA + 8x software gain to bring mic signal to audible level
6. **Reuse existing playback pipeline** — `startClip(_recBuf, _recLen)` works because `pgm_read_byte()` on ESP32 is a plain memory read
6. **Compile-time gating** — All mic code wrapped in `#if defined(HAS_MIC)`, only active for CYD-S3

**Additions beyond plan:**
- Floating "REC"/"PLAY" indicator overlay in `drawScene()` — centered banner with blinking dot and progress bar (REC only renders on non-blocking approach; display freezes during current blocking drain)
- Software gain amplification (8x) in `playRecording()` — ES8311 ADC output is well below full scale
- Direct `playRecording()` call from recording completion in `update()` — the blocking drain loop prevents the cross-module phase-transition detector from working

**Deviations from plan:**
- `ps_malloc()` replaced with `heap_caps_malloc(size, MALLOC_CAP_SPIRAM)` — more reliable on pioarduino builds
- Phase-transition detector removed from `main.cpp` — recording now auto-plays directly from `update()` after the blocking drain completes
- PGA gain: 42dB (plan said 24dB) — mic signal required higher analog gain for audibility

## Verification

- [x] `pio run -e freenove-s3-28c` compiles without errors (CYD-S3 with mic code)
- [ ] `pio run -e cyd-2432s028r` compiles without errors (CYD without mic code)
- [ ] `pio run -e lilygo-t-display-s3` compiles without errors (no touch, no sound, no mic)
- [x] Hardware test: flash to Freenove board, open menu, tap "Mic Test", speak, hear playback
- [x] Normal sound effects still work after mic test
- [x] Touch input still works (I2C bus sharing)

## Follow-ups

- Recording time (2s) may need adjustment based on real-world use
- Display freezes during 2-second recording — could switch to non-blocking approach with per-frame DMA drain if this bothers users
- Future: transport mic audio to companion for STT processing

## Audit Fixes (Wake Word + Mic Test Removal)

Fixes applied against the consolidated wake word audit (`audit.md`).

### Fixes applied

1. **`volatile bool _paused` → `std::atomic<bool> _paused`** — fixes S2/SM1/R1/D2/I2 (cross-core sync without memory ordering guarantees)
2. **Add double-begin guard: `if (_ready) return false`** — fixes S3 (duplicate detection tasks on repeated `begin()`)
3. **Validate `s_chunkSize > 0` after `get_samp_chunksize()`** — fixes Q2/S5 (zero chunk size → infinite loop)
4. **Free non-null PSRAM buffers on partial allocation failure** — fixes Q1/S1/R3/SM5 (memory leak when only some buffers succeed)
5. **Route wake word bark through `office.queueSound()` instead of `sound.play()`** — fixes Q6 (bark played even with sound toggled off)
6. **Add WHY comment on 42dB mic gain** — fixes Q4/D7 (undocumented gain change from 24dB)
7. **Add WHY comment on downsample algorithm** — fixes D5 (reader can't tell if simple resampler was deliberate)
8. **Replace magic numbers with named constants** — fixes D1 (stack size, priority, core, pause delay, flush params, I2S timeout)
9. **Remove redundant `static` from anonymous namespace** — fixes D6 (style inconsistency)
10. **Fix stale "mic test" comment on `pause()`** — fixes Q5/I6 (references removed feature)
11. **Add "never freed" comment on PSRAM buffers** — fixes D12 (unclear lifetime intent)
12. **Move `WAKEWORD_COOLDOWN_MS` under `#if defined(HAS_WAKEWORD)`** — fixes D9 (constant inside board-specific block)
13. **Add 10 wake word test items to testing checklist** — fixes T1 (critical: zero test coverage) and T2 (mic test removal verification)

### Verification checklist

- [ ] CYD-S3 build compiles without errors (`pio run -e freenove-s3-28c`)
- [ ] CYD build compiles without errors (`pio run -e cyd-2432s028r`)
- [ ] LILYGO build compiles without errors (`pio run -e lilygo-t-display-s3`)
- [ ] Wake word bark respects sound toggle (toggle OFF → say "Computer" → no bark)
- [ ] Wake word still triggers when sound is ON
- [ ] No regression in existing sound effects after `queueSound()` routing change

### Unresolved items

- **S4/D3/SM4/R4 (task handle not stored):** Accepted — detection task runs for device lifetime; no orderly shutdown path needed. Adding a handle would add complexity with no practical benefit.
- **Q3/S7 (downsample OOB on odd chunks):** Accepted with comment — WakeNet chunk sizes (480, 512) are always even. Added "Note: safe for WakeNet chunk sizes" comment.
- **I1/R2/R6 (TOCTOU race / 100ms stall):** Accepted — serialized by I2S driver internal mutex; no data corruption. Post-pause DMA flush mitigates false detections. The 100ms worst-case stall on Core 1 is acceptable for 15 FPS rendering.
- **SM9 (double-trigger race):** Accepted — mitigated by 5s cooldown which exceeds all sound clip durations.
- **R7 (watchdog starvation):** Monitor on hardware — WakeNet inference may starve Core 0 idle task. If TWDT fires, add `esp_task_wdt_reset()` call after `detect()`.
- **D4 (detectTask length):** Accepted — 85 lines is manageable for a self-contained audio pipeline. Extracting helpers would fragment the data flow.
- **D8/T7 (DOG_BARK is placeholder):** Accepted — intentional demo behavior for POC phase.
- **D11 (partition migration notes):** Deferred — will address when documenting the full flash procedure for end users.
- **T3-T8 (untested paths):** Accepted — hardware-dependent code has no automated test path; manual testing checklist items added.
