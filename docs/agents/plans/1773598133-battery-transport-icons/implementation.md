# Implementation: Battery Monitor + Transport Icons

## Files Changed

- `firmware/src/config.h` — Added `HAS_BATTERY`, `BATTERY_ADC_PIN`, battery constants (`BATTERY_VOLTAGE_DIVIDER`, `BATTERY_READ_INTERVAL_MS`, `BATTERY_SMOOTH_ALPHA`, `BATTERY_FULL_MV`, `BATTERY_EMPTY_MV`, `BATTERY_CHARGING_MV`, `BATTERY_WARN_PCT`, `BATTERY_CRIT_PCT`), transport icon constants (`TRANSPORT_ICON_W/H`), new colors (`COLOR_BLE`, `COLOR_CHARGING`, `COLOR_DIM`)
- `firmware/src/battery.h` — **Created.** Free-function API: `battery_begin()`, `battery_update()`, `battery_getPercent()`, `battery_isCharging()`, `battery_setUsbConnected()`
- `firmware/src/battery.cpp` — **Created.** ADC reading with EMA smoothing, LiPo discharge curve lookup table (15 breakpoints), charging heuristic (USB + voltage > 4.1V)
- `firmware/src/office_state.h` — Split `_connected`/`_lastHeartbeatMs` into per-transport (`_serialConnected`/`_bleConnected`, `_lastSerialHeartbeatMs`/`_lastBleHeartbeatMs`). Removed `setConnected()`, `onHeartbeat()`. Added `onSerialHeartbeat()`, `onBleHeartbeat()`, `isSerialConnected()`, `isBleConnected()`. Changed `checkHeartbeat()` return to void.
- `firmware/src/office_state.cpp` — Per-transport heartbeat implementation with independent timeouts. Bubble clearing only on transition from any-connected to fully-disconnected.
- `firmware/src/main.cpp` — Split `onHeartbeat` callback into `onSerialHeartbeat`/`onBleHeartbeat`. Wired `battery_begin()` in setup, `battery_update()` and `battery_setUsbConnected()` in main loop.
- `firmware/src/renderer.h` — Added `gfxDrawMonoBitmap()` private helper for monochrome bitmap rendering.
- `firmware/src/renderer.cpp` — Added USB/BT/bolt icon bitmaps (5x8 PROGMEM). Redesigned `drawStatusBar()`: left side has transport icons (USB always, BT if `HAS_BLE`), right side has battery indicator (if `HAS_BATTERY`), center has status text. Updated all status modes to use `textLeft`/`rightBound` for text positioning.
- `CLAUDE.md` — Added battery module to Core Files, File Inventory. Added Battery Monitor as Key Subsystem #13. Added `HAS_BATTERY`/`BATTERY_ADC_PIN` to Environment Variables. Updated Status Bar subsystem and Serial Protocol descriptions.

## Summary

Implemented as planned with minor deviations:
- `checkHeartbeat()` changed from `bool` to `void` return (unused return value flagged by IC audit)
- Battery color thresholds extracted to named constants (`BATTERY_WARN_PCT`, `BATTERY_CRIT_PCT`) per DX audit
- Used per-pin ADC attenuation (`analogSetPinAttenuation`) instead of global per Resource audit

## Verification

- All 3 PlatformIO environments build successfully: `cyd-2432s028r`, `freenove-s3-28c`, `lilygo-t-display-s3`
- CYD: No `HAS_BATTERY` → battery code excluded. Has `HAS_BLE` → USB+BT icons. Verified no compile errors.
- CYD-S3: `HAS_BATTERY` on GPIO 9, `HAS_BLE` → USB+BT icons + battery indicator
- LILYGO: `HAS_BATTERY` on GPIO 4, no `HAS_BLE` → USB icon only + battery indicator
- `isConnected()` backward compatibility verified: 3 callers (led_ambient.cpp, renderer.cpp OVERVIEW mode) work unchanged

## Follow-ups

- Hardware testing needed: verify ADC readings on GPIO 9 (CYD-S3) and GPIO 4 (LILYGO) with actual LiPo batteries
- If boards have different voltage divider ratios, `BATTERY_VOLTAGE_DIVIDER` should be moved to per-board `#if` blocks

## Audit Fixes

1. **[SM-1/RC2/IC-1/Q2]** Removed redundant `battery_setUsbConnected(true)` from `onSerialHeartbeat` callback. Main loop sync at line 234 is the single authoritative write site.
2. **[RC3]** Changed `analogSetAttenuation(ADC_11db)` to `analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db)` in battery.cpp for per-pin isolation.
3. **[S1]** Added `if (hiMv == loMv) return hiPct;` guard before division in `voltageToPercent()` to prevent future div-by-zero if curve data is edited.
4. **[R2]** Added `BATTERY_WARN_PCT` (50) and `BATTERY_CRIT_PCT` (20) constants in config.h. Updated renderer.cpp to use them.
5. **[D1]** Changed first/last entries of `DISCHARGE_CURVE[]` to use `BATTERY_FULL_MV`/`BATTERY_EMPTY_MV` constants instead of hardcoded values.
6. **[IC-2]** Changed `checkHeartbeat()` from `bool` to `void` return type — return value was unused by sole caller.
7. **[Q1]** Updated stale comment in main.cpp referencing old `_lastHeartbeatMs` field name.

### Verification Checklist
- [x] All 3 environments build after audit fixes
- [ ] Verify battery percentage reads correctly on CYD-S3 with LiPo connected
- [ ] Verify battery percentage reads correctly on LILYGO with LiPo connected
- [ ] Verify USB icon turns green when companion connects
- [ ] Verify BT icon turns blue when BLE companion connects
- [ ] Verify bolt icon appears when USB connected + battery > 4.1V
- [ ] Verify status bar text doesn't overlap battery indicator in AGENT_LIST mode
- [ ] Verify tap-to-cycle status modes still works on CYD/CYD-S3
