#pragma once
#if defined(HAS_TOUCH)
#include <TFT_eSPI.h>
#include "config.h"

struct TouchEvent {
    bool tapped;
    int16_t x, y;
};

class TouchInput {
public:
    void begin(TFT_eSPI& tft);
    TouchEvent poll();
private:
    TFT_eSPI* _tft = nullptr;
    uint32_t _lastTapMs = 0;
    bool _wasTouched = false;
    uint16_t _calData[5] = {300, 3600, 300, 3600, 1};
};
#endif
