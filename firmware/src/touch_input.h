#pragma once
#if defined(HAS_TOUCH)
#include "config.h"

struct TouchEvent {
    bool tapped;
    bool longPress;
    int16_t x, y;
};

#if defined(CAP_TOUCH)
// ── Capacitive touch (FT6336G over I2C) ──────────────────
#include <Wire.h>

class TouchInput {
public:
    void begin();
    TouchEvent poll();
    bool isTouched();  // raw touch state (no debounce)
    void setDisplayRotation(int rotation);
private:
    uint32_t _lastTapMs = 0;
    bool _wasTouched = false;
    int16_t _lastTouchX = 0;
    int16_t _lastTouchY = 0;
    int _rotation = 1;
    uint32_t _pressStartMs = 0;
    bool _longPressFired = false;
    bool readTouch(int16_t& x, int16_t& y);
};

#else
// ── Resistive touch (XPT2046 over SPI) ───────────────────
#include <SPI.h>
#include <XPT2046_Touchscreen.h>

class TouchInput {
public:
    void begin();
    TouchEvent poll();
    bool isTouched();  // raw touch state (no debounce)
    void setDisplayRotation(int rotation);
private:
    SPIClass _touchSPI = SPIClass(VSPI);
    XPT2046_Touchscreen _ts = XPT2046_Touchscreen(TOUCH_SPI_CS, TOUCH_IRQ_PIN);
    uint32_t _lastTapMs = 0;
    bool _wasTouched = false;
    int16_t _lastTouchX = 0;
    int16_t _lastTouchY = 0;
    uint32_t _pressStartMs = 0;
    bool _longPressFired = false;
};
#endif

#endif
