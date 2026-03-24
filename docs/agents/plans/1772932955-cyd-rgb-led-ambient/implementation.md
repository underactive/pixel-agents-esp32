# Implementation: CYD RGB LED Ambient Lighting

## Files Changed

- `firmware/src/config.h` — Added LED pin/channel constants, `LedMode` enum, brightness constants (all inside `#if defined(BOARD_CYD)`)
- `firmware/src/led_ambient.h` — **New file.** `LedAmbient` class declaration with forward-declared `OfficeState`
- `firmware/src/led_ambient.cpp` — **New file.** LED mode resolution, PWM output, sine-wave breathe/pulse animation
- `firmware/src/main.cpp` — Wired `LedAmbient` into setup/loop (guarded by `BOARD_CYD`)
- `docs/CLAUDE.md/testing-checklist.md` — Added 8 LED ambient testing items

## Summary

Implemented as planned. The CYD's built-in RGB LED (GPIOs 4/16/17, active-LOW) reflects office activity:

- **OFF** when disconnected
- **Dim cyan breathe** (4s cycle) when connected with no active agents
- **Solid green** (brightness scales with 1–3 active agents) when agents are working
- **Amber** when 4+ agents are busy
- **Red pulse** (2s cycle) when usage stats ≥ 90%

All LED code is guarded by `#if defined(BOARD_CYD)` — zero impact on LILYGO build.

## Verification

- `pio run -e cyd-2432s028r` — SUCCESS
- `pio run -e lilygo-t-display-s3` — SUCCESS (no LED symbols leak into LILYGO build)
- Hardware testing pending (CYD board not connected)

## Follow-ups

- Hardware verification of GPIO 4/16/17 driving the RGB LED correctly (active-LOW)
- Verify LEDC channels 5/6/7 don't conflict with TFT_eSPI (expected safe — TFT_eSPI uses channel 0)
- Future: auto-brightness via CYD's LDR on GPIO 34
- Future: if Arduino-ESP32 v3.x is adopted, migrate from `ledcSetup`/`ledcAttachPin` to `ledcAttach` API

## Audit Fixes

Fixes applied from the consolidated 7-subagent audit:

1. **[SM-1/S2/Q1/RC1/T4/IC-1] Phase wrapping** — Added `if (_phase > 1000.0f) _phase -= 1000.0f;` after accumulation to prevent float precision loss on long uptimes
2. **[Q2/D2] SINE_LUT fix** — Replaced duplicated half-wave with a proper 16-entry half-wave (0→peak→0 with dwell at zero), indexed with `& 15` so full breathe cycle matches the configured period
3. **[S1/Q3/D3/IC-3] Brightness scaling** — Replaced magic numbers with `LED_ACTIVE_MIN_BRIGHT`/`LED_ACTIVE_MAX_BRIGHT` constants; step computed from `LED_BUSY_THRESHOLD`; clamped with `if (bright > max)`
4. **[SM-5/S4/Q4/D1/IC-2] Board guard** — Moved `LedMode` enum and all LED constants inside `#if defined(BOARD_CYD)` block
5. **[T3] Testing checklist** — Added 8 observable-behavior test items to `docs/CLAUDE.md/testing-checklist.md`
6. **[D6] Forward declaration** — Replaced `#include "office_state.h"` with `class OfficeState;` in `led_ambient.h`; moved include to `.cpp`
7. **[D5] Doc comment** — Added return-value comment on `breathe()` in header
8. **[Q5] Default case** — Added `default: setRGB(0,0,0);` to the mode switch

### Verification checklist

- [x] CYD build succeeds with all fixes
- [x] LILYGO build succeeds (no LED symbols leaked)
- [ ] Verify breathe animation runs at correct 4s period (not 2s) on hardware
- [ ] Verify green brightness visibly increases from 1→2→3 active agents
- [ ] Verify phase wrap doesn't cause visible glitch at 1000s boundary
