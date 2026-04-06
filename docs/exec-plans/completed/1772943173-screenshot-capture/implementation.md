# Implementation: Screenshot Capture

## Files Changed

- `firmware/src/config.h` — Added `MSG_SCREENSHOT_REQ`, `SCREENSHOT_SYNC1`, `SCREENSHOT_SYNC2` constants
- `firmware/src/protocol.h` — Added `ScreenshotReqCb` type, `_onScreenshotReq` member, extended `begin()` signature
- `firmware/src/protocol.cpp` — Added `payloadLength()` case, `dispatch()` handler, stored callback in `begin()`
- `firmware/src/renderer.h` — Added `requestScreenshot()`, `isScreenshotPending()`, `sendScreenshot()` public methods; `_frameBuffer`, `_screenshotRequested` private members
- `firmware/src/renderer.cpp` — Saved `createSprite()` buffer pointer; implemented RLE screenshot send with 256-byte streaming buffer; graceful empty response when no framebuffer
- `firmware/src/main.cpp` — Added `onScreenshotReq()` callback, passed to `protocol.begin()`, added post-render `isScreenshotPending()` check
- `companion/pixel_agents_bridge.py` — Added screenshot constants, `build_screenshot_req()`, `rgb565_to_rgb888()`, `save_bmp()`, `handle_screenshot()`, `receive_screenshot()`, `_read_exact()`; replaced `time.sleep()` with `select()` + `setcbreak()` for keyboard input; optional PIL PNG support

## Summary

Implemented exactly as planned. The ESP32 receives a `MSG_SCREENSHOT_REQ` (0x06) with no payload, sets a flag, and after the next render frame sends the full framebuffer as RLE-compressed RGB565 data over serial with distinct sync bytes (0xBB 0x66). The companion decodes the RLE stream, converts RGB565 to RGB888, and saves as BMP (or PNG if PIL is installed). CYD boards without a full framebuffer receive a graceful "not available" response (zero width/height header).

Keyboard input uses `select()` on stdin with cbreak mode (only when stdin is a TTY), falling back to `time.sleep()` otherwise.

## Verification

- LILYGO build: SUCCESS (pio run -e lilygo-t-display-s3)
- CYD build: SUCCESS (pio run -e cyd-2432s028r)
- Protocol constants match between firmware and companion
- Screenshot message has 0-byte payload, correctly handled by protocol state machine (goes directly to checksum)

## Follow-ups

- Hardware verification of byte order (RGB565 in framebuffer vs post-setSwapBytes)
- End-to-end test with actual hardware (request screenshot, verify BMP output)

## Audit Fixes

### Fixes Applied

1. **R5 — Buffer overflow in post-loop RLE flush** (`firmware/src/renderer.cpp`): Added `if (bufPos > 248)` flush check before appending the final run + end marker (8 bytes) to the 256-byte stack buffer.
2. **S2/S3 — Unbounded width/height from serial** (`companion/pixel_agents_bridge.py`): Added `MAX_DIM = 1024` upper bound check on width and height values received from serial.
3. **IC-6 — total_pixels consistency check** (`companion/pixel_agents_bridge.py`): Added validation that `total_pixels == width * height` after dimension checks.
4. **T3a — Uncaught SerialException** (`companion/pixel_agents_bridge.py`): Wrapped `_receive_screenshot_inner()` in try/except for `serial.SerialException`, printing error instead of crashing.

### Verification Checklist

- [x] LILYGO firmware builds successfully after R5 fix
- [x] CYD firmware builds successfully after R5 fix
- [ ] Hardware test: screenshot with bufPos near 252 at loop exit produces correct output (R5)
- [ ] Companion rejects dimensions >1024 with error message (S2/S3)
- [ ] Companion rejects mismatched total_pixels with error message (IC-6)
- [ ] Companion prints serial error and continues running when cable disconnected during screenshot (T3a)

### Deferred Findings

- **S5/R2/IC-5** (main loop blocking): Accepted — by design for infrequent manual use, within ESP32 watchdog timeout.
- **IC-9/SM-3** (heartbeat pause during receive): Accepted — ESP32 is also blocked, watchdog self-recovers after completion.
- **DM3/SM-2** (getter naming): Accepted — consume-on-read is idiomatic for embedded single-consumer flags.
