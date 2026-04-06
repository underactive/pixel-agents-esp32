# Audit: Wake Word Detection + Mic Test Removal (CYD-S3)

Supersedes the original mic loopback POC audit. Covers the full staged changeset: ESP-SR WakeNet9 wake word detection addition and mic loopback test feature removal.

## Files Changed

| File | Findings |
|------|----------|
| `firmware/src/wakeword.cpp` | S1, S3, S4, S5, S6, I1, SM1, SM4, SM5, R1, R2, R3, R4, R5, R7, R8, R9, T3, T4, D1, D3, D4, D5, D6, D12 |
| `firmware/src/wakeword.h` | S2, SM1, R1, D2, D10 |
| `firmware/src/sound.cpp` | I1, SM8, R6, T5, T6, D7 |
| `firmware/src/main.cpp` | S6, SM6, SM9, R10, T7, D8 |
| `firmware/src/config.h` | D9, T10 |
| `firmware/partitions_sr_16MB.csv` | S8, T8, D11 |
| `firmware/platformio.ini` | D11 |
| `firmware/src/renderer.cpp` | (no findings) |
| `firmware/src/renderer.h` | (no findings) |
| `firmware/src/sound.h` | (no findings) |
| `docs/references/testing-checklist.md` | T1, T2 |

---

## 1. QA Audit

**[FIXED] Q1 (warning): Memory leak on partial PSRAM allocation failure** (`wakeword.cpp:109-113`)
If `stereoBuf` succeeds but `mono24k` or `feed16k` fails, previously allocated buffers are not freed before `vTaskDelete(nullptr)`. Add `heap_caps_free()` for non-null buffers before task deletion.

**[FIXED] Q2 (warning): No validation that `s_chunkSize` is positive** (`wakeword.cpp:55`)
If `get_samp_chunksize()` returns 0, `in24k` is 0, `stereoBytes` is 0, and the loop spins on zero-byte I2S reads. Add: `if (s_chunkSize <= 0) return false;`.

**Q3 (warning): Downsample out-of-bounds access when `out16k` is odd** (`wakeword.cpp:159-166`)
When last output index `j` is odd, `idx + 1` could reach `in24k` (one past buffer). Safe for typical WakeNet chunk sizes (480, 512) which are even, but lacks a bounds guard.

**[FIXED] Q4 (warning): Mic gain changed from 24dB to 42dB without documentation** (`sound.cpp:152`)
`ES8311_MIC_GAIN_42DB` vs. the 24dB used in the previous mic loopback. Likely intentional for wake word sensitivity, but should be documented.

**[FIXED] Q5 (info): Stale comment references "mic test"** (`wakeword.h:16`)
Comment on `pause()` says "for sound playback / mic test" — mic test has been removed.

**[FIXED] Q6 (warning): Wake word bark bypasses `isSoundEnabled()` check** (`main.cpp:241`)
`sound.play(SoundId::DOG_BARK)` is called directly instead of through `office.queueSound()`. Other sound triggers use `queueSound()` which checks `_soundEnabled`. The dog bark will play even when sound is toggled off in the hamburger menu.

---

## 2. Security Audit

**[FIXED] S1 (warning): Memory leak on partial allocation failure** (`wakeword.cpp:109-113`)
Same as Q1. Partial PSRAM allocation not cleaned up before task deletion.

**[FIXED] S2 (warning): `volatile bool _paused` should be `std::atomic<bool>`** (`wakeword.h:22`)
Written on Core 1, read on Core 0. `volatile` does not guarantee memory ordering across cores. Should use `std::atomic<bool>` to match the convention already used for `_detected`.

**[FIXED] S3 (warning): No guard against double `begin()` call** (`wakeword.cpp:26`)
Would spawn duplicate detection tasks. Add a guard: `if (_ready) return false;` or `if (s_instance) return false;`.

**S4 (warning): FreeRTOS task handle not stored** (`wakeword.cpp:64`)
Passed `nullptr` — no way to stop/manage detection task for lifecycle management.

**[FIXED] S5 (info): `s_chunkSize` not validated for zero/negative** (`wakeword.cpp:55`)
Same as Q2.

**S6 (info): Wake word init failure is non-persistent** (`main.cpp:151-155`)
Failure only shown in splash log (transient). No persistent indicator or retry mechanism. Acceptable for current use.

**S7 (info): Downsampler boundary math safe but no runtime bounds check** (`wakeword.cpp:160`)
Same as Q3.

**S8 (info): OTA capability removed for CYD-S3** (`partitions_sr_16MB.csv`)
Custom partition table drops OTA partition. Documented in partition CSV comments.

---

## 3. Interface Contract Audit

