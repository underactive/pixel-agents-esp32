# Sound Extensibility Refactor — Implementation

## Files Changed

| File | Action |
|------|--------|
| `tools/convert_sound.py` | Created — MP3 to C PCM header converter |
| `firmware/src/sound.h` | Modified — SoundId enum, play(SoundId) API |
| `firmware/src/sound.cpp` | Modified — CLIPS[] table, preemption, amp per-clip |
| `firmware/src/office_state.h` | Modified — pendingSound, consumePendingSound(), queueSound() |
| `firmware/src/office_state.cpp` | Modified — petPickTarget uses queueSound, init/consume updated |
| `firmware/src/main.cpp` | Modified — generic sound dispatch, #if HAS_SOUND guards |
| `firmware/src/sounds/startup_sound_pcm.h` | Regenerated — static const |
| `firmware/src/sounds/dog_bark_pcm.h` | Regenerated — static const |
| `CLAUDE.md` | Modified — file inventory, core files, common modifications, subsystem docs |
| `docs/references/testing-checklist.md` | Modified — sound test items |

## Summary

Replaced per-sound methods with table-driven `SoundId` enum + `CLIPS[]` lookup:

- **sound.h**: `SoundId` enum (`STARTUP`, `DOG_BARK`, `COUNT`), `play(SoundId)` replaces `playStartup()`/`playDogBark()`
- **sound.cpp**: `SoundClip` struct with `CLIPS[]` array, `static_assert` on table size. Preemption enabled (removed `if (_playing) return` guard). Amp enabled in `startClip()`, disabled when playback ends in `update()`. Amp starts disabled in `begin()`.
- **office_state**: `Pet::barkPending` → `Pet::pendingSound` (`SoundId::COUNT` = none). `consumePendingSound()` returns `SoundId` + resets. `queueSound()` sets pending. `petPickTarget()` calls `queueSound(SoundId::DOG_BARK)`.
- **main.cpp**: `#if defined(HAS_SOUND)` guards on `#include "sound.h"` and `SoundPlayer sound`. Generic dispatch: `consumePendingSound()` → `sound.play(pending)`.
- **PCM headers**: Regenerated via `tools/convert_sound.py` with `static const` storage class.
- **convert_sound.py**: New tool. Supports batch mode and `-n name` override for custom slugs.

## Verification

- All three environments build successfully:
  - `cyd-2432s028r`: SUCCESS (no HAS_SOUND — stubs compile)
  - `freenove-s3-28c`: SUCCESS (HAS_SOUND — full sound system)
  - `lilygo-t-display-s3`: SUCCESS (no HAS_SOUND — stubs compile)
- `python3 tools/convert_sound.py` generates correct headers with matching symbol names and byte counts
- No stale references to `playStartup`, `playDogBark`, `consumeDogBark`, or `barkPending` in firmware sources

## Follow-ups

- Hardware test: verify startup sound and dog bark on CYD-S3 hardware
- Hardware test: verify preemption (trigger bark during startup playback)

## Audit Fixes

### Fixes applied

1. **Q3/D1**: Extracted duplicated stop-playback logic in `sound.cpp` `update()` to `endClip()` private helper method
2. **D2**: Added `AMP_ON`/`AMP_OFF` `constexpr` constants in `sound.cpp` to replace 4 repeated `SOUND_AMP_ENABLE_ACTIVE_LOW ? X : Y` ternaries
3. **Q6/S3**: Added `_pcmLen = len & ~1u` in `startClip()` to truncate odd-length PCM data, preventing potential one-byte overread
4. **D4/Q7/S4**: Changed `petPickTarget()` to call `queueSound(SoundId::DOG_BARK)` instead of directly writing `_pet.pendingSound`
5. **Q5**: Added `_pet.pendingSound = SoundId::COUNT` in `setDogEnabled(false)` path to clear any queued bark when dog is disabled
6. **D9/Q11**: Removed dead `#if defined(HAS_SOUND)` / `#include "sound.h"` guard in `main.cpp` (already included transitively via `office_state.h`)
7. **D6**: Changed `str | None` type hint to `Optional[str]` in `convert_sound.py` for Python 3.8+ compatibility
8. **Q9/T2**: Added empty-slug guard in `convert_file()` — exits with error message suggesting `-n` override
9. **T8**: Added zero-length PCM guard in `convert_file()` — exits with error on ffmpeg producing empty output
10. **T4**: Added inline comment on `queueSound()` declaration documenting single-slot last-writer-wins semantics
11. **T6**: Added 4 testing checklist items for `convert_sound.py` batch mode, `-n` override, no-args usage, and amp silence

### Verification checklist

- [ ] All three PlatformIO environments build (cyd-2432s028r, freenove-s3-28c, lilygo-t-display-s3) — VERIFIED
- [ ] No remaining `SOUND_AMP_ENABLE_ACTIVE_LOW ?` ternaries outside AMP_ON/AMP_OFF definitions
- [ ] `petPickTarget()` uses `queueSound()` instead of direct field write
- [ ] `setDogEnabled(false)` clears pending sound
- [ ] `convert_sound.py` rejects empty slug with helpful error
- [ ] `convert_sound.py` rejects zero-length ffmpeg output

### Unresolved items

- **Q1** (MEDIUM): `_pet.pendingSound` not initialized in `OfficeState::init()`. Deferred — `initPet()` is always called via `spawnAllCharacters()` before the main loop, and no code path calls `consumePendingSound()` between `init()` and `spawnAllCharacters()`. Adding init there would be redundant with `initPet()` and mask if the real init path ever broke.
- **Q2/R1** (MEDIUM): `delay(10)` in `startClip()` blocks main loop. Deferred — amp settle time is hardware-required, and sounds are rare events (~2 per session). A state-machine approach would add complexity for negligible benefit.
- **Q4** (MEDIUM): Partial I2S write accounting mismatch. Deferred — ESP-IDF always writes in DMA-buffer-sized units; fractional stereo frames cannot occur in practice.
- **Q8/M1/I3/D3** (LOW-MEDIUM): `pendingSound` on Pet struct is semantically misplaced. Deferred — currently the only sound source is the dog FSM. Moving the field to OfficeState adds no value until a second sound source exists.
- **Q10** (LOW): `NamedTemporaryFile` POSIX semantics. Deferred — tool targets macOS/Linux only.
- **T1** (MEDIUM): No unit tests for `convert_sound.py`. Deferred — tool is stable and simple; runtime guard improvements (Q9, T8) reduce the risk of the primary failure modes.
- **T7** (MEDIUM): Sound dispatch chain only testable via non-deterministic dog FSM. Deferred — adding a debug serial command is out of scope for this refactor.
