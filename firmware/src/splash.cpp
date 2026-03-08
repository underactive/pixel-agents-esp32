#include "splash.h"
#include "sprites/characters.h"
#include <esp_random.h>

// Walk-down animation cycle: walk1, walk2(stand), walk3, walk2(stand)
static const int WALK_CYCLE[] = { TPL_DOWN_WALK1, TPL_DOWN_WALK2, TPL_DOWN_WALK3, TPL_DOWN_WALK2 };
static constexpr int WALK_CYCLE_LEN = 4;

void Splash::begin(TFT_eSPI& tft) {
    _tft = &tft;
    _charIdx = esp_random() % NUM_CHAR_SPRITES;
    _walkFrame = 0;
    _lastAnimMs = millis();
    _connected = false;
    _complete = false;
    _logCount = 0;

    _tft->fillScreen(TFT_BLACK);
    drawTitle();
    drawFooter();
    drawCharFrame();
}

void Splash::drawTitle() {
    _tft->setTextFont(1);
    _tft->setTextSize(3);
    _tft->setTextColor(TFT_WHITE, TFT_BLACK);
    _tft->setTextDatum(TC_DATUM);  // top-center
    _tft->drawString("PIXEL AGENTS", SCREEN_W / 2, SPLASH_TITLE_Y + _drawYOffset);
    _tft->setTextDatum(TL_DATUM);  // reset to top-left
}

void Splash::drawFooter() {
    _tft->setTextFont(1);
    _tft->setTextSize(1);
    _tft->setTextColor(COLOR_SPLASH_FOOTER, TFT_BLACK);
    _tft->setTextDatum(TC_DATUM);
    _tft->drawString(SPLASH_VERSION_STR, SCREEN_W / 2, SPLASH_FOOTER_Y + _drawYOffset);
    _tft->setTextDatum(TL_DATUM);
}

void Splash::clearCharArea() {
    int charW = CHAR_W * SPLASH_CHAR_SCALE;
    int charH = CHAR_H * SPLASH_CHAR_SCALE;
    int x = (SCREEN_W - charW) / 2;
    _tft->fillRect(x, SPLASH_CHAR_Y + _drawYOffset, charW, charH, TFT_BLACK);
}

void Splash::drawCharFrame() {
    int frameIdx = WALK_CYCLE[_walkFrame % WALK_CYCLE_LEN];
    const uint16_t* sprite = (const uint16_t*)pgm_read_ptr(&CHAR_SPRITES[_charIdx][frameIdx]);
    if (!sprite) return;

    int scaledW = CHAR_W * SPLASH_CHAR_SCALE;
    int startX = (SCREEN_W - scaledW) / 2;
    int startY = SPLASH_CHAR_Y + _drawYOffset;

    for (int py = 0; py < CHAR_H; py++) {
        for (int px = 0; px < CHAR_W; px++) {
            uint16_t color = pgm_read_word(&sprite[py * CHAR_W + px]);
            int sx = startX + px * SPLASH_CHAR_SCALE;
            int sy = startY + py * SPLASH_CHAR_SCALE;
            if (color != 0x0000) {
                _tft->fillRect(sx, sy, SPLASH_CHAR_SCALE, SPLASH_CHAR_SCALE, color);
            } else {
                _tft->fillRect(sx, sy, SPLASH_CHAR_SCALE, SPLASH_CHAR_SCALE, TFT_BLACK);
            }
        }
    }
}

void Splash::addLog(const char* msg) {
    if (_logCount < SPLASH_MAX_LOG_LINES) {
        snprintf(_logLines[_logCount], sizeof(_logLines[0]), "> %s", msg);
        _logCount++;
    } else {
        // Scroll: shift lines up, add new at bottom
        for (int i = 0; i < SPLASH_MAX_LOG_LINES - 1; i++) {
            memcpy(_logLines[i], _logLines[i + 1], sizeof(_logLines[0]));
        }
        snprintf(_logLines[SPLASH_MAX_LOG_LINES - 1], sizeof(_logLines[0]), "> %s", msg);
        // Redraw entire log area
        redrawLogArea();
        return;
    }

    // Draw just the new line
    int lineY = SPLASH_LOG_Y + (_logCount - 1) * SPLASH_LOG_LINE_H + _drawYOffset;
    _tft->setTextFont(1);
    _tft->setTextSize(1);
    _tft->setTextColor(COLOR_SPLASH_LOG, TFT_BLACK);
    _tft->setTextDatum(TL_DATUM);
    _tft->drawString(_logLines[_logCount - 1], 8, lineY);
}

void Splash::redrawLogArea() {
    // Clear log area
    int logAreaH = SPLASH_MAX_LOG_LINES * SPLASH_LOG_LINE_H;
    _tft->fillRect(0, SPLASH_LOG_Y + _drawYOffset, SCREEN_W, logAreaH, TFT_BLACK);

    _tft->setTextFont(1);
    _tft->setTextSize(1);
    _tft->setTextColor(COLOR_SPLASH_LOG, TFT_BLACK);
    _tft->setTextDatum(TL_DATUM);

    for (int i = 0; i < _logCount; i++) {
        int lineY = SPLASH_LOG_Y + i * SPLASH_LOG_LINE_H + _drawYOffset;
        _tft->drawString(_logLines[i], 8, lineY);
    }
}

void Splash::tick() {
    uint32_t now = millis();

    // Advance walk animation
    if (now - _lastAnimMs >= SPLASH_ANIM_FRAME_MS) {
        _lastAnimMs = now;
        _walkFrame = (_walkFrame + 1) % WALK_CYCLE_LEN;
        clearCharArea();
        drawCharFrame();
    }

    // Check 3s hold after connection
    if (_connected && !_complete) {
        if (now - _connectedMs >= (uint32_t)SPLASH_CONNECTED_HOLD_MS) {
            _complete = true;
        }
    }
}

void Splash::onHeartbeat() {
    if (_connected) return;  // only trigger once
    _connected = true;
    _connectedMs = millis();
    addLog("Connected!");
}

bool Splash::isActive() const {
    return !_complete;
}

void Splash::drawTo(TFT_eSPI* target, int yOffset) {
    TFT_eSPI* saved = _tft;
    _tft = target;
    _drawYOffset = yOffset;
    drawTitle();
    drawFooter();
    drawCharFrame();
    redrawLogArea();
    _drawYOffset = 0;
    _tft = saved;
}

// LEDC channel for backlight PWM fade (avoid CYD LED channels 5/6/7)
static constexpr int BL_LEDC_CH = 1;

void Splash::fadeOut(void (*stepCallback)()) {
#ifdef TFT_BL
    ledcSetup(BL_LEDC_CH, 5000, 8);
    ledcAttachPin(TFT_BL, BL_LEDC_CH);
    for (int i = 255; i >= 0; i -= 5) {
        ledcWrite(BL_LEDC_CH, i);
        delay(SPLASH_FADE_STEP_MS);
        if (stepCallback) stepCallback();
    }
    ledcWrite(BL_LEDC_CH, 0);
#endif
}

void Splash::fadeIn(void (*stepCallback)()) {
#ifdef TFT_BL
    for (int i = 0; i <= 255; i += 5) {
        ledcWrite(BL_LEDC_CH, i);
        delay(SPLASH_FADE_STEP_MS);
        if (stepCallback) stepCallback();
    }
    ledcWrite(BL_LEDC_CH, 255);
    // Revert to digital control
    ledcDetachPin(TFT_BL);
    pinMode(TFT_BL, OUTPUT);
    digitalWrite(TFT_BL, HIGH);
#endif
}