**I1 (medium): Race between pause and `i2s_zero_dma_buffer()`** (`sound.cpp:170-181`, `wakeword.cpp:117-148`)
`startClip()` calls `wakeword_pause()` then immediately `i2s_zero_dma_buffer()`. Detection task on Core 0 may still be inside `i2s_read()`. At the I2S driver level the calls serialize via internal mutexes (no data corruption), but `i2s_zero_dma_buffer()` may block Core 1 for up to 100ms. After resume, the post-pause DMA flush in the detection task discards stale data, which mitigates false detections.

**[FIXED] I2 (low): `volatile` vs `std::atomic` for `_paused`** (`wakeword.h:22`)
Same as S2.

**I3 (low): Post-pause DMA flush budget** (`wakeword.cpp:126-139`)
Analysis shows 16 iterations × 512 samples is sufficient to drain the I2S RX DMA buffer (12 × 512 = 6144 samples). Flush is bounded and correct.

**I4 (info): No task handle for cleanup** (`wakeword.cpp:64`)
Same as S4.

**I5 (info): Buffer alloc failure leaves `_ready=true` and `s_instance` set** (`wakeword.cpp:109-112`)
If allocation fails in `detectTask`, the task deletes itself but `_ready` and `s_instance` remain set from `begin()`. `poll()` would return false (no detection), so this is benign, but `_ready` is misleading.

**[FIXED] I6 (info): Stale comment references "mic test"** (`wakeword.h:16`)
Same as Q5.

---

## 4. State Management Audit

**[FIXED] SM1 (warning): `_paused` should be `std::atomic<bool>`** (`wakeword.h:22`)
Same as S2. Cross-core read/write without acquire/release semantics. ESP32-S3 Xtensa is cache-coherent for single-byte writes, so this works in practice, but violates the pattern used by adjacent `_detected`.

**SM2 (info): `s_instance` raw pointer has no ordering guarantee with `_ready`** (`wakeword.cpp:60`)
Both writes are on Core 1 and `xTaskCreatePinnedToCore` includes a full memory barrier, so detection task sees consistent state. Safe but relies on implicit FreeRTOS guarantee.

**SM3 (info): Up to 50ms delay between `resume()` and detection task resuming** (`wakeword.cpp:121`)
Detection task polls `_paused` every 50ms. Documented and acceptable.

**SM4 (info): Task handle not stored** (`wakeword.cpp:64`)
Same as S4. No orderly shutdown path.

**[FIXED] SM5 (info): Partial allocation leak** (`wakeword.cpp:109-113`)
Same as Q1/S1.

**SM6 (info): `lastWakeMs` is single-core** (`main.cpp`)
Only accessed in main loop on Core 1. No concurrency issue.

**SM7 (info): Pause/resume bracket around sound playback is correct** (`sound.cpp`)
Cross-module coordination via free functions is well-structured. DMA flush after unpause correctly discards stale RX data.

**SM8 (info): I2S port contention model is implicit** (`sound.cpp`)
TX and RX use separate internal mutexes. Pause/resume adds further software exclusion. Correct but rationale not documented.

**SM9 (warning): Double-trigger race window** (`main.cpp:240-243`)
Between `poll()` clearing `_detected` and `wakeword_pause()` setting `_paused`, detection task could set `_detected` again. `WAKEWORD_COOLDOWN_MS` (5s) mitigates this since sound clips are shorter than 5s.

---

## 5. Resource & Concurrency Audit

**[FIXED] R1 (warning): `volatile bool _paused` insufficient for cross-core sync** (`wakeword.h:22`)
Same as S2/SM1. Should be `std::atomic<bool>`.

**R2 (warning): TOCTOU between pause and `i2s_zero_dma_buffer()`** (`sound.cpp`, `wakeword.cpp`)
Same as I1. At driver level calls serialize via internal mutexes — no data corruption. Main concern is up to 100ms latency stall on Core 1. Post-pause DMA flush mitigates false detections from stale audio.

**[FIXED] R3 (warning): Memory leak on partial allocation failure** (`wakeword.cpp:109-113`)
Same as Q1/S1.

**R4 (warning): Task handle not stored** (`wakeword.cpp:64`)
Same as S4.

**[FIXED] R5 (warning): Downsample out-of-bounds on odd chunk sizes** (`wakeword.cpp:159-166`)
Same as Q3.

**R6 (warning): `i2s_zero_dma_buffer()` in `startClip()` may block 100ms** (`sound.cpp`)
If detection task is inside `i2s_read()`, the shared driver mutex causes `i2s_zero_dma_buffer()` to wait. Could stall the main loop rendering.

**R7 (warning): WakeNet `detect()` may starve Core 0 watchdog** (`wakeword.cpp:170`)
Neural net inference at priority 5 may prevent idle task from feeding watchdog. Consider `esp_task_wdt_reset()` or TWDT registration.

**R8 (info): File-scope statics rely on implicit FreeRTOS barrier** (`wakeword.cpp`)
`s_wn`, `s_wnData`, `s_chunkSize` written before `xTaskCreatePinnedToCore()` which includes a full memory barrier. Safe but undocumented.

