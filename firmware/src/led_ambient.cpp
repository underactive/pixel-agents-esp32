#if defined(BOARD_CYD)
#include "led_ambient.h"
#include "office_state.h"
#include <Arduino.h>

// 32-entry sine LUT: full period (0 -> peak -> 0 -> peak -> 0)
// Two identical half-waves so (idx & 31) wraps naturally into a complete cycle
static const uint8_t SINE_LUT[32] PROGMEM = {
      0,  25,  71, 128, 185, 231, 255, 255,
    231, 185, 128,  71,  25,   0,   0,   0,
      0,  25,  71, 128, 185, 231, 255, 255,
    231, 185, 128,  71,  25,   0,   0,   0
};

void LedAmbient::begin() {
    ledcAttach(LED_PIN_R, LED_PWM_FREQ, LED_PWM_RES);
    ledcAttach(LED_PIN_G, LED_PWM_FREQ, LED_PWM_RES);
    ledcAttach(LED_PIN_B, LED_PWM_FREQ, LED_PWM_RES);
    setRGB(0, 0, 0);
}

void LedAmbient::setRGB(uint8_t r, uint8_t g, uint8_t b) {
    // Active-LOW: 255 - value inverts for common-anode LED
    ledcWrite(LED_PIN_R, 255 - r);
    ledcWrite(LED_PIN_G, 255 - g);
    ledcWrite(LED_PIN_B, 255 - b);
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
    int idx = (int)(pos * 16) & 15;           // 16-entry half-wave
    return pgm_read_byte(&SINE_LUT[idx]);
}

void LedAmbient::update(const OfficeState& office, float dt) {
    LedMode newMode = resolveMode(office);
    if (newMode != _mode) {
        _mode = newMode;
        _phase = 0.0f;
    }
    _phase += dt;
    // Wrap phase to prevent float precision loss on long uptimes
    if (_phase > 1000.0f) _phase -= 1000.0f;

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
            // Scale brightness by agent count (1 agent=min, up to max)
            int step = (LED_ACTIVE_MAX_BRIGHT - LED_ACTIVE_MIN_BRIGHT) / (LED_BUSY_THRESHOLD - 1);
            int bright = LED_ACTIVE_MIN_BRIGHT + (active - 1) * step;
            if (bright > LED_ACTIVE_MAX_BRIGHT) bright = LED_ACTIVE_MAX_BRIGHT;
            setRGB(0, (uint8_t)bright, 0);   // green
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

        default:
            setRGB(0, 0, 0);
            break;
    }
}

#endif
