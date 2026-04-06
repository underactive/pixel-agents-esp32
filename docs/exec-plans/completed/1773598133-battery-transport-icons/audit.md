# Audit: Battery Monitor + Transport Icons

## Files Changed (flagged findings)

- `firmware/src/battery.cpp` — S1 (div-by-zero guard), RC3 (per-pin attenuation), D1 (use named constants in curve)
- `firmware/src/config.h` — R2 (add BATTERY_WARN_PCT/BATTERY_CRIT_PCT), D1 (BATTERY_FULL_MV/BATTERY_EMPTY_MV unused)
- `firmware/src/main.cpp` — SM-1/RC2/IC-1/Q2 (redundant battery_setUsbConnected), Q1 (stale comment)
- `firmware/src/office_state.h` — IC-2 (checkHeartbeat return type)
- `firmware/src/office_state.cpp` — IC-2 (checkHeartbeat return type)
- `firmware/src/renderer.cpp` — R2 (magic number thresholds)

## QA Audit

- **[FIXED] Q1:** Stale comment referencing old `_lastHeartbeatMs` in main.cpp — updated
- **[FIXED] Q2:** Redundant `battery_setUsbConnected(true)` in heartbeat callback — removed
- Q3: `gfxDrawMonoBitmap` assumes 1 byte per row (w<=8). Documented in header comment. Accepted — all callers pass w=5.
- Q4: Charging heuristic shows "charging" for fully charged battery on USB. Accepted — known limitation of voltage-only heuristic.

## Security Audit

- **[FIXED] S1:** Missing division-by-zero guard in `voltageToPercent` — added `if (hiMv == loMv)` check
- S2: No overflow clamp in `readBatteryMv`. Accepted — max possible value (3300*2=6600) fits uint16_t. Hardware fault values would be caught by EMA smoothing.

## Interface Contract Audit

- **[FIXED] IC-1:** Redundant `battery_setUsbConnected(true)` in callback — removed (same as Q2)
- **[FIXED] IC-2:** `checkHeartbeat()` return value unused — changed to void
- IC-3: `BATTERY_VOLTAGE_DIVIDER` shared across boards. Accepted — both CYD-S3 and LILYGO confirmed to use 2:1 dividers.
- IC-4: Charging heuristic false positives. Accepted — same as Q4.
- IC-5: No guard on battery getters before `battery_begin()`. Accepted — init order guarantees begin() runs first.

## State Management Audit

- **[FIXED] SM-1:** Redundant `battery_setUsbConnected(true)` in callback — removed (same as Q2/IC-1)
- SM-7: Renderer reads battery directly instead of via OfficeState. Accepted — consistent with simple free-function module pattern. Adding OfficeState indirection would be over-engineering for a read-only value.

## Resource & Concurrency Audit

- **[FIXED] RC2:** Same as SM-1 — removed
- **[FIXED] RC3:** `analogSetAttenuation()` sets global ADC attenuation — changed to `analogSetPinAttenuation()` for isolation
- RC1/RC4/RC5/RC6/RC7: Verified correct — no concurrency issues, no resource leaks.

## DX & Maintainability Audit

- R1: `drawStatusBar()` is 183 lines. Accepted — extracting helpers would fragment the status bar layout logic. The function is linear with clear section comments.
- **[FIXED] R2:** Battery color thresholds 50/20 are magic numbers — added `BATTERY_WARN_PCT` and `BATTERY_CRIT_PCT` constants
- **[FIXED] D1:** `BATTERY_FULL_MV` and `BATTERY_EMPTY_MV` defined but unused — now used as first/last entries in discharge curve
- N2: `COLOR_CHARGING` name reused for battery warning. Accepted — the yellow color is semantically appropriate for both "charging" and "warning" contexts.
- D-DOC1: `battery_setUsbConnected()` lacks doc comment. Accepted — the coupling is straightforward and the single call site in main.cpp is self-documenting.
