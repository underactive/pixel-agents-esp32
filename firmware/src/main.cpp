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
    (void)timestamp;
    office.onHeartbeat();
}

void onStatusText(const StatusText& st) {
    // Could display status text in future
}

void onUsageStats(const UsageStatsMsg& us) {
    office.setUsageStats(us.currentPct, us.weeklyPct, us.currentResetMin, us.weeklyResetMin);
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
    protocol.begin(onAgentUpdate, onAgentCount, onHeartbeat, onStatusText, onUsageStats);

    // Seed random before spawning characters
    randomSeed(analogRead(0) ^ millis());

    // Spawn all 6 characters in social zones
    office.spawnAllCharacters();

#if defined(HAS_TOUCH)
    touchInput.begin();
#endif

    lastFrameMs = millis();
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
        if (office.isMenuOpen()) {
            // hitTestMenuItem returns: 0=dog toggle, 1-4=color,
            // -1=outside menu (close), -2=inside menu no-op (keep open)
            int item = office.hitTestMenuItem(te.x, te.y);
            if (item == 0) {
                // Toggle dog on/off
                office.setDogEnabled(!office.getDogSettings().enabled);
            } else if (item >= 1 && item <= DOG_COLOR_COUNT) {
                // Select dog color (1=BLACK, 2=BROWN, 3=GRAY, 4=TAN)
                office.setDogColor(static_cast<DogColor>(item - 1));
            } else if (item == -1) {
                // Tap outside menu -> close menu
                office.closeMenu();
            }
            // item == -2: inside menu but not on actionable item, keep open
        } else if (office.hitTestHamburger(te.x, te.y)) {
            office.toggleMenu();
        } else if (office.hitTestStatusBar(te.y)) {
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
