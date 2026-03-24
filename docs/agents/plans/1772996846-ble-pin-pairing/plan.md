# BLE PIN Pairing — Implementation Plan

## Objective

Enable multiple CYDs to coexist in the same room, each paired to a specific computer running the companion bridge. Inspired by MeshCore's approach: each CYD generates a random 4-digit PIN at boot, displays it on the splash screen, and embeds it in BLE advertising manufacturer data. The companion prompts the user for the PIN and connects only to the matching device.

This is an application-layer pairing mechanism — no changes to the binary protocol are needed. The PIN is used purely for device selection during BLE scanning/connection.

## Changes

### 1. `firmware/src/config.h`
- Add BLE PIN constants:
  - `BLE_PIN_MIN = 1000` — minimum PIN value (ensures 4 digits)
  - `BLE_PIN_MAX = 9999` — maximum PIN value
  - `BLE_MFG_COMPANY_ID = 0xFFFF` — BT SIG reserved company ID for testing
- Add splash PIN Y-position constant:
  - `SPLASH_PIN_Y = 218` (CYD only) — positioned between log area bottom (Y=212) and footer (Y=230)

### 2. `firmware/src/ble_service.h`
- Add `uint16_t _pin` member variable
- Add `uint16_t getPin() const` public getter so `main.cpp` can pass the PIN to the splash screen

### 3. `firmware/src/ble_service.cpp`
- In `begin()`, generate a random 4-digit PIN using `esp_random() % (BLE_PIN_MAX - BLE_PIN_MIN + 1) + BLE_PIN_MIN`
- Log PIN to serial: `[BLE] PIN: XXXX`
- Add manufacturer data to the advertising packet via `NimBLEAdvertisementData::setManufacturerData()`:
  - Format: `[company_id_low][company_id_high][pin_high][pin_low]` (4 bytes)
  - This adds 6 bytes (2 AD header + 4 data) to the advertising packet
  - New advertising packet size: 21 (existing) + 6 = 27 bytes — within 31-byte limit

### 4. `firmware/src/splash.h`
- Add `void setPinCode(uint16_t pin)` public method
- Add `uint16_t _pinCode = 0` member variable
- Add `void drawPinCode()` private method

### 5. `firmware/src/splash.cpp`
- Implement `setPinCode()`: stores PIN and calls `drawPinCode()`
- Implement `drawPinCode()`: draws `"PIN: XXXX"` centered in white text (font 1, size 2) at `SPLASH_PIN_Y` — only if `_pinCode != 0`
- Call `drawPinCode()` from `drawTo()` for screenshot capture support

### 6. `firmware/src/main.cpp`
- After successful BLE init (`bleService.begin()` returns true), call `splash.setPinCode(bleService.getPin())`
- PIN displays on splash screen immediately after BLE starts advertising

### 7. `companion/ble_transport.py`
- Update `_scan_async()` to collect manufacturer data from each discovered device
- Add `_extract_pin(device)` method: reads manufacturer data, checks company ID `0xFFFF`, extracts 2-byte PIN value
- Change `scan()` return type to list of `(address, name, pin)` tuples instead of a single address string
- Add `connect_by_pin(pin: int)` method: scans for NUS devices, finds the one with matching PIN, connects to it
- Keep existing `connect(address)` method for backward compatibility (direct address connection)

### 8. `companion/pixel_agents_bridge.py`
- Add `--ble-pin` CLI argument (optional int) for non-interactive use
- Update `_connect_ble()`:
  - If `--ble-pin` was provided, call `connect_by_pin(pin)` directly
  - If no PIN provided and in interactive mode (tty), scan for NUS devices, display list with PINs, prompt user to enter PIN
  - If no PIN provided and non-interactive, fall back to connecting to first NUS device found (existing behavior for single-CYD setups)
- Print discovered devices with their PINs during scan: `"Found: PixelAgents (PIN: 1234) at XX:XX:XX:XX:XX:XX"`

## Dependencies

1. `ble_service.cpp` changes must be done before `main.cpp` (needs `getPin()`)
2. `splash.h/.cpp` changes can be done in parallel with `ble_service` changes
3. `main.cpp` depends on both `ble_service` and `splash` changes
4. Companion changes (`ble_transport.py`, `pixel_agents_bridge.py`) are independent of firmware changes but should be tested together

## Advertising Packet Size Budget

```
Advertising packet (31 bytes max):
  Flags:             3 bytes (type=0x01, len=0x02, value=0x06)
  128-bit UUID:     18 bytes (type=0x07, len=0x11, 16-byte UUID)
  Manufacturer data: 6 bytes (type=0xFF, len=0x05, 2-byte company + 2-byte PIN)
  Total:            27 bytes ✓

Scan response (31 bytes max):
  Device name:      13 bytes (type=0x09, len=0x0C, "PixelAgents")
  Total:            13 bytes ✓
```

## Risks / Open Questions

1. **`esp_random()` availability at BLE init time** — `esp_random()` is used for PIN generation. It should be available after `NimBLEDevice::init()` since the radio subsystem is running. If not, fall back to `analogRead(0) ^ millis()` like the character spawn code does.

2. **Manufacturer data parsing in bleak** — bleak exposes manufacturer data via `device.details` or `device.metadata["manufacturer_data"]` as a dict keyed by company ID. Need to verify the exact API for the installed version (≥0.21.0). The company ID `0xFFFF` is the dict key, and the value is the 2-byte PIN payload.

3. **PIN collision** — Two CYDs could generate the same PIN at boot (probability: 1/9000 ≈ 0.01%). Acceptable for the target use case (2-3 devices). If collision occurs, user reboots one device.

4. **PIN persistence** — PIN regenerates on every boot. This is intentional — it prevents stale PINs and is consistent with MeshCore behavior. The companion must re-enter the PIN after a CYD reboot.

5. **Non-BLE boards** — LILYGO env doesn't define `HAS_BLE`, so PIN code never appears on its splash. The `setPinCode()` method must be guarded with `#if defined(HAS_BLE)` or handled gracefully (no-op if PIN is 0).
