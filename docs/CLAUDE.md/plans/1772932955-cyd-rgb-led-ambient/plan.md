# Plan: CYD RGB LED Ambient Lighting

## Objective

Use the CYD board's built-in RGB LED (GPIOs 4/16/17, active-LOW) to reflect office activity as ambient lighting. The LED provides at-a-glance status without looking at the screen — glowing when agents are working, pulsing gently when idle, and going dark when disconnected.

## Hardware

The ESP32-2432S028R has a discrete common-anode RGB LED:

| Channel | GPIO | Active-LOW |
|---------|------|------------|
| Red     | 4    | YES        |
| Green   | 16   | YES        |
| Blue    | 17   | YES        |

Driven via ESP32 LEDC PWM (8-bit, ~5kHz). Active-LOW means duty 255 = OFF, duty 0 = full brightness.

## LED Modes

The LED mode is derived from office state each frame — no serial protocol changes needed.

| Mode | Condition | Color | Behavior |
|------|-----------|-------|----------|
| **OFF** | Disconnected (no heartbeat) | — | LED fully off |
| **IDLE** | Connected, 0 agents active | Dim cyan | Slow breathe (4s period) |
| **ACTIVE** | 1+ agents in TYPE/READ | Green | Solid glow, brightness scales with agent count (1=40%, 6=100%) |
| **BUSY** | 4+ agents in TYPE/READ | Amber/orange | Solid glow |
| **RATE_LIMITED** | Usage stats ≥ 90% current_pct | Red | Slow pulse (2s period) |

Priority (highest wins): RATE_LIMITED > BUSY > ACTIVE > IDLE > OFF.

The breathe/pulse effects use a sine-wave LUT (32 entries) to avoid floating-point math in the hot path.

## Changes

### 1. `firmware/src/config.h` — Add LED constants

```cpp
// ── RGB LED (CYD only) ──────────────────────────────────
#if defined(BOARD_CYD)
static constexpr int LED_PIN_R = 4;
static constexpr int LED_PIN_G = 16;
static constexpr int LED_PIN_B = 17;
static constexpr int LED_PWM_FREQ = 5000;    // 5kHz
static constexpr int LED_PWM_RES  = 8;       // 8-bit (0-255)
// LEDC channels (0-15 available; TFT_eSPI uses some, pick high)
static constexpr int LED_LEDC_CH_R = 5;
static constexpr int LED_LEDC_CH_G = 6;
static constexpr int LED_LEDC_CH_B = 7;
#endif
```

Add LED mode enum:

```cpp
enum class LedMode : uint8_t {
    OFF          = 0,
    IDLE_BREATHE = 1,
    ACTIVE       = 2,
    BUSY         = 3,
    RATE_LIMITED = 4
};
```

Add timing constants:

```cpp
static constexpr float LED_BREATHE_PERIOD_SEC = 4.0f;   // idle breathe cycle
static constexpr float LED_PULSE_PERIOD_SEC   = 2.0f;   // rate-limited pulse cycle
static constexpr int   LED_BUSY_THRESHOLD     = 4;      // agents for BUSY mode
static constexpr uint8_t LED_RATE_LIMIT_PCT   = 90;     // usage % to trigger rate-limited mode
```

### 2. `firmware/src/led_ambient.h` — New header (CYD only)

```cpp
#pragma once
#if defined(BOARD_CYD)

#include "config.h"
#include "office_state.h"

class LedAmbient {
public:
    void begin();
    void update(const OfficeState& office, float dt);

private:
    LedMode _mode = LedMode::OFF;
    float _phase = 0.0f;           // 0.0–1.0 animation phase

    void setRGB(uint8_t r, uint8_t g, uint8_t b);
    LedMode resolveMode(const OfficeState& office) const;
    uint8_t breathe(float period) const;  // returns brightness 0-255
};

#endif
```

### 3. `firmware/src/led_ambient.cpp` — New implementation (CYD only)

