# BLE PIN Pairing — Implementation Record

## Files Changed

- `firmware/src/config.h` — Added BLE PIN constants (`BLE_PIN_MIN`, `BLE_PIN_MAX`, `BLE_MFG_COMPANY_ID`) and `SPLASH_PIN_Y` layout constant
- `firmware/src/ble_service.h` — Added `_pin` member, `getPin()` getter
- `firmware/src/ble_service.cpp` — PIN generation via `esp_random()`, manufacturer data in advertising packet
- `firmware/src/splash.h` — Added `setPinCode()`, `_pinCode` member, `drawPinCode()` private method
- `firmware/src/splash.cpp` — Implemented PIN display (white, size 2, centered) and screenshot capture support
- `firmware/src/main.cpp` — Wired `bleService.getPin()` to `splash.setPinCode()` after BLE init
- `companion/ble_transport.py` — Added `scan_devices()` returning `(addr, name, pin)` tuples, `_extract_pin()` from manufacturer data, `connect_by_pin()` method, `return_adv=True` scanning
- `companion/pixel_agents_bridge.py` — Added `--ble-pin` CLI argument, interactive PIN prompt in `_connect_ble()`, single-device legacy fallback

## Summary

Implemented exactly as planned. The PIN pairing feature uses BLE manufacturer-specific data (company ID `0xFFFF`, 2-byte PIN payload) embedded in the advertising packet. The advertising packet size is 27 bytes (within 31-byte limit). The companion supports three connection modes:

1. `--ble-pin 1234` — non-interactive, connect directly to device with matching PIN
2. Interactive (no `--ble-pin`, tty attached) — scans, shows devices with PINs, prompts user
3. Non-interactive (no `--ble-pin`, no tty) — connects to first NUS device found (backward compat)

No deviations from plan.

## Verification

- CYD firmware builds successfully (`pio run -e cyd-2432s028r` — SUCCESS)
- RAM: 12.2%, Flash: 82.4%
- No new compiler warnings related to PIN changes

## Follow-ups

- Hardware test: verify PIN displays on splash screen at correct position
- Hardware test: verify companion reads PIN from manufacturer data
- Hardware test: verify two CYDs advertise different PINs and companion connects to correct one

## Audit Fixes

### Fixes Applied

1. **`std::atomic<bool>` for `_connected`** (Q2 / R1) — Changed `volatile bool _connected` in `ble_service.h` to `std::atomic<bool>` with acquire/release ordering for cross-core safety between NimBLE callbacks and main loop.

2. **Eliminated double BLE scan** (Q3 / I1) — Interactive PIN flow previously scanned devices, prompted for PIN, then `connect_by_pin()` scanned again. Fixed by reusing the first scan's results directly.

3. **`--ble-pin` range validation** (Q4 / I2) — Added `parser.error()` validation for values outside 1000-9999.

4. **BLE scan exception handling** (I8) — Added try/except wrapper around BLE scan in `_connect_ble()`.

5. **`_pinCode` reset in `Splash::begin()`** (S2) — Added `_pinCode = 0` to prevent stale PIN from previous boot cycle.

6. **`_last_count` initialized in `__init__`** (S3 / D6) — Added `self._last_count = -1` in `__init__`, removed `hasattr` check.

7. **Unified session-state reset** (S4 / S8) — Added `_reset_session_state()` method called from both `_connect_serial()` and `_connect_ble()`, resetting `last_states`, `last_usage_data`, and `_last_count`.

8. **Interactive PIN persisted for reconnect** (S5) — Saves entered PIN to `self.ble_pin` on successful connect so auto-reconnect doesn't re-prompt.

9. **PIN endianness comments** (D5) — Added byte-order comments in `ble_service.cpp` manufacturer data construction.

### Verification Checklist

- [ ] CYD firmware builds with `std::atomic<bool>` (`pio run -e cyd-2432s028r`)
- [ ] `--ble-pin 0` prints error and exits
- [ ] `--ble-pin 99999` prints error and exits
- [ ] BLE scan failure (no devices in range) does not crash companion
- [ ] Serial disconnect/reconnect resets agent tracking state (no stale characters)
- [ ] BLE disconnect/reconnect resets agent tracking state
- [ ] Interactive PIN entry followed by BLE disconnect reconnects without re-prompting
