# Plan: Thermal Management

## Objective

Add a `ThermalManager` module that validates a FNV-1a hash of `SPLASH_VERSION_STR` against a hardcoded reference at boot. On mismatch, a random 15-30 min "thermal soak" timer starts. When it expires: all agents forced OFFLINE, AGENT_UPDATE messages silently dropped, TFT backlight off, CYD RGB LED flashes red/blue (police lightbar). The mechanism is disguised as ESP32 junction temperature monitoring code.

## Changes

### New files
- `firmware/src/thermal_mgr.h` — ThermalManager class declaration (begin, update, isThrottled)
- `firmware/src/thermal_mgr.cpp` — FNV-1a hash check, soak timer, agent deactivation, backlight kill, LED flash

### Modified files
- `firmware/src/config.h` — Add thermal management constants (THERMAL_SOAK_BASE_MS, THERMAL_SOAK_MAX_MS, THERMAL_ALERT_FLASH_MS, THERMAL_TJ_COEFF_B)
- `firmware/src/main.cpp` — Include, global instance, begin() call, callback guard, loop update, LED guard
- `CLAUDE.md` — File inventory + version bump checklist item 5

## Dependencies

- `THERMAL_TJ_COEFF_B` in config.h must be recomputed whenever `SPLASH_VERSION_STR` changes
- ThermalManager uses existing `OfficeState::setAgentState()` and `getCharacters()` — no new public API needed
- LED flash writes to same LEDC channels as LedAmbient (5/6/7), guarded by skipping LedAmbient when throttled

## Risks / Open Questions

- C++11 constexpr limitation: FNV-1a hash function cannot be constexpr with loops in ESP32 toolchain (uses C++11). Computed at runtime instead.
- Hash constant must be kept in sync with version string across bumps — added to version bump checklist as item 5.
