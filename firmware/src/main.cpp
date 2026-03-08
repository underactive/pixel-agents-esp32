#include <Arduino.h>
#include <TFT_eSPI.h>
#include "config.h"
#include "transport.h"
#include "protocol.h"
#include "office_state.h"
#include "renderer.h"
#include "splash.h"
#if defined(HAS_TOUCH)
#include "touch_input.h"
#endif
#if defined(BOARD_CYD)
#include "led_ambient.h"
#endif
#if defined(HAS_BLE)
#include "ble_service.h"
#endif

TFT_eSPI tft;
Protocol serialProtocol;
OfficeState office;
Renderer renderer;
Splash splash;
SerialTransport serialTransport;
#if defined(HAS_TOUCH)
TouchInput touchInput;
#endif
#if defined(BOARD_CYD)
LedAmbient ledAmbient;
#endif
#if defined(HAS_BLE)
Protocol bleProtocol;
BleTransport bleTransport;
BleService bleService;
#endif

uint32_t lastFrameMs = 0;
bool splashActive = true;

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
    if (splashActive) {
        splash.onHeartbeat();
    }
}

void onStatusText(const StatusText& st) {
    // Could display status text in future
}

void onUsageStats(const UsageStatsMsg& us) {
    office.setUsageStats(us.currentPct, us.weeklyPct, us.currentResetMin, us.weeklyResetMin);
}

void onScreenshotReq() {
    renderer.requestScreenshot();
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

    // Boot splash with animated character + verbose log
    splash.begin(tft);
    splash.addLog("Display initialized");

    office.init();
    splash.addLog("Office state ready");

    renderer.begin(tft);
    splash.addLog("Render buffer allocated");

    serialProtocol.begin(onAgentUpdate, onAgentCount, onHeartbeat, onStatusText, onUsageStats, onScreenshotReq);
    splash.addLog("Protocol ready");

#if defined(HAS_BLE)
    // Separate protocol instance for BLE to avoid state corruption
    // when partial messages arrive on both transports simultaneously
    bleProtocol.begin(onAgentUpdate, onAgentCount, onHeartbeat, onStatusText, onUsageStats, nullptr);
    bleService.begin(bleTransport);
    splash.addLog("BLE advertising");
#endif

    randomSeed(analogRead(0) ^ millis());
    office.spawnAllCharacters();
    splash.addLog("Characters spawned");

#if defined(HAS_TOUCH)
    touchInput.begin();
    splash.addLog("Touch input ready");
#endif

#if defined(BOARD_CYD)
    ledAmbient.begin();
    splash.addLog("LED ambient ready");
#endif

    splash.addLog("Waiting for companion...");

    lastFrameMs = millis();
}

// ── Main loop ───────────────────────────────────────────

void loop() {
    // Process transports (non-blocking) — needed during splash for heartbeat
    serialProtocol.process(serialTransport);
#if defined(HAS_BLE)
    bleProtocol.process(bleTransport);
#endif

    // Splash screen mode: animate character + wait for connection
    if (splashActive) {
        splash.tick();
        // Handle screenshot requests during splash
        if (renderer.isScreenshotPending()) {
            renderer.sendSplashScreenshot(splash);
        }
        if (!splash.isActive()) {
            // Drain serial buffer during blocking fade to prevent UART overflow
            auto drainSerial = []() {
                serialProtocol.process(serialTransport);
#if defined(HAS_BLE)
                bleProtocol.process(bleTransport);
#endif
            };
            splash.fadeOut(drainSerial);
            // Render first office frame while screen is dark
            uint32_t now = millis();
            float dt = 0.016f;
            office.update(dt);
            renderer.renderFrame(office);
            splash.fadeIn(drainSerial);
            splashActive = false;
            lastFrameMs = now;
        }
        return;
    }

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

#if defined(BOARD_CYD)
    // Update ambient LED based on office state
    ledAmbient.update(office, dt);
#endif

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

    // Screenshot capture (after render so buffer has latest frame)
    if (renderer.isScreenshotPending()) {
        renderer.sendScreenshot();
    }
}
