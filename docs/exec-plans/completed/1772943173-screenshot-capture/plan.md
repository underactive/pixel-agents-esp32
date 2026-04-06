# Plan: Screenshot Capture

## Objective

Add screenshot capture capability: the companion sends a request, the ESP32 captures its framebuffer, RLE-compresses it, and sends it back over serial. The companion saves it as a BMP (or PNG if PIL available).

Scoped to LILYGO (full-frame buffer) only. CYD half-buffer/direct modes return a graceful error.

## Changes

### Firmware

- **`firmware/src/config.h`** — Add `MSG_SCREENSHOT_REQ = 0x06`, `SCREENSHOT_SYNC1 = 0xBB`, `SCREENSHOT_SYNC2 = 0x66`
- **`firmware/src/protocol.h`** — Add `ScreenshotReqCb` callback type, extend `begin()` signature
- **`firmware/src/protocol.cpp`** — Add `payloadLength()` case (0 bytes), `dispatch()` handler, store callback in `begin()`
- **`firmware/src/renderer.h`** — Add `requestScreenshot()`, `isScreenshotPending()`, `sendScreenshot()` public methods; `_frameBuffer` and `_screenshotRequested` private members
- **`firmware/src/renderer.cpp`** — Save `createSprite()` buffer pointer; implement RLE-encoded screenshot send over Serial
- **`firmware/src/main.cpp`** — Add `onScreenshotReq()` callback, pass to `protocol.begin()`, check `isScreenshotPending()` after render

### Companion

- **`companion/pixel_agents_bridge.py`** — Add screenshot request/receive/save; keyboard input via `select()` + `setcbreak()` for 's' key; BMP writer; optional PIL PNG output

## Dependencies

Implementation order: config.h → protocol.h/.cpp → renderer.h/.cpp → main.cpp → companion

## Risks / Open Questions

1. Byte order in sprite buffer — `setSwapBytes(true)` applies during `pushSprite()` only, so `_frameBuffer[i]` should be correct RGB565. Needs hardware verification.
2. Serial TX blocks when buffer full (256 bytes) — provides natural flow control. Screenshot takes ~1-3s.
3. Incoming messages queue during screenshot send — heartbeats fit in 256-byte RX buffer.
4. Terminal restore on crash — `atexit` handler covers normal exits; `stty sane` for crashes.
