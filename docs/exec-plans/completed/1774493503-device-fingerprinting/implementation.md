# Device Fingerprinting Implementation

## Files Changed
- `firmware/src/config.h` — Added MSG_IDENTIFY_REQ/RSP constants, IDENTIFY_MAGIC, IDENTIFY_PROTOCOL_VERSION, board type constants, FIRMWARE_VERSION_ENCODED
- `firmware/src/protocol.h` — Added IdentifyReqCb callback type, _onIdentifyReq member, extended begin() signature
- `firmware/src/protocol.cpp` — Added MSG_IDENTIFY_REQ to payloadLength() and dispatch()
- `firmware/src/main.cpp` — Added sendIdentifyResponse(), onSerialIdentifyReq/onBleIdentifyReq callbacks, proactive identify on first heartbeat, wired callbacks in begin() calls
- `companion/pixel_agents_bridge.py` — Added identify constants, build_identify_req(), parse_identify_response(), _try_identify() method, identify handshake in _connect_serial() and _connect_ble()
- `companion/ble_transport.py` — Added NUS TX notification subscription (_on_notify), rx buffer with threading lock, read() method
- `macos/PixelAgents/PixelAgents/Model/ProtocolBuilder.swift` — Added IdentifyResponse struct, msgIdentifyReq/Rsp constants, identifyRequest() builder, parseIdentifyResponse() parser
- `macos/PixelAgents/PixelAgents/Transport/SerialTransport.swift` — Extended extractProtocolFrames() to match MSG_IDENTIFY_RSP, added onIdentifyResponse callback
- `macos/PixelAgents/PixelAgents/Transport/BLETransport.swift` — Added onIdentifyResponse callback, extended NUS TX handler to parse identify responses
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — Wired onIdentifyResponse callbacks, send identify request on serial/BLE connect, handleIdentifyResponse() logging
- `macos/PixelAgentsTests/ProtocolBuilderTests.swift` — Added tests for identifyRequest(), parseIdentifyResponse() (valid, bad magic, too short)
- `docs/references/subsystems.md` — Added IDENTIFY_REQ/RSP to protocol message table, updated BLE TX description
- `docs/references/testing-checklist.md` — Added Device Fingerprinting test section
- `ARCHITECTURE.md` — Updated message type count from 8 to 10

## Summary
Implemented as planned. The identify handshake uses a request/response pattern with a 2-second timeout for backwards compatibility. BLE advertising format was intentionally left unchanged to avoid breaking old companions. The BLE transport in the Python bridge gained NUS TX notification support (previously send-only) to receive identify responses over BLE.

## Verification
- ESP32 toolchain not installed on dev machine; firmware builds could not be verified locally
- Python companion changes are syntactically correct (no imports or runtime dependencies added beyond existing pyserial/bleak)
- macOS test cases added for ProtocolBuilder (identifyRequest framing, parseIdentifyResponse valid/invalid)
- All changes follow existing patterns (sendSettingsState → sendIdentifyResponse, extractProtocolFrames extension)

## Audit Fixes

1. **SM-1/RC-3**: Wrapped `handleIdentifyResponse` in `Task { @MainActor in }` for thread safety (BridgeService.swift)
2. **SM-4**: Reordered BLE `_rx_buf.clear()` before `start_notify` to prevent race (ble_transport.py)
3. **DX-1**: Updated protocol recipe from "after 0x05" to "after 0x0A" (PROJECT.md)
4. **DX-5**: Expanded WHY comment on proactive identify in heartbeat callbacks (main.cpp)
5. **QA-7**: Added `FIRMWARE_VERSION_ENCODED` to version bump recipe (PROJECT.md)

### Verification checklist
- [ ] macOS: `handleIdentifyResponse` no longer triggers MainActor isolation warning
- [ ] BLE: reconnect does not surface stale identify response from previous session
- [ ] Protocol recipe in CLAUDE.md shows correct next message type value (0x0B)
- [ ] Version bump recipe mentions all 6 locations including FIRMWARE_VERSION_ENCODED

### Unresolved (deferred)
- TC-1: No Python test infrastructure — accepted, out of scope
- TC-2: No tests for `extractProtocolFrames` — accepted, pre-existing gap
- DX-2: Protocol::begin() 8 positional params — deferred to next protocol message addition
- DX-10: Duplicated frame parsing across transports — matches existing pattern

## Follow-ups
- Verify firmware builds for all 3 targets when toolchain is available
- Run macOS unit tests via xcodebuild
- Hardware testing with actual devices (serial + BLE, all board variants)
- Consider adding device info to macOS UI (board type, firmware version display)
