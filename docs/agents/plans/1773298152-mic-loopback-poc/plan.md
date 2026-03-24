# Plan: Microphone Loopback Proof-of-Concept (CYD-S3)

## Objective

Enable the ES8311 codec's microphone input on the Freenove ESP32-S3 board, add record/playback capability, and wire it to a hamburger menu button. The flow is: tap "Mic Test" → record 2 seconds → auto-play back through speaker. This validates the full audio capture chain (mic → ES8311 ADC → I2S RX → PSRAM buffer → I2S TX → ES8311 DAC → speaker) before investing in the transport/STT layers.

**Scope:** CYD-S3 only (gated by new `HAS_MIC` define). CYD has no microphone hardware.

## Changes

### 1. `firmware/src/config.h` — New defines
- Add `HAS_MIC` auto-define (set when `BOARD_CYD_S3` is defined)
- Add mic constants: `SOUND_MIC_RECORD_MAX_MS` (2000ms), `SOUND_MIC_BUF_SAMPLES`, `SOUND_MIC_BUF_BYTES` (96KB)
- Increase `MENU_H` from 110 to 130 when `HAS_MIC` (adds 6th row: mic test)

### 2. `firmware/src/sound.h` — New public methods
- Add `MicTestPhase` enum: `IDLE`, `RECORDING`, `PLAYING`
- Add public methods: `startRecording()`, `stopRecording()`, `playRecording()`, `micTestPhase()`
- Add private members: `_recBuf`, `_recLen`, `_recStartMs`, `_micPhase`
- All gated by `#if defined(HAS_MIC)`

### 3. `firmware/src/sound.cpp` — I2S full-duplex + mic init + record/playback
- Change I2S mode from TX-only to TX+RX (full-duplex)
- Connect `data_in_num` to `SOUND_I2S_DINT` (GPIO 6)
- Add mic initialization: `es8311_microphone_config()` and `es8311_microphone_gain_set()`
- Add `startRecording()`: allocate PSRAM buffer, flush stale DMA, begin capture
- Add recording drain in `update()`: non-blocking I2S RX read, stereo→mono extraction, auto-stop
- Add `playRecording()`: reuse `startClip()` with PSRAM pointer
- Extend `endClip()`: free PSRAM buffer when playback of recording finishes

### 4. `firmware/src/office_state.cpp` — Menu hit-test
- Add return code 7 for mic test menu row in `hitTestMenuItem()`

### 5. `firmware/src/renderer.h` — Mic phase tracking
- Add `setMicTestPhase()` method and `_micPhase` member

### 6. `firmware/src/renderer.cpp` — Menu row + recording indicator
- Add "Mic Test" label as Row 5 in `drawMenuOverlay()`
- Add floating "REC"/"PLAY" indicator overlay in `drawScene()`

### 7. `firmware/src/main.cpp` — Wire menu item + state machine
- Add menu item 7 handler (starts recording, closes menu)
- Add mic test state machine (detects RECORDING→IDLE transition, auto-plays)
- Pass mic phase to renderer

## Dependencies

- ES8311 codec driver already vendored in `firmware/src/codec/es8311/`
- `es8311_microphone_config()` and `es8311_microphone_gain_set()` available in existing header
- PSRAM available on CYD-S3 (8MB OPI)

## Risks / Open Questions

1. **I2S full-duplex stability** — Adding RX to existing TX-only config. Fallback: use I2S_NUM_1 for RX.
2. **I2C bus sharing** — ES8311 mic config shares I2C with FT6336G touch. Both polled in main loop, no contention expected.
3. **DMA buffer pressure** — Adding RX DMA descriptors (~24KB internal SRAM). ESP32-S3 has ~512KB, should be fine.
