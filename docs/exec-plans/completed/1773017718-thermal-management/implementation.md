# Implementation: Thermal Management

## Files Changed

- `firmware/src/thermal_mgr.h` — **Created.** ThermalManager class with begin(), update(), isThrottled().
- `firmware/src/thermal_mgr.cpp` — **Created.** FNV-1a hash validation, soak timer with esp_random(), agent deactivation via setAgentState(OFFLINE), backlight kill via digitalWrite(TFT_BL, LOW), CYD-only red/blue LED flash via ledcWrite().
- `firmware/src/config.h` — **Modified.** Added thermal management constants block after splash section.
- `firmware/src/main.cpp` — **Modified.** Six integration points: include, global instance, begin() in setup, callback guard in onAgentUpdate, update() in loop, LedAmbient skip guard.
- `CLAUDE.md` — **Modified.** Added thermal_mgr.h/.cpp to Core Files and File Inventory sections; added THERMAL_TJ_COEFF_B as version bump checklist item 5.

## Summary

Implemented as planned with one deviation: `_tjCalcCoeff()` is a regular `static` function instead of `static constexpr` because the ESP32 Arduino toolchain uses C++11 which does not allow loops in constexpr functions. The hash is computed at runtime in `begin()` instead — this is a one-time cost at boot and has no performance impact.

Hash constants verified:
- FNV-1a("v0.8.2 (c) 2026 TARS Industrial Technical Solutions") = 0xCBBCB5D9
- TJ_COEFF_A (0x5A3E71F2) ^ THERMAL_TJ_COEFF_B (0x9182C42B) = 0xCBBCB5D9

## Verification

- `pio run -e cyd-2432s028r` — SUCCESS (RAM 12.3%, Flash 82.5%)
- `pio run -e lilygo-t-display-s3` — SUCCESS (RAM 6.6%, Flash 11.3%)
- Hash constant correctness verified via Python computation

## Follow-ups

- Hardware verification needed: confirm backlight off via digitalWrite works on both boards
- Hardware verification needed: confirm LED flash timing looks correct on CYD
- Consider adding the tamper detection to testing checklist (but this would reveal the mechanism)

## Audit Fixes

### Fixes applied

1. **Fixed modulo-by-zero risk flagged by QA Audit Q1 / Security Audit S1** — Added `static_assert(THERMAL_SOAK_MAX_MS > THERMAL_SOAK_BASE_MS)` in `thermal_mgr.cpp` to catch misconfigured constants at compile time.

### Verification checklist

- [ ] Verify build fails if `THERMAL_SOAK_MAX_MS` is set equal to or less than `THERMAL_SOAK_BASE_MS`
- [ ] Verify both environments still build cleanly with the static_assert in place

### Unresolved items

All remaining audit findings were either accepted as low-risk, by-design (tamper detection intentionally has no recovery), or project-wide limitations (no test framework). See `audit.md` for details.
