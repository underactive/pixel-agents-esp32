# Implementation: Add Sound Support to CYD Board

## Files Changed

- `firmware/src/config.h` — Added `BOARD_CYD` audio constants block with `HAS_SOUND`, `SOUND_DAC_INTERNAL`, `SOUND_HAS_AMP_ENABLE=0`, DAC GPIO pin, volume shift, smaller DMA/chunk sizes. Restructured audio section from CYD-S3-only to `#if defined(BOARD_CYD) / #elif defined(BOARD_CYD_S3)`.
- `firmware/src/sound.cpp` — Added conditional compilation for two I2S backends. CYD path uses `I2S_MODE_DAC_BUILT_IN` + `i2s_set_dac_mode()`, no pin config, no codec init, no amp GPIO. Sample conversion adds signed-to-unsigned offset for internal DAC. All ES8311/Wire/amp code guarded behind `!SOUND_DAC_INTERNAL` / `SOUND_HAS_AMP_ENABLE`.
- `firmware/platformio.ini` — Added `board_build.partitions = huge_app.csv` to CYD env for 3MB app partition.
- `CLAUDE.md` — Updated hardware (SC8002B in components table, CYD microcontroller description), CYD pin assignments (GPIO 26 audio DAC), audio subsystem section (both boards), build config (huge_app.csv, env vars for SOUND_DAC_INTERNAL/SOUND_HAS_AMP_ENABLE), known issues (8-bit DAC quality, no-OTA partition).
- `CHANGELOG.md` — Added CYD sound support and partition change entries under 0.9.0.
- `docs/CLAUDE.md/version-history.md` — Updated 0.9.0 row to include CYD sound support.
- `docs/CLAUDE.md/testing-checklist.md` — Added 7 CYD-specific sound test items, updated section title from "CYD-S3 Only" to "CYD and CYD-S3".

## Summary

Implemented exactly as planned. The ESP32's internal DAC mode (`I2S_MODE_DAC_BUILT_IN`) on GPIO 26 feeds the SC8002B amplifier. The same `SoundPlayer` API and all 5 sound events work on both boards. Key differences from CYD-S3: no codec init, no amp enable GPIO, signed-to-unsigned PCM conversion, smaller DMA buffers for RAM conservation.

## Verification

1. `pio run -e cyd-2432s028r` — SUCCESS (1,613KB / 3,145KB = 51.3% of huge_app partition)
2. `pio run -e freenove-s3-28c` — SUCCESS (1,584KB / 6,553KB = 24.2%, no regression)
3. `pio run -e lilygo-t-display-s3` — SUCCESS (842KB / 6,553KB = 12.8%, no HAS_SOUND)

## Follow-ups

- Hardware test: verify all 5 sounds play through CYD speaker with acceptable quality
- Tune `SOUND_VOLUME_SHIFT` if audio is too quiet/loud on CYD hardware
- Check for audible hiss/pop from always-on SC8002B amp when no sound is playing

## Audit Fixes

### Fixes Applied

1. **Fixed unchecked `i2s_set_dac_mode()` return value** (Testing Coverage Audit T1) — Added error check in `initI2S()` CYD path: if `i2s_set_dac_mode(I2S_DAC_CHANNEL_LEFT_EN)` fails, the I2S driver is uninstalled and `initI2S()` returns false. Previously the return value was ignored, which could leave the I2S driver installed with an improperly configured DAC.

### Verification

- [x] CYD build succeeds with error check in `initI2S()` (`pio run -e cyd-2432s028r`)

### Unresolved Items

All other audit findings were either pre-existing in the CYD-S3 code path (S1, S2, S3, R1, R4), by design (R2), false positives due to single-threaded execution model (R3), or low-severity cosmetic/documentation suggestions (S4, T2, T3, R5, D1, D2). None require action for this change.
