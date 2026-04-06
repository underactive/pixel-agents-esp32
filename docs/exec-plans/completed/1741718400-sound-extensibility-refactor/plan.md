# Sound Feature — Extensibility Refactor

## Objective

Refactor the CYD-S3 sound system from per-sound methods (`playStartup()`, `playDogBark()`) to a table-driven architecture so adding a new sound is a one-line-per-file operation instead of touching 5+ files.

## Changes

1. **`tools/convert_sound.py`** — New MP3-to-C-header tool (ffmpeg, 24kHz mono s16le, `-n` override)
2. **`firmware/src/sound.h`** — `SoundId` enum + `play(SoundId)` API replacing per-sound methods
3. **`firmware/src/sound.cpp`** — `SoundClip` struct + `CLIPS[]` table, preemption, amp per-clip toggle
4. **`firmware/src/office_state.h`** — `pendingSound` replaces `barkPending`, `consumePendingSound()` + `queueSound()`
5. **`firmware/src/office_state.cpp`** — Update `petPickTarget()` and init/consume functions
6. **`firmware/src/main.cpp`** — Generic sound dispatch, `#if HAS_SOUND` guards on include/instance
7. **`firmware/src/sounds/*.h`** — Regenerate with `static const` via convert_sound.py
8. **`CLAUDE.md`** — File inventory, core files, common modifications recipe, subsystem docs
9. **`docs/references/testing-checklist.md`** — Sound test items

## Dependencies

- sound.h must be updated before office_state.h (includes SoundId)
- PCM headers must be regenerated before sound.cpp compiles

## Risks / Open Questions

- Amp polarity verified on hardware — no change needed
- `static const` on PCM arrays prevents linker symbol pollution in multi-TU scenarios
