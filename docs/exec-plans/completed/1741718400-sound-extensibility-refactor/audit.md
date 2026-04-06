# Sound Extensibility Refactor — Audit

## Files Changed

Files where findings were flagged (including immediate dependents not in the original implementation):

| File | Audits with findings |
|------|---------------------|
| `firmware/src/sound.cpp` | Security (S1-S3), QA (Q2-Q4, Q6), State (M2, M4), Resource (R1-R3), Interface (I2, I4), DX (D1-D2), Testing (T3, T5) |
| `firmware/src/sound.h` | Interface (I1), DX (D5) |
| `firmware/src/office_state.cpp` | Security (S4), QA (Q5, Q7), State (M1, M3, M5), Interface (I3), DX (D4), Testing (T4, T7) |
| `firmware/src/office_state.h` | QA (Q1, Q8), State (M1), Interface (I3), DX (D3), Testing (T4) |
| `firmware/src/main.cpp` | QA (Q11), DX (D9), Testing (T7) |
| `firmware/src/config.h` | Resource (R4) |
| `tools/convert_sound.py` | Security (S5-S8), QA (Q9-Q10), DX (D6-D7), Testing (T1, T2, T6, T8) |
| `docs/references/testing-checklist.md` | Testing (T6) |

---

## 1. QA Audit

**Q1 — MEDIUM — `office_state.cpp` (`init()`) / `office_state.h` (line 91)**
`_pet.pendingSound` not initialized in `OfficeState::init()`. Between `init()` and `spawnAllCharacters()` -> `initPet()`, the zero-initialized `SoundId(0)` == `SoundId::STARTUP` could cause a phantom startup sound if `consumePendingSound()` is ever called in that window.

**Q2 — MEDIUM — `sound.cpp:114-115` (`startClip`)**
`delay(10)` blocks the main loop for 10ms (~15% of 66ms frame budget). Acceptable for rare events but would cause frame drops if sounds become frequent.

**[FIXED] Q3 — MEDIUM — `sound.cpp:126-132` and `158-163` (`update`)**
Duplicated end-of-clip cleanup code in two places within `update()`. Should extract to an inline helper.

**Q4 — MEDIUM — `sound.cpp:156-157` (`update`)**
Partial I2S write could theoretically cause mono/stereo accounting mismatch. In practice ESP-IDF writes in DMA-buffer-sized units, making this unlikely.

**[FIXED] Q5 — MEDIUM — `office_state.cpp:1362-1369` (`setDogEnabled`)**
Disabling the dog does not clear `_pet.pendingSound`, so a bark queued in the same frame survives and plays.

**[FIXED] Q6 — LOW — `sound.cpp:140-146` (`update`)**
Odd-length PCM data could cause a one-byte overread. PCM should always be even-length, but not enforced.

**[FIXED] Q7 — LOW — `office_state.cpp:1102` (`petPickTarget`)**
Direct field write `_pet.pendingSound = SoundId::DOG_BARK` bypasses public `queueSound()` API.

**Q8 — LOW — `office_state.h:91` / `office_state.cpp:1384-1392`**
`pendingSound` scoped to `Pet` but serves as office-wide sound queue. Limits future extensibility.

**[FIXED] Q9 — LOW — `convert_sound.py:32-47` (`slugify`)**
Can return empty string for certain filenames (e.g., `dragon-studio-494308.mp3`).

**Q10 — LOW — `convert_sound.py:52-66` (`convert_mp3_to_pcm`)**
`NamedTemporaryFile(delete=True)` relies on POSIX semantics. Works on macOS/Linux but would fail on Windows.

**[FIXED] Q11 — LOW — `main.cpp:10-12`**
Conditional `#include "sound.h"` is misleading — `office_state.h` already includes it unconditionally.

---

## 2. Security Audit

**S1 — LOW — `sound.cpp:106-108` (`play`)**
Bounds check on `SoundId` uses `static_cast<uint8_t>` comparison. Correct for the current enum range but would silently pass if `COUNT` ever exceeds 255.

**S2 — LOW — `sound.cpp:112` (`startClip`)**
Null/zero-length checks present. No vulnerability.

**[FIXED] S3 — LOW — `sound.cpp:140-146` (`update`)**
Same as Q6: potential one-byte overread with odd-length PCM. Defense: truncate to even in `startClip()`.

**[FIXED] S4 — LOW — `office_state.cpp:1102`**
Direct field write bypasses `queueSound()`. No security impact but reduces auditability.

**S5 — LOW — `convert_sound.py:53-59`**
`mp3_path` passed to ffmpeg subprocess via list (not shell). No injection risk.

**S6 — LOW — `convert_sound.py:104`**
Output path constructed from sanitized slug + fixed suffix. No path traversal risk.

**S7 — LOW — `convert_sound.py:140`**
User-supplied path resolved via `Path.resolve()`. Safe.

**S8 — LOW — `convert_sound.py:61`**
ffmpeg exit code checked, stderr printed on failure. Adequate error handling.

---

## 3. Interface Contract Audit

**I1 — LOW — `sound.h:5-9`**
`SoundId::COUNT` sentinel documented in comment. Adequate.

**I2 — LOW — `sound.cpp:25-26`**
`static_assert` enforces table-enum sync. Good defensive design.

**I3 — MEDIUM — `office_state.h:141-142` / `office_state.cpp:1384-1392`**
`consumePendingSound()` and `queueSound()` are public on `OfficeState` but backed by `_pet.pendingSound`. Semantic mismatch: the public API suggests office-wide sound queueing but implementation is pet-scoped.

**I4 — LOW — `sound.cpp:150`**
`i2s_write()` with timeout 0 (non-blocking). Partial writes handled correctly.

