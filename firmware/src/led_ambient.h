#pragma once
#if defined(BOARD_CYD)

#include "config.h"

class OfficeState;  // forward declaration

class LedAmbient {
public:
    void begin();
    void update(const OfficeState& office, float dt);

private:
    LedMode _mode = LedMode::OFF;
    float _phase = 0.0f;           // accumulated time for animation

    void setRGB(uint8_t r, uint8_t g, uint8_t b);
    LedMode resolveMode(const OfficeState& office) const;
    // Returns 0-255 brightness following a sine curve over the given period (seconds)
    uint8_t breathe(float period) const;
};

#endif