```cpp
#if defined(BOARD_CYD)
#include "led_ambient.h"
#include <Arduino.h>

// 32-entry sine LUT for smooth breathe/pulse (0-255)
static const uint8_t SINE_LUT[32] PROGMEM = {
    0,   6,  25,  55,  96, 143, 190, 228,
  253, 255, 237, 201, 153, 100,  51,  16,
    0,   6,  25,  55,  96, 143, 190, 228,
  253, 255, 237, 201, 153, 100,  51,  16
};

void LedAmbient::begin() {
    ledcSetup(LED_LEDC_CH_R, LED_PWM_FREQ, LED_PWM_RES);
    ledcSetup(LED_LEDC_CH_G, LED_PWM_FREQ, LED_PWM_RES);
    ledcSetup(LED_LEDC_CH_B, LED_PWM_FREQ, LED_PWM_RES);
    ledcAttachPin(LED_PIN_R, LED_LEDC_CH_R);
    ledcAttachPin(LED_PIN_G, LED_LEDC_CH_G);
    ledcAttachPin(LED_PIN_B, LED_LEDC_CH_B);
    setRGB(0, 0, 0); // start off
}

void LedAmbient::setRGB(uint8_t r, uint8_t g, uint8_t b) {
    // Active-LOW: 255 - value inverts for common-anode LED
    ledcWrite(LED_LEDC_CH_R, 255 - r);
    ledcWrite(LED_LEDC_CH_G, 255 - g);
    ledcWrite(LED_LEDC_CH_B, 255 - b);
}

LedMode LedAmbient::resolveMode(const OfficeState& office) const {
    if (!office.isConnected()) return LedMode::OFF;

    const UsageStats& usage = office.getUsageStats();
    if (usage.valid && usage.currentPct >= LED_RATE_LIMIT_PCT)
        return LedMode::RATE_LIMITED;

    int active = office.getActiveAgentCount();
    if (active >= LED_BUSY_THRESHOLD) return LedMode::BUSY;
    if (active > 0)                   return LedMode::ACTIVE;
    return LedMode::IDLE_BREATHE;
}

uint8_t LedAmbient::breathe(float period) const {
    float pos = _phase / period;
    pos -= (int)pos;                          // fract 0.0-1.0
    int idx = (int)(pos * 32) & 31;
    return pgm_read_byte(&SINE_LUT[idx]);
}

void LedAmbient::update(const OfficeState& office, float dt) {
    LedMode newMode = resolveMode(office);
    if (newMode != _mode) {
        _mode = newMode;
        _phase = 0.0f;    // reset animation on mode change
    }
    _phase += dt;

    switch (_mode) {
        case LedMode::OFF:
            setRGB(0, 0, 0);
            break;

        case LedMode::IDLE_BREATHE: {
            uint8_t b = breathe(LED_BREATHE_PERIOD_SEC);
            setRGB(0, b / 4, b / 3);        // dim cyan
            break;
        }

        case LedMode::ACTIVE: {
            int active = office.getActiveAgentCount();
            // Scale brightness: 1 agent=40%, 6 agents=100%
            uint8_t bright = 100 + (active - 1) * 31;  // 100..255
            setRGB(0, bright, 0);            // green
            break;
        }

        case LedMode::BUSY:
            setRGB(255, 100, 0);             // amber/orange
            break;

        case LedMode::RATE_LIMITED: {
            uint8_t b = breathe(LED_PULSE_PERIOD_SEC);
            setRGB(b, 0, 0);                // red pulse
            break;
        }
    }
}

#endif
```

### 4. `firmware/src/main.cpp` — Wire up LedAmbient

Add include and instance (inside `#if defined(BOARD_CYD)` or `HAS_TOUCH` guard — use `BOARD_CYD` since the LED exists on all CYD boards regardless of touch):

```cpp
#if defined(BOARD_CYD)
#include "led_ambient.h"
LedAmbient ledAmbient;
#endif
```

In `setup()`, after `office.init()`:

```cpp
#if defined(BOARD_CYD)
    ledAmbient.begin();
#endif
```

In `loop()`, after `office.update(dt)`:

```cpp
#if defined(BOARD_CYD)
    ledAmbient.update(office, dt);
#endif
```

### 5. `firmware/src/office_state.h` — Make `getUsageStats()` available

Already exists: `const UsageStats& getUsageStats() const`. No change needed.
`getActiveAgentCount()` also already exists. No change needed.

## Dependencies

- `led_ambient.cpp` depends on `config.h` (pin/channel constants) and `office_state.h` (read-only access to connection, agent count, usage stats)
- No changes to the serial protocol or companion bridge
- No changes to the renderer — LED is independent of display
- The `ledcSetup` channels (5/6/7) must not collide with TFT_eSPI's LEDC usage; TFT_eSPI backlight typically uses channel 0

## Ordering

1. Add constants to `config.h`
2. Create `led_ambient.h` and `led_ambient.cpp`
3. Wire into `main.cpp`
4. Build with `pio run -e cyd-2432s028r` to verify compilation

## Risks / Open Questions

1. **LEDC channel conflicts:** TFT_eSPI may claim LEDC channels for backlight PWM. Channels 5/6/7 should be safe (TFT_eSPI defaults to channel 0), but verify at build time. If there's a conflict, bump to channels 12/13/14.
2. **GPIO 16/17 on original ESP32:** These pins are connected to the internal flash/PSRAM on some ESP32 modules, but the CYD uses a standard ESP32-WROOM-32 where GPIO 16/17 are free. The CYD schematic confirms they drive the RGB LED. Still, worth a quick hardware test.
3. **LED brightness at night:** The RGB LED can be surprisingly bright in a dark room. Could add a global brightness scaler in the future (possibly reading the CYD's LDR on GPIO 34 for auto-dimming), but that's out of scope for this plan.
4. **Power draw:** Negligible — a single RGB LED at full duty draws <20mA total across three channels.
