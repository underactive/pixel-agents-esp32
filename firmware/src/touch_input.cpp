#if defined(HAS_TOUCH)
#include "touch_input.h"
#include <Arduino.h>

void TouchInput::begin(TFT_eSPI& tft) {
    _tft = &tft;
    _tft->setTouch(_calData);
}

TouchEvent TouchInput::poll() {
    TouchEvent ev = {false, 0, 0};
    if (!_tft) return ev;

    uint16_t tx, ty;
    bool touched = _tft->getTouch(&tx, &ty);

    uint32_t now = millis();

    // Detect tap on release with debounce
    if (_wasTouched && !touched) {
        if (now - _lastTapMs >= TOUCH_DEBOUNCE_MS) {
            ev.tapped = true;
            ev.x = (int16_t)tx;
            ev.y = (int16_t)ty;
            _lastTapMs = now;
        }
    }

    _wasTouched = touched;
    return ev;
}
#endif
