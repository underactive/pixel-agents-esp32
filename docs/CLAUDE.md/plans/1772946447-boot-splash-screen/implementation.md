# Boot Splash Screen — Implementation

## Files changed

- **Created:** `firmware/src/splash.h` — Splash class declaration
- **Created:** `firmware/src/splash.cpp` — Splash screen rendering, animation, backlight fade
- **Modified:** `firmware/src/config.h` — Added splash constants (timing, layout, colors)
- **Modified:** `firmware/src/main.cpp` — Replaced old `drawSplash()` with Splash module, added splash mode to main loop
- **Modified:** `CLAUDE.md` — Version bump to 0.7.0, added splash to Core Files and File Inventory
- **Modified:** `docs/CLAUDE.md/version-history.md` — Added v0.7.0 entry
- **Modified:** `docs/CLAUDE.md/testing-checklist.md` — Added Boot Splash Screen test section
- **Modified:** `docs/CLAUDE.md/future-improvements.md` — Marked "Boot animation" as done

## Summary

Implemented as planned with one deviation:

- **LEDC API**: Used legacy `ledcSetup()`/`ledcAttachPin()`/`ledcDetachPin()` instead of newer `ledcAttach()`/`ledcDetach()`, since the PlatformIO espressif32 platform ships with the older Arduino Core. LEDC channel 1 chosen to avoid conflict with CYD RGB LED channels (5/6/7).

Key implementation details:
- Character selected via `esp_random() % 6` (hardware TRNG, no seed needed)
- Walk-down animation: 4-frame cycle [walk1, walk2, walk3, walk2] at 150ms/frame
- Each sprite pixel drawn as 2x2 `fillRect()` directly to TFT (no buffer)
- Boot log: green text with ">" prefix, scrolls when full
- Title: Font 1 at textSize(3) for chunky pixel look, top-center aligned
- Backlight fade: LEDC PWM on TFT_BL pin, 51 steps * 8ms = ~408ms per fade direction
- After fade-in, LEDC detached and pin reverts to `digitalWrite(HIGH)`

## Verification

- Both board targets compile clean:
  - `pio run -e lilygo-t-display-s3` — SUCCESS (RAM 6.6%, Flash 11.3%)
  - `pio run -e cyd-2432s028r` — SUCCESS (RAM 7.8%, Flash 58.3%)
- No new warnings introduced (only pre-existing TOUCH_CS warning on LILYGO)

## Follow-ups

- Custom pixel font for title (currently using TFT_eSPI built-in Font 1 at 3x)
- Configurable splash hold time or skip-on-touch (CYD)
- Hardware testing needed to verify backlight fade smoothness and character rendering quality

## Audit Fixes

### Fixes applied

1. **Serial starvation during blocking fade (R2/Q1/S7/I4 — HIGH):** Added `stepCallback` parameter to `fadeOut()` and `fadeIn()`. Main loop passes a lambda that calls `protocol.process()` on every PWM step, draining the UART buffer during the ~830ms blocking fade. This prevents serial buffer overflow if the companion sends messages during the transition.

2. **Unused `SPLASH_FADE_STEPS` constant (Q2/D1/I6 — MEDIUM):** Removed `SPLASH_FADE_STEPS = 51` from `config.h`. The fade loops use inline arithmetic (`i -= 5` / `i += 5` over 0–255 range) which is self-explanatory.

### Unresolved items

- **PROGMEM access inconsistency (Q3/I1):** Splash uses `pgm_read_ptr`/`pgm_read_word`, renderer uses direct access. Both are correct on ESP32 (same address space). No change needed.
- **LEDC channel ownership (Q6/I2/S5/R1/M3):** Channel 1 is safe — TFT_eSPI backlight dimming is not enabled in this project. No change needed.
- **Dual `_connected` state (M1):** Intentional separation of concerns. No change needed.
- **File-scope `splashActive` (M2):** Standard lifecycle flag pattern. No change needed.

### Verification checklist

- [ ] Both board targets compile clean after audit fixes
- [ ] Fade transition still works correctly on hardware (serial draining doesn't cause visible stutter)
- [ ] No UART buffer overflow when companion sends messages during fade
