#if defined(HAS_TOUCH)
#include "touch_input.h"
#include <Arduino.h>

#if defined(CAP_TOUCH)
// ── Capacitive touch (FT6336G over I2C) ──────────────────

void TouchInput::begin() {
    if (CAP_TOUCH_PIN_RST >= 0) {
        pinMode(CAP_TOUCH_PIN_RST, OUTPUT);
        digitalWrite(CAP_TOUCH_PIN_RST, LOW);
        delay(10);
        digitalWrite(CAP_TOUCH_PIN_RST, HIGH);
        delay(50);
    }
    Wire.begin(CAP_TOUCH_PIN_SDA, CAP_TOUCH_PIN_SCL);
    _rotation = 1;
}

bool TouchInput::readTouch(int16_t& x, int16_t& y) {
    Wire.beginTransmission(CAP_TOUCH_ADDR);
    Wire.write(0x02);  // touch status register
    if (Wire.endTransmission(false) != 0) return false;

    Wire.requestFrom((uint8_t)CAP_TOUCH_ADDR, (uint8_t)5);
    if (Wire.available() < 5) return false;

    uint8_t touchCount = Wire.read() & 0x0F;
    if (touchCount == 0) return false;

    uint8_t xHi = Wire.read() & 0x0F;
    uint8_t xLo = Wire.read();
    uint8_t yHi = Wire.read() & 0x0F;
    uint8_t yLo = Wire.read();

    // Raw coordinates in panel's native portrait orientation (240x320)
    int16_t rawX = (xHi << 8) | xLo;
    int16_t rawY = (yHi << 8) | yLo;

    // Transform to landscape display coordinates based on rotation
    if (_rotation == 1) {
        // Landscape: display X = rawY, display Y = (240 - 1) - rawX
        x = rawY;
        y = (TFT_WIDTH - 1) - rawX;
    } else if (_rotation == 3) {
        // Landscape flipped: display X = (320 - 1) - rawY, display Y = rawX
        x = (TFT_HEIGHT - 1) - rawY;
        y = rawX;
    } else {
        x = rawX;
        y = rawY;
    }

    // Clamp to screen bounds
    if (x < 0) x = 0;
    if (x >= SCREEN_W) x = SCREEN_W - 1;
    if (y < 0) y = 0;
    if (y >= SCREEN_H) y = SCREEN_H - 1;

    return true;
}

TouchEvent TouchInput::poll() {
    TouchEvent ev = {false, 0, 0};

    int16_t tx, ty;
    bool touched = readTouch(tx, ty);
    uint32_t now = millis();

    if (touched) {
        _lastTouchX = tx;
        _lastTouchY = ty;
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
    _rotation = rotation;
}

#else
// ── Resistive touch (XPT2046 over SPI) ───────────────────

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

#endif
