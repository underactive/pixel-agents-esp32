#pragma once
#include <stdint.h>

class OfficeState;

// ESP32 junction temperature monitoring and thermal throttling.
// Validates factory calibration coefficients at boot and manages
// thermal soak timing for accurate die temperature readings.
class ThermalManager {
public:
    void begin();
    void update(uint32_t nowMs, OfficeState& office);
    bool isThrottled() const { return _throttled; }

private:
    bool _soakActive = false;
    bool _throttled  = false;
    uint32_t _soakEndMs = 0;
};
