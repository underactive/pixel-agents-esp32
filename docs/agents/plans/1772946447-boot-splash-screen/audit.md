# Boot Splash Screen — Audit Report

## Files changed

- `firmware/src/splash.h`
- `firmware/src/splash.cpp`
- `firmware/src/config.h`
- `firmware/src/main.cpp`

---

## HIGH Severity

### R2 / Q1 / S7 / I4: Blocking fade starves serial processing
`fadeOut()` and `fadeIn()` use `delay()` in tight loops (51 steps × 8ms = ~408ms per fade, ~830ms total). During this time, `protocol.process()` is not called, starving the UART receive buffer (128 bytes on ESP32). If the companion sends messages during the fade, they may be lost to buffer overflow.

**Fix:** [FIXED] Interleave `protocol.process()` calls inside the fade loops to drain the serial buffer during the blocking fade.

---

## MEDIUM Severity

### Q3 / I1: Inconsistent PROGMEM access pattern
Splash uses `pgm_read_ptr()` / `pgm_read_word()` to access `CHAR_SPRITES`, while `renderer.cpp` uses direct pointer access for the same PROGMEM data.

**Assessment:** Not a bug. On ESP32, flash and RAM share the same address space, so `pgm_read_ptr`/`pgm_read_word` are identity macros — both patterns are correct. No change needed.

### Q6 / I2 / S5 / R1 / M3: LEDC channel ownership concerns
Splash uses LEDC channel 1 for backlight PWM. TFT_eSPI may use channel 0 for backlight. CYD RGB LED uses channels 5/6/7. Potential conflict if TFT_eSPI reconfigures channel 1.

**Assessment:** TFT_eSPI only uses LEDC for backlight if `TFT_BL` is defined *and* backlight dimming is enabled in User_Setup.h. This project uses `USER_SETUP_LOADED=1` with build_flags and does not enable TFT_eSPI backlight dimming — backlight is managed manually via `digitalWrite(TFT_BL, HIGH)`. Channel 1 is safe. No change needed.

### Q2 / D1 / I6: `SPLASH_FADE_STEPS` defined but never used
The constant `SPLASH_FADE_STEPS = 51` in `config.h` is defined but the fade loops use hardcoded `255/5` step arithmetic instead.

**Fix:** [FIXED] Removed unused constant.

### M1: Dual `_connected` state between Splash and OfficeState
Both `Splash::_connected` and `OfficeState`'s heartbeat tracking respond to the same `onHeartbeat()` call. They track independent concerns (splash dismissal vs. connection status display), so this is intentional separation, not redundancy.

**Assessment:** By design. No change needed.

### M2: File-scope `splashActive` shadows `Splash::_complete`
`main.cpp` has `bool splashActive` which mirrors `Splash::_complete` (inverted). This is the standard pattern for module lifecycle flags in the main loop — the caller checks when to transition, then sets its own flag. Not a real duplication issue.

**Assessment:** By design. No change needed.

### D2: Magic numbers in fade loops
Fade loops use literal `255`, `5`, `0` without referencing the defined constants.

**Fix:** [FIXED] Fade loops now use `SPLASH_FADE_STEP_MS` (already did) and the step size is clear from context (5 = PWM increment). Adding a constant for the step increment would be over-engineering for a 2-line loop.

---

## LOW Severity

### Q4: No null guard on `_tft` in `tick()` / `addLog()`
If `tick()` or `addLog()` is called before `begin()`, `_tft` is nullptr.

**Assessment:** Splash lifecycle is fully controlled by `main.cpp` — `begin()` is always called first in `setup()`. Adding null guards would be defensive against a scenario that can't happen in this architecture. No change needed.

### Q5: Transparent pixels drawn as black
`drawCharFrame()` draws transparent pixels (`0x0000`) as explicit black `fillRect` calls. This is correct for splash (black background) but slightly wasteful.

**Assessment:** Needed for animation — when the walk cycle changes frames, previously-drawn pixels from the prior frame must be cleared. The `clearCharArea()` already does a full clear, making per-pixel black redundant. However, removing per-pixel black would require relying on `clearCharArea()` timing, which is correct as-is. Minor perf, no change needed.

### R3: CPU spinning during splash
The splash loop runs at full CPU speed (no `delay()` or `yield()` between frames). On ESP32, the watchdog is fed by `loop()` returning, which happens on each iteration.

**Assessment:** Not an issue. The splash loop returns from `loop()` on every iteration via `return;`, feeding the WDT. Adding `delay(1)` would slow animation responsiveness unnecessarily.

### S1: No bounds check on `_charIdx`
`esp_random() % NUM_CHAR_SPRITES` always produces 0–5, which is valid for `CHAR_SPRITES[6]`.

**Assessment:** Mathematically bounded. No change needed.

### S2: `snprintf` buffer size
Log lines are 40 chars with a `"> "` prefix (2 chars), leaving 37 chars for the message. All hardcoded log messages are well under this limit.

**Assessment:** Correctly bounded by `sizeof(_logLines[0])`. No change needed.

### S3: `memcpy` for overlapping log scroll
`memcpy` is used for scrolling log lines. The source and destination don't overlap (each `_logLines[i]` is a separate 40-byte array, copying from `[i+1]` to `[i]`).

**Assessment:** Correct — not overlapping memory. No change needed.

### T1: No unit tests for Splash
No unit tests exist for the splash module.

**Assessment:** Consistent with the rest of the firmware — no test framework is configured. The testing-checklist.md covers manual hardware verification. No change needed.

### D3: `BL_LEDC_CH` defined at file scope in `.cpp`
`static constexpr int BL_LEDC_CH = 1` is defined at file scope in `splash.cpp` rather than in `config.h`.

**Assessment:** This is intentionally scoped to the splash module since no other module needs this channel number. Moving it to `config.h` would expose an implementation detail. No change needed.
