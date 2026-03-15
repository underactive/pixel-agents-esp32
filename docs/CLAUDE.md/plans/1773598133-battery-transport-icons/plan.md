# Plan: Battery Monitor + Transport Icons in Status Bar

## Objective

Add battery percentage display and transport connection icons (USB/BLE) to the status bar. Both the CYD-S3 and LILYGO boards have built-in battery voltage dividers. Charging is inferred from USB (serial) connection + high voltage since neither board has a dedicated charging detection pin.

## Status Bar Layout

```
BEFORE:  [green/red dot] [status text............] [hamburger]
AFTER:   [USB][BT] [status text.........] [bolt 87%] [hamburger]
```

## Changes

### 1. `firmware/src/config.h`
- Add `HAS_BATTERY` auto-define for CYD-S3 and LILYGO
- Add `BATTERY_ADC_PIN` (9 for CYD-S3, 4 for LILYGO)
- Add battery constants (voltage divider, read interval, smoothing, voltage thresholds)
- Add transport icon constants and new colors

### 2. `firmware/src/battery.h` (new)
- Free-function API: `battery_begin()`, `battery_update()`, `battery_getPercent()`, `battery_isCharging()`, `battery_setUsbConnected()`
- Gated by `HAS_BATTERY`

### 3. `firmware/src/battery.cpp` (new)
- ADC reading with EMA smoothing
- LiPo discharge curve lookup table
- Charging heuristic: USB connected + voltage > 4.1V

### 4. `firmware/src/office_state.h`
- Split `_connected`/`_lastHeartbeatMs` into per-transport (serial + BLE)
- New methods: `onSerialHeartbeat()`, `onBleHeartbeat()`, `isSerialConnected()`, `isBleConnected()`
- Keep `isConnected()` as `serial || ble` for backward compat

### 5. `firmware/src/office_state.cpp`
- Implement per-transport heartbeat tracking

### 6. `firmware/src/main.cpp`
- Split `onHeartbeat` callback into serial/BLE variants
- Wire battery module

### 7. `firmware/src/renderer.h`
- Add `gfxDrawMonoBitmap()` helper

### 8. `firmware/src/renderer.cpp`
- Add icon bitmaps (USB, BT, bolt)
- Redesign status bar with transport icons and battery indicator

### 9. `CLAUDE.md`
- Document new battery module, constants, and status bar changes

## Dependencies
- config.h → battery.h/cpp (constants)
- office_state changes → main.cpp (callback split) → renderer.cpp (per-transport queries)

## Risks
| Risk | Mitigation |
|------|-----------|
| `isConnected()` callers break | Preserved as `serial \|\| ble` |
| ADC noise | EMA smoothing + coarse lookup table |
| CYD strip-buffer rendering | All drawing via `gfxFillRect` handles `_yOffset` |

## Verification
- Build all 3 environments
- CYD: USB+BT icons, no battery, no compile errors
- CYD-S3: USB+BT icons, battery %, bolt when charging
- LILYGO: USB icon only, battery %, no BT icon
