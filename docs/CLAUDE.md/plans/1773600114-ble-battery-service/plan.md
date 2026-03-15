# Plan: BLE Battery Service (BAS)

## Objective

Expose battery level via standard BLE Battery Service (BAS, UUID `0x180F`) so macOS shows device battery natively and the companion app can display it without custom protocol messages.

## Changes

### 1. `firmware/src/ble_service.h`
- Add `NimBLECharacteristic* _battLevelChar` pointer (only when `HAS_BATTERY`)
- Add `void updateBatteryLevel(uint8_t percent)` public method (only when `HAS_BATTERY`)

### 2. `firmware/src/ble_service.cpp`
- Create BAS service (`0x180F`) alongside NUS
- Create Battery Level characteristic (`0x2A19`, READ + NOTIFY)
- `updateBatteryLevel()` sets value and notifies connected central

### 3. `firmware/src/main.cpp`
- Call `bleService.updateBatteryLevel(battery_getPercent())` after `battery_update()` in main loop

### 4. `macos/PixelAgents/.../BLETransport.swift`
- Add BAS UUID constants
- Discover BAS service alongside NUS
- Read + subscribe to Battery Level characteristic
- Publish `batteryLevel: UInt8?`

### 5. `macos/PixelAgents/.../BridgeService.swift`
- Expose `deviceBatteryLevel: UInt8?` from BLE transport

### 6. `macos/PixelAgents/.../ConnectionStatusView.swift`
- Show battery percentage next to connection status when available via BLE

### 7. `CLAUDE.md`
- Update BLE subsystem section with BAS

## Risks
- BAS 16-bit UUID must fit in advertising scan response alongside device name
- Battery level notifications should be rate-limited to avoid BLE congestion
