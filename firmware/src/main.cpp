#include <Arduino.h>
#include <TFT_eSPI.h>
#include "config.h"
#include "protocol.h"
#include "office_state.h"
#include "renderer.h"

TFT_eSPI tft;
Protocol protocol;
OfficeState office;
Renderer renderer;

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
    tft.setRotation(1); // Landscape: 320x170
    tft.fillScreen(TFT_BLACK);

    // Backlight
    pinMode(TFT_BL, OUTPUT);
    digitalWrite(TFT_BL, HIGH);

    // Show splash
    drawSplash();

    // Initialize subsystems
    office.init();
    renderer.begin(tft);
    protocol.begin(onAgentUpdate, onAgentCount, onHeartbeat, onStatusText);

    lastFrameMs = millis();

    // Seed random
    randomSeed(analogRead(0) ^ millis());
}

// ── Main loop ───────────────────────────────────────────

void loop() {
    uint32_t now = millis();

    // Process serial (non-blocking)
    protocol.process();

    // Check heartbeat
    office.checkHeartbeat(now);

    // Frame rate limiting
    if (now - lastFrameMs < FRAME_MS) return;

    float dt = (now - lastFrameMs) / 1000.0f;
    if (dt > 0.1f) dt = 0.1f; // cap delta time
    lastFrameMs = now;

    // Update office state
    office.update(dt);

    // Render
    renderer.renderFrame(office);
}
