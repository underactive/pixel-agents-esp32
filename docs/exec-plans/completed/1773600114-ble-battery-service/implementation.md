# Implementation: BLE Battery Service (BAS)

## Files Changed

- `firmware/src/ble_service.h` — Added `updateBatteryLevel(uint8_t)` method and `_battLevelChar` pointer (guarded by `HAS_BATTERY`)
- `firmware/src/ble_service.cpp` — Created BAS service (`0x180F`) with Battery Level characteristic (`0x2A19`, READ + NOTIFY). Added `updateBatteryLevel()` implementation with change-detection dedup.
- `firmware/src/main.cpp` — Wired `bleService.updateBatteryLevel(battery_getPercent())` in main loop after `battery_update()` (guarded by `HAS_BATTERY && HAS_BLE`)
- `macos/PixelAgents/.../BLETransport.swift` — Added BAS UUID constants, discovers BAS service alongside NUS, reads + subscribes to battery characteristic, publishes `batteryLevel: UInt8?`, clears on disconnect
- `macos/PixelAgents/.../ConnectionStatusView.swift` — Shows battery percentage with SF Symbols battery icon and color-coded text (green >50%, yellow >20%, red <=20%) when BLE battery level is available
- `macos/PixelAgents/.../MenuBarView.swift` — Passes `bridge.deviceBatteryLevel` to `ConnectionStatusView`, added `deviceBatteryLevel` computed property on `BridgeService`
- `CLAUDE.md` — Updated BLE Transport subsystem section with BAS documentation

## Summary

Implemented standard BLE Battery Service (BAS) on the firmware side and CoreBluetooth battery level reading on the macOS companion. This uses the standard Bluetooth GATT profile, so macOS also shows the device battery level natively in System Settings → Bluetooth without any custom protocol messages.

No Python companion changes needed — battery over BLE is OS-level.

## Verification

- All 3 PlatformIO environments build successfully
- macOS companion builds successfully (xcodebuild Release)
- All macOS unit tests pass (StateDeriver, CodexStateDeriver, ProtocolBuilder, AgentTracker)
- BAS only compiled on boards with `HAS_BATTERY && HAS_BLE` (CYD-S3 only currently — LILYGO has battery but no BLE)
- CYD (no battery, has BLE): BAS code excluded at compile time
- Battery level notifications are deduped (only sent on change)

## Follow-ups

- Hardware testing: verify macOS shows battery level in Bluetooth settings when CYD-S3 connected via BLE
- LILYGO has `HAS_BATTERY` but no `HAS_BLE`, so it cannot expose battery via BAS — only via local display
