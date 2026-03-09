#pragma once
#if defined(HAS_TOUCH)
#include <SPI.h>
#include <XPT2046_Touchscreen.h>
#include "config.h"

struct TouchEvent {
    bool tapped;
    int16_t x, y;
};

class TouchInput {
public:
    void begin();
    TouchEvent poll();
    void setDisplayRotation(int rotation);
private:
    SPIClass _touchSPI = SPIClass(VSPI);
    XPT2046_Touchscreen _ts = XPT2046_Touchscreen(TOUCH_SPI_CS, TOUCH_IRQ_PIN);
    uint32_t _lastTapMs = 0;
    bool _wasTouched = false;
    int16_t _lastTouchX = 0;
    int16_t _lastTouchY = 0;
};
#endif
