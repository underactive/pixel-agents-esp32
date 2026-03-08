#pragma once
#include <TFT_eSPI.h>
#include "config.h"

class Splash {
public:
    void begin(TFT_eSPI& tft);
    void addLog(const char* msg);
    void tick();
    void onHeartbeat();
    bool isActive() const;
    void fadeOut(void (*stepCallback)() = nullptr);
    void fadeIn(void (*stepCallback)() = nullptr);

private:
    void drawTitle();
    void drawFooter();
    void drawCharFrame();
    void clearCharArea();
    void redrawLogArea();

    TFT_eSPI* _tft = nullptr;
    int _charIdx = 0;              // which of 6 characters
    int _walkFrame = 0;            // index into walk cycle [0,1,2,1]
    uint32_t _lastAnimMs = 0;
    bool _connected = false;
    uint32_t _connectedMs = 0;     // millis() when connected
    bool _complete = false;

    // Log line circular buffer
    char _logLines[SPLASH_MAX_LOG_LINES][40];
    int _logCount = 0;
};
