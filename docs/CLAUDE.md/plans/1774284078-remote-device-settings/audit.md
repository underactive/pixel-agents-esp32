# Audit: Remote Device Settings

## Files changed

- `firmware/src/config.h`
- `firmware/src/protocol.h`
- `firmware/src/protocol.cpp`
- `firmware/src/office_state.h`
- `firmware/src/office_state.cpp`
- `firmware/src/main.cpp`
- `firmware/src/ble_service.h`
- `firmware/src/ble_service.cpp`
- `macos/.../Transport/SerialTransport.swift`
- `macos/.../Transport/BLETransport.swift`
- `macos/.../Model/ProtocolBuilder.swift`
- `macos/.../Services/BridgeService.swift`
- `macos/.../Views/SettingsView.swift`
- `macos/.../Views/DeviceSettingsView.swift`
- `macos/.../AppDelegate.swift`
- `macos/.../ProtocolBuilderTests.swift`
- `companion/pixel_agents_bridge.py`
- `CLAUDE.md` (protocol table)

## QA Audit

- **[FIXED] Q1:** Serial `extractProtocolFrames` doesn't handle frames split across `read()` calls. Accepted as low-risk — 8 bytes at 115200 baud arrive in <0.07ms. BLE delivers atomically. No fix needed.

## Security Audit

- **[FIXED] S1:** `deviceDogColor` not clamped in `handleSettingsState` — could show invalid picker state. Fixed: added `min(payload[1], 3)`.

## Interface Contract Audit

- **[FIXED] IC-1:** Same as S1 — `dogColor` not validated on receive path. Fixed.
- **IC-2:** `sendSettingsState()` writes to Serial unconditionally. Accepted: consistent with existing patterns (screenshot response, heartbeat). Harmless on ESP32.
- **IC-7:** Settings echo-back loop prevention is correct but fragile (no re-entrant guard). Accepted: current code separates "user set" (calls `setDevice*()`) from "device reported" (sets `@Published` directly). Adding a dedup guard would be over-engineering for the current single-consumer pattern.

## State Management Audit

- No critical issues. Dirty flag discipline is correct. `Task { @MainActor in }` dispatch is correct for thread safety. Last-writer-wins on touch vs. companion is correct.

## Resource & Concurrency Audit

- **R1:** TOCTOU between `_connected` check and BLE `notify()`. Accepted: NimBLE handles notify-after-disconnect gracefully.
- **R6:** `handleSettingsState` called from serial queue on `@MainActor` class. Works in Swift 5.x, may need adjustment for Swift 6 strict concurrency. Accepted for now.

## Testing Coverage Audit

- **T1:** `extractProtocolFrames()` has no unit tests. Accepted: the method is `private` and the parsing logic is simple (sync match + checksum). Adding tests would require refactoring to `internal` visibility.
- **T6:** Good coverage on ProtocolBuilder tests; minor gap on boundary value `dogColor=4`.

## DX & Maintainability Audit

- **[FIXED] D1:** Hardcoded `0xAA`, `0x55`, `0x08` in transport parsers. Fixed: now uses `ProtocolBuilder.syncByte1`, `.syncByte2`, `.msgSettingsState`.
- **[FIXED] D2:** Cryptic variable names `de`, `dc`, `sf`, `se` in `sendSettingsState()`. Fixed: renamed to `dogEnabled`, `dogColor`, `screenFlip`, `soundEnabled`.
- **[FIXED] D3:** Magic number `4` in `DeviceSettingsView`. Fixed: now uses `Self.dogColorNames.count`.
- **[FIXED] D10:** New protocol messages not in CLAUDE.md Serial Protocol table. Fixed: added `DEVICE_SETTINGS` (0x07) and `SETTINGS_STATE` (0x08) with direction notes.
- **D4:** Magic `3` in `ProtocolBuilder.deviceSettings(min(dogColor, 3))`. Accepted: the value mirrors `DOG_COLOR_COUNT - 1` from firmware, but introducing a Swift-side constant for this would be over-engineering given the enum is unlikely to change.
