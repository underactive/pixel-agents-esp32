#include <Arduino.h>
#include <TFT_eSPI.h>
#include "config.h"
#include "protocol.h"
#include "office_state.h"
#include "renderer.h"
#if defined(HAS_TOUCH)
#include "touch_input.h"
#endif

TFT_eSPI tft;
Protocol protocol;
OfficeState office;
Renderer renderer;
#if defined(HAS_TOUCH)
TouchInput touchInput;
#endif

uint32_t lastFrameMs = 0;

// ── Protocol callbacks ──────────────────────────────────

void onAgentUpdate(const AgentUpdate& upd) {
    office.setAgentState(upd.agentId, upd.state, upd.toolName);
}

void onAgentCount(uint8_t count) {
    office.setAgentCount(count);
}

void onHeartbeat(uint32_t timestamp) {
    office.onHeartbeat();
}

void onStatusText(const StatusText& st) {
    // Could display status text in future
}

// ── Splash screen ───────────────────────────────────────

void drawSplash() {
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(2);
    tft.drawString("Pixel Agents", 80, 60);
    tft.setTextSize(1);
    tft.drawString("Waiting for connection...", 70, 100);
    tft.drawString("Connect companion script via USB", 40, 120);
}

// ── Setup ───────────────────────────────────────────────

void setup() {
    Serial.begin(115200);

    // Initialize display
    tft.init();
    tft.setRotation(1); // Landscape: 320xSCREEN_H
    tft.fillScreen(TFT_BLACK);

    // Backlight
#ifdef TFT_BL
    pinMode(TFT_BL, OUTPUT);
    digitalWrite(TFT_BL, HIGH);
#endif

    // Show splash
    drawSplash();

    // Initialize subsystems
    office.init();
    renderer.begin(tft);
    protocol.begin(onAgentUpdate, onAgentCount, onHeartbeat, onStatusText);

#if defined(HAS_TOUCH)
    touchInput.begin();
#endif

    lastFrameMs = millis();

    // Seed random
    randomSeed(analogRead(0) ^ millis());
}

// ── Main loop ───────────────────────────────────────────

void loop() {
    // Process serial (non-blocking)
    protocol.process();

    // Capture time AFTER serial processing so now >= _lastHeartbeatMs
    // (avoids unsigned underflow in timeout check)
    uint32_t now = millis();

    // Check heartbeat
    office.checkHeartbeat(now);

    // Frame rate limiting
    if (now - lastFrameMs < FRAME_MS) return;

    float dt = (now - lastFrameMs) / 1000.0f;
    if (dt > 0.1f) dt = 0.1f; // cap delta time
    lastFrameMs = now;

    // Update office state
    office.update(dt);

#if defined(HAS_TOUCH)
    // Poll touch input
    TouchEvent te = touchInput.poll();
    if (te.tapped) {
        if (office.hitTestStatusBar(te.y)) {
            office.cycleStatusMode();
        } else {
            int hit = office.hitTestCharacter(te.x, te.y);
            if (hit >= 0) {
                office.showInfoBubble(hit);
            }
        }
    }
#endif

    // Render
    renderer.renderFrame(office);
}
