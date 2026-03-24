# Boot Splash Screen

## Objective

Replace the static text splash with an animated boot splash screen that shows:
- "PIXEL AGENTS" title in a pixel-style font
- A randomly selected character (1 of 6) at 2x scale, playing a walk-down animation in place
- Verbose boot log lines appearing in real-time as subsystems initialize
- Final "Connected!" message when first heartbeat arrives from companion
- 3-second hold after connection, then backlight fade-out → render first office frame → backlight fade-in transition

## Layout

```
Both boards (320px wide), vertically scaled per board height:

┌──────────────────────────────────┐
│                                  │
│         PIXEL  AGENTS            │  title, Font 1 textSize(3), chunky pixel look
│                                  │
│           ┌────────┐             │
│           │        │             │
│           │ char   │ 32x64 (2x) │  walk-down cycle [w1,w2,w3,w2], 150ms/frame
│           │ sprite │             │
│           │        │             │
│           └────────┘             │
│                                  │
│  > Display initialized           │  Font 1 textSize(1), green text, ">" prefix
│  > Office state ready            │  lines appear as each subsystem completes
│  > Render buffer allocated       │
│  > Serial protocol ready         │
│  > Waiting for companion...      │
│  > Connected!                    │  appears on first heartbeat
└──────────────────────────────────┘
```

**LILYGO (320x170):** title y=8, character y=30, log area y=98, ~6 visible log lines
**CYD (320x240):** title y=15, character y=42, log area y=112, ~10 visible log lines

## Changes

### New: `firmware/src/splash.h`
Splash class declaration:
- `begin(TFT_eSPI& tft)` — init, pick random char via `esp_random() % 6`, draw title + first frame
- `addLog(const char* msg)` — append line to boot log area with ">" prefix
- `tick()` — advance walk animation frame every 150ms; returns true while splash active
- `onHeartbeat()` — trigger "Connected!" log, start 3s hold timer
- `fadeOut()` / `fadeIn()` — backlight LEDC PWM fade over ~400ms
- `isActive()` — true until 3s hold after connection completes

### New: `firmware/src/splash.cpp`
Implementation:
- Character selection: `esp_random() % 6` (hardware RNG, no seed needed)
- Walk animation: cycle [walk1, walk2, walk3, walk2] at 150ms/frame, direction DOWN
- 2x rendering: each sprite pixel → 2x2 `tft.fillRect()`, skip 0x0000 (transparent)
- Character drawn centered: x = (320 - 32) / 2 = 144
- Log area: fixed-size circular buffer of log strings; when full, scroll up (redraw area)
- Green text (`0x07E0`) with ">" prefix on black background for terminal aesthetic
- Backlight fade via LEDC: `ledcAttach(pin, 5000, 8)` / `ledcWrite(pin, duty)` / `ledcDetach(pin)`
  - LEDC channel auto-assigned by pin-based API (ESP32 Arduino Core 3.x)
  - After fade-in completes, detach LEDC and revert to `digitalWrite(HIGH)`

### Modified: `firmware/src/config.h`
Add splash constants:
- `SPLASH_CHAR_SCALE` (2)
- `SPLASH_ANIM_FRAME_MS` (150)
- `SPLASH_CONNECTED_HOLD_MS` (3000)
- `SPLASH_FADE_STEPS` (51) — 255/5 steps
- `SPLASH_FADE_STEP_MS` (8) — ~400ms total fade
- `SPLASH_MAX_LOG_LINES` — 6 (LILYGO) / 10 (CYD)
- `SPLASH_LOG_LINE_H` (10)
- Board-specific Y offsets: `SPLASH_TITLE_Y`, `SPLASH_CHAR_Y`, `SPLASH_LOG_Y`

### Modified: `firmware/src/main.cpp`
- Remove old `drawSplash()` function
- Add `#include "splash.h"` and `Splash splash;` global
- Rework `setup()`:
  1. Serial + TFT init + backlight on
  2. `splash.begin(tft)` — draws title + first character frame
  3. `splash.addLog("Display initialized")`
  4. `office.init()` → `splash.addLog("Office state ready")`
  5. `renderer.begin(tft)` → `splash.addLog("Render buffer allocated")`
  6. `protocol.begin(...)` → `splash.addLog("Serial protocol ready")`
  7. `randomSeed(...)` + `office.spawnAllCharacters()` → `splash.addLog("Characters spawned")`
  8. Touch/LED init → log lines (CYD only)
  9. `splash.addLog("Waiting for companion...")`
- Add `bool splashActive = true;` global
- Modify `loop()`:
  - When `splashActive`:
    - `protocol.process()` (to receive heartbeat)
    - `splash.tick()` (animate character)
    - On heartbeat callback: `splash.onHeartbeat()`
    - When `!splash.isActive()`: `splash.fadeOut()`, render first office frame via `renderer.renderFrame()`, `splash.fadeIn()`, set `splashActive = false`
  - When `!splashActive`: existing office loop (unchanged)

### Modified: `CLAUDE.md`
- Add `firmware/src/splash.h/.cpp` to File Inventory
- Add splash subsystem to Architecture > Key Subsystems

### Modified: `docs/CLAUDE.md/version-history.md`
- New version entry for splash screen

### Modified: `docs/CLAUDE.md/testing-checklist.md`
- Test items for splash screen behavior

### Modified: `docs/CLAUDE.md/future-improvements.md`
- Mark "Boot animation" item as done

## Dependencies

- Splash module includes `sprites/characters.h` for `CHAR_SPRITES` lookup table
- Splash draws directly to TFT (before renderer buffer allocation) — no dependency on Renderer
- `esp_random()` available without setup on ESP32 (hardware TRNG)
- LEDC for backlight fade must not conflict with CYD RGB LED channels (5/6/7)
  - Pin-based `ledcAttach()` API auto-assigns channels; no manual channel selection needed

## Risks / Open Questions

1. **LEDC API version**: ESP32 Arduino Core 3.x uses `ledcAttach(pin, freq, res)` (pin-based). Older cores use `ledcSetup(channel, freq, res)` + `ledcAttachPin(pin, channel)`. Since `platform = espressif32` is unpinned, assume latest (3.x).
   - Mitigation: If build fails, add `#if` fallback for old API.

2. **TFT_eSPI backlight conflict**: TFT_eSPI may internally manage the backlight pin. Current code uses `digitalWrite` so no conflict expected, but if TFT_eSPI enables PWM internally, the `ledcAttach` call could collide.
   - Mitigation: Set up LEDC only at fade time (after all TFT init is done), detach immediately after.

3. **Font quality**: Using built-in TFT_eSPI Font 1 at textSize(3) for title. It's a 5x7 pixel font so it'll look blocky/retro. This matches the pixel-art aesthetic but may look crude.
   - Mitigation: Can replace with custom pixel font renderer in a follow-up if needed.
