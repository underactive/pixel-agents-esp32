# Device Fingerprinting Plan

## Objective
Add protocol-level device identification so companions can verify they're talking to a Pixel Agents device, preventing accidental connection to unrelated ESP32 boards.

## Changes
- Add MSG_IDENTIFY_REQ (0x09) and MSG_IDENTIFY_RSP (0x0A) protocol messages
- Firmware responds with 8-byte payload: magic "PXAG" + protocol version + board type + firmware version
- Companion sends identify request after connecting, validates response with 2s timeout
- Proactive identify response on first heartbeat for backwards compatibility with old companions

## Dependencies
- Firmware config.h constants must be added first (all other files depend on them)
- Protocol changes must be complete before companion/macOS changes

## Risks / Open Questions
- BLE transport in Python bridge was send-only; needs NUS TX notification subscription for identify response
- No toolchain installed on dev machine; firmware build not verifiable locally
