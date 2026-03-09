#if defined(HAS_TOUCH)
#include "touch_input.h"
#include <Arduino.h>

void TouchInput::begin() {
    _touchSPI.begin(TOUCH_SPI_CLK, TOUCH_SPI_MISO, TOUCH_SPI_MOSI, TOUCH_SPI_CS);
    _ts.begin(_touchSPI);
    _ts.setRotation(1); // landscape, matching display
}

TouchEvent TouchInput::poll() {
    TouchEvent ev = {false, 0, 0};

    bool touched = _ts.touched();
    uint32_t now = millis();

    if (touched) {
        TS_Point p = _ts.getPoint();
        // Map raw ADC values (0-4095) to screen coordinates
        _lastTouchX = (int16_t)map(p.x, 200, 3800, 0, SCREEN_W);
        _lastTouchY = (int16_t)map(p.y, 200, 3800, 0, SCREEN_H);

        // Clamp to screen bounds
        if (_lastTouchX < 0) _lastTouchX = 0;
        if (_lastTouchX >= SCREEN_W) _lastTouchX = SCREEN_W - 1;
        if (_lastTouchY < 0) _lastTouchY = 0;
        if (_lastTouchY >= SCREEN_H) _lastTouchY = SCREEN_H - 1;
    }

    // Detect tap on release with debounce
    if (_wasTouched && !touched) {
        if (now - _lastTapMs >= TOUCH_DEBOUNCE_MS) {
            ev.tapped = true;
            ev.x = _lastTouchX;
            ev.y = _lastTouchY;
            _lastTapMs = now;
        }
    }

    _wasTouched = touched;
    return ev;
}

void TouchInput::setDisplayRotation(int rotation) {
    _ts.setRotation(rotation);
}
#endif