**R9 (info): 1024-byte `discard` buffer on 12KB task stack** (`wakeword.cpp:134`)
Within budget but notable. If stack size is reduced, this could overflow.

**R10 (info): Wake word detection pauses detector for bark duration + cooldown** (`main.cpp`)
Design observation, not a bug. Detection is deaf during sound playback.

---

## 6. Testing Coverage Audit

**[FIXED] T1 (critical): No wake word testing items in checklist** (`docs/references/testing-checklist.md`)
New WakeWord subsystem has zero test items. Needed:
- Boot log shows "Wake word ready" on CYD-S3
- Saying "Computer" triggers DOG_BARK sound
- Cooldown prevents re-trigger within 5s
- Wake word pauses during sound playback and resumes after
- No false detection after sound playback ends
- CYD/LILYGO builds unaffected (no `HAS_WAKEWORD`)
- Init failure is non-fatal (logs message, device continues)

**[FIXED] T2 (warning): Mic test removal not verified in checklist** (`docs/references/testing-checklist.md`)
Mic test items were removed but no verification that hamburger menu no longer shows "Mic Test" row.

**T3 (warning): Downsample algorithm untested** (`wakeword.cpp:159-167`)
3:2 downsample math is non-trivial. No automated test. Manual testing is the only validation path.

**T4 (warning): Buffer allocation failure path untested** (`wakeword.cpp:109-113`)
PSRAM exhaustion scenario has no test coverage.

**T5 (warning): I2S full-duplex mode change needs regression testing** (`sound.cpp:87`)
Changed from TX-only to TX+RX. All CYD-S3 sound playback is affected. Need checklist item verifying existing sound effects still work.

**T6 (warning): Pause/resume integration needs test item** (`sound.cpp`)
False detection after sound playback end should be verified.

**T7 (info): Wake word action is hardcoded placeholder** (`main.cpp:241`)
DOG_BARK on detection. Add test item verifying expected behavior.

**T8 (info): Custom partition table needs build verification** (`partitions_sr_16MB.csv`)
Need test items: CYD-S3 builds and uploads; missing srmodels.bin shows error and continues.

**T10 (info): `HAS_MIC` removal verified** (`config.h`)
Confirmed zero remaining references in codebase.

---

## 7. DX & Maintainability Audit

**[FIXED] D1 (warning): Magic numbers in `wakeword.cpp`** (`wakeword.cpp`)
`12288` (stack), `5` (priority), `0` (core), `50` (pause delay ms), `512` (discard samples), `16` (flush iterations), `100` (I2S timeout ms) should be named constants in `config.h` or at file scope.

**[FIXED] D2 (warning): `volatile` vs `std::atomic` inconsistency** (`wakeword.h`)
Same as S2. Inconsistent with adjacent `_detected` field.

**D3 (warning): Task handle not stored** (`wakeword.cpp:64`)
Same as S4.

**D4 (info): `detectTask` exceeds ~50 lines** (`wakeword.cpp:90-175`)
At ~85 lines. Consider extracting buffer allocation, pause/flush logic, and downsample+detect into named helpers.

**[FIXED] D5 (warning): No `// WHY:` comment on downsample algorithm** (`wakeword.cpp:155-167`)
Reader cannot tell whether simple point-sample/average interleave was chosen deliberately vs. a proper resampler.

**[FIXED] D6 (info): `static` inside anonymous namespace is redundant** (`wakeword.cpp:13-16`)
Anonymous namespace already provides internal linkage. `static` keyword is unnecessary.

**[FIXED] D7 (warning): Mic gain change undocumented** (`sound.cpp:152`)
Same as Q4. 42dB vs previous 24dB — needs `// WHY:` comment.

**D8 (info): Wake word action is placeholder** (`main.cpp:240-243`)
Same as T7. DOG_BARK is the demo behavior. Add comment if intentional.

**[FIXED] D9 (warning): `WAKEWORD_COOLDOWN_MS` inside board-specific block** (`config.h:346`)
Defined inside `BOARD_CYD_S3` section. If wake word is added to another board, this constant would need duplication. Consider moving under `#if defined(HAS_WAKEWORD)`.

**D10 (info): No helpful error when `wakeword.h` included without `HAS_WAKEWORD`** (`wakeword.h`)
Class is intentionally omitted in `#else` block. Brief comment would help.

**D11 (warning): Partition table change lacks migration notes** (`platformio.ini`, `partitions_sr_16MB.csv`)
Breaking change for existing CYD-S3 users. CLAUDE.md Build Instructions should include the `esptool.py write_flash` command from the partition CSV header.

**[FIXED] D12 (info): PSRAM buffers intentionally never freed** (`wakeword.cpp`)
`stereoBuf`, `mono24k`, `feed16k` persist for device lifetime. Correct for never-exiting task but deserves a comment.
