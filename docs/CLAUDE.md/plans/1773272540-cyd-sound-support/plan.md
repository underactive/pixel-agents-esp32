# Plan: Add Sound Support to CYD Board

## Objective

Enable sound playback on the primary CYD board (ESP32-2432S028R) using its onboard SC8002B mono amplifier connected to GPIO 26 (ESP32's built-in 8-bit DAC). The CYD-S3 uses an external ES8311 codec; the CYD uses the ESP32's I2S internal DAC mode instead. Same 5 sound events, same `SoundPlayer` API.

## Changes

1. **`firmware/src/config.h`** — Add `BOARD_CYD` audio constants block (`HAS_SOUND`, `SOUND_DAC_INTERNAL`, `SOUND_HAS_AMP_ENABLE=0`, DAC GPIO, volume shift, smaller DMA buffers). Restructure existing CYD-S3 block under unified `#if defined(BOARD_CYD) / #elif defined(BOARD_CYD_S3)`.

2. **`firmware/src/sound.cpp`** — Conditional compilation:
   - Guard `Wire.h` and `es8311.h` includes with `#if !defined(SOUND_DAC_INTERNAL)`
   - Guard amp GPIO helpers with `#if SOUND_HAS_AMP_ENABLE`
   - Guard `es8311_handle_t` with `#if !defined(SOUND_DAC_INTERNAL)`
   - Two `initI2S()` paths: internal DAC mode vs external codec
   - Guard `begin()` codec init and amp pin setup
   - Guard `startClip()`/`endClip()` amp GPIO
   - Add signed-to-unsigned sample conversion for internal DAC in `update()`

3. **`firmware/platformio.ini`** — Add `board_build.partitions = huge_app.csv` to CYD env (3MB app, no OTA).

4. **Documentation** — Update CLAUDE.md (hardware, pins, subsystem, build config, env vars, known issues), CHANGELOG.md, version-history.md, testing-checklist.md.

## Dependencies

- Config constants must be defined before sound.cpp compiles (header include order — already satisfied).
- Partition change must be in platformio.ini before build verification.

## Risks / Open Questions

- Flash usage: PCM data adds ~451KB. With `huge_app.csv` (3MB), CYD firmware fits at ~1.6MB (51%).
- 8-bit DAC audio quality is lower than 16-bit ES8311. `SOUND_VOLUME_SHIFT=2` provides software attenuation.
- SC8002B amp is always-on (no enable pin) — may produce slight hiss when idle.
- GPIO 26 verified unused by display, touch, LED, or BLE subsystems.
