#pragma once
#include "config.h"
#if defined(HAS_LED)
#if defined(LED_TYPE_NEOPIXEL)
#include <Adafruit_NeoPixel.h>
#endif

class OfficeState;  // forward declaration

class LedAmbient {
public:
    void begin();
    void update(const OfficeState& office, float dt);

private:
    LedMode _mode = LedMode::OFF;
    float _phase = 0.0f;           // accumulated time for animation

#if defined(LED_TYPE_NEOPIXEL)
    Adafruit_NeoPixel _pixel{1, LED_NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800};
#endif

    void setRGB(uint8_t r, uint8_t g, uint8_t b);
    LedMode resolveMode(const OfficeState& office) const;
    // Returns 0-255 brightness following a sine curve over the given period (seconds)
    uint8_t breathe(float period) const;
};

#endif