**I5 — LOW — `sound.cpp:67-103` (`begin`)**
I2S/codec init sequence follows ESP-IDF conventions. Error paths print to Serial and return without setting `_ready`.

**I6 — LOW — `sound.h` / `office_state.h`**
`office_state.h` includes `sound.h` for `SoundId` type. Creates a compile-time dependency but acceptable given the tight coupling.

**I7 — LOW — `main.cpp:217-224`**
Dispatch pattern (consume + play) is clean and idiomatic.

---

## 4. State Management Audit

**M1 — MEDIUM — `office_state.h:91` / `office_state.cpp:1390-1392`**
`pendingSound` lives on `Pet` struct but `queueSound()` is a general-purpose public API on `OfficeState`. If non-pet sounds are added, the field location becomes semantically wrong.

**M2 — LOW — `sound.cpp:116-120` (`startClip`)**
State mutation sequence (`_pcm`, `_pcmLen`, `_byteOffset`, `_playing`) is correct. No intermediate invalid state observable since all runs on main loop.

**M3 — LOW — `office_state.cpp:1038`**
`initPet()` correctly initializes `pendingSound = SoundId::COUNT`.

**M4 — LOW — `sound.cpp:127-131` and `159-163`**
Stop-state cleanup correctly nulls `_pcm` and zeros `_pcmLen` alongside `_playing = false`.

**M5 — LOW — `office_state.cpp:1384-1388` (`consumePendingSound`)**
Read-and-reset is atomic from the main loop perspective (single-threaded).

**M6 — LOW — `sound.cpp:67-68` (`begin`)**
`_ready` flag prevents re-initialization. Correct.

---

## 5. Resource & Concurrency Audit

**R1 — LOW — `sound.cpp:114` (`startClip`)**
`delay(10)` blocks main loop. Not a concurrency issue but a latency concern. Same as Q2.

**R2 — LOW — `sound.cpp:31`**
`stereoBuf` is a static 2KB buffer. Single-writer (main loop only). No concurrency concern.

**R3 — LOW — `sound.cpp:120` (`startClip`)**
`i2s_zero_dma_buffer()` on preemption correctly resets DMA state before new clip plays.

**R4 — LOW — `config.h:326-328`**
`SOUND_PCM_CHUNK_SAMPLES = 512` and `SOUND_I2S_PREFILL_CHUNKS = 4` define bounded iteration. No runaway loop risk.

**R5 — LOW — `sound.cpp:71-72` (`begin`)**
Amp GPIO configured as OUTPUT with correct initial state (disabled). No floating pin risk.

**R6 — LOW — `sound.cpp:74-75` (`begin`)**
`Wire.begin()` with explicit pins. On CYD-S3, I2C bus is shared with capacitive touch. `Wire.begin()` is safe to call if already initialized (Arduino Wire is idempotent).

**R7 — LOW — `sound.cpp:49-51` (`initI2S`)**
I2S driver install checks return code. DMA buffers are ESP-IDF managed, no manual free needed.

---

## 6. DX & Maintainability Audit

**[FIXED] D1 — MEDIUM — `sound.cpp:126-132` and `158-163`**
Duplicated stop-playback logic. Extract to `endClip()` helper.

**[FIXED] D2 — LOW — `sound.cpp:72` and `114` and `131` and `163`**
Amp polarity ternary `SOUND_AMP_ENABLE_ACTIVE_LOW ? X : Y` repeated 4 times. Consider `AMP_ON`/`AMP_OFF` constants.

**[FIXED] D3 — LOW — `office_state.h:91`**
`pendingSound` on `Pet` struct is semantically misplaced for a general-purpose office sound queue.

**[FIXED] D4 — LOW — `office_state.cpp:1102`**
`petPickTarget()` directly sets `_pet.pendingSound` instead of calling `queueSound()`.

**D5 — LOW — `sound.h:1-2`**
`#pragma once` + `<stddef.h>` + `<stdint.h>`. Clean header, no issues.

**[FIXED] D6 — LOW — `convert_sound.py:95`**
`str | None` type hint requires Python 3.10+. Project docs say Python 3.8+. Use `Optional[str]` for compatibility.

**D7 — LOW — `convert_sound.py:32-47`**
`slugify` prefix stripping is fragile — hard-coded source names. Acceptable for a project-internal tool.

**D8 — LOW — `CLAUDE.md`**
Common Modifications recipe for adding sounds is clear and complete.

**[FIXED] D9 — LOW — `main.cpp:10-12`**
Dead `#if defined(HAS_SOUND)` / `#include "sound.h"` guard — already included via `office_state.h`.

---

## 7. Testing Coverage Audit

**T1 — MEDIUM — `convert_sound.py`**
New Python tool with testable pure functions (`slugify()`, `generate_header()`) has no unit tests. These are trivially testable with pytest.

**T2 — LOW — `convert_sound.py:32-47`**
`slugify()` edge cases (empty result, leading digit) not caught without tests. Same as Q9.

**T3 — LOW — `sound.cpp:21-26`**
CLIPS[] order not verifiable beyond `static_assert`. Acceptable limitation.

**[FIXED] T4 — MEDIUM — `office_state.cpp:1384-1392`**
Single-slot pending sound silently drops on overwrite. Should document last-writer-wins semantics.

**T5 — LOW — `sound.cpp:168-172`**
No-op stubs adequately covered by build verification.

**[FIXED] T6 — MEDIUM — `testing-checklist.md`**
Missing checklist items for `convert_sound.py` batch mode and error paths.

**T7 — MEDIUM — cross-module**
Full sound dispatch chain only testable via non-deterministic dog behavior trigger.

**[FIXED] T8 — LOW — `convert_sound.py:85`**
Zero-length PCM produces potentially invalid C header. Should guard against it.
