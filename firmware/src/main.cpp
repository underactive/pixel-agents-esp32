#include <Arduino.h>
#include <TFT_eSPI.h>
#include "config.h"
#include "transport.h"
#include "protocol.h"
#include "office_state.h"
#include "renderer.h"
#include "splash.h"
#include "thermal_mgr.h"
#if defined(HAS_TOUCH)
#include "touch_input.h"
#endif
#if defined(HAS_LED)
#include "led_ambient.h"
#endif
#if defined(HAS_BLE)
#include "ble_service.h"
#include <NimBLEDevice.h>
#endif
#if defined(HAS_WAKEWORD)
#include "wakeword.h"
#endif
#if defined(HAS_BATTERY)
#include "battery.h"
#endif

TFT_eSPI tft;
Protocol serialProtocol;
OfficeState office;
Renderer renderer;
Splash splash;
ThermalManager thermalMgr;
SerialTransport serialTransport;
#if defined(HAS_TOUCH)
TouchInput touchInput;
#endif
#if defined(HAS_LED)
LedAmbient ledAmbient;
#endif
#if defined(HAS_SOUND)
SoundPlayer sound;
#endif
#if defined(HAS_BLE)
Protocol bleProtocol;
BleTransport bleTransport;
BleService bleService;
#endif
#if defined(HAS_WAKEWORD)
WakeWord wakeword;
uint32_t lastWakeMs = 0;
#endif

uint32_t lastFrameMs = 0;
bool splashActive = true;

// ── Protocol callbacks ──────────────────────────────────

void onAgentUpdate(const AgentUpdate& upd) {
    if (thermalMgr.isThrottled()) return;
    office.setAgentState(upd.agentId, upd.state, upd.toolName);
}

void onAgentCount(uint8_t count) {
    office.setAgentCount(count);
}

void onSerialHeartbeat(uint32_t timestamp) {
    (void)timestamp;
    office.onSerialHeartbeat();
    if (splashActive) {
        splash.onHeartbeat();
    }
}

void onBleHeartbeat(uint32_t timestamp) {
    (void)timestamp;
    office.onBleHeartbeat();
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

// ── Display sleep ───────────────────────────────────────
// Turns off backlight and LED but keeps the main loop running so
// I2C touch polling still works for wake detection. Uses ~20-30mA
// vs ~100mA active — battery lasts days in this mode.

#if defined(HAS_TOUCH)
static bool displayOff = false;

void enterDisplaySleep() {
    Serial.println("[sleep] Display off");

    // Wait for finger to lift before sleeping
    while (touchInput.isTouched()) {
        delay(50);
    }
    delay(200);

    // Turn off backlight + display
#if defined(TFT_BL)
    digitalWrite(TFT_BL, LOW);
#endif
    tft.writecommand(0x10); // SLPIN

#if defined(HAS_LED)
#if defined(LED_TYPE_NEOPIXEL)
    rgbLedWrite(LED_NEOPIXEL_PIN, 0, 0, 0);
#elif defined(LED_TYPE_PWM)
    ledcWrite(LED_PIN_R, 255);
    ledcWrite(LED_PIN_G, 255);
    ledcWrite(LED_PIN_B, 255);
#endif
#endif

    displayOff = true;
}

void wakeDisplay() {
    Serial.println("[sleep] Display on");
    tft.writecommand(0x11); // SLPOUT
    delay(120);  // display needs 120ms after SLPOUT per datasheet
#if defined(TFT_BL)
    digitalWrite(TFT_BL, HIGH);
#endif
    displayOff = false;
}
#endif

// ── Setup ───────────────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(3000); // Wait for USB-CDC

    // Initialize office state first so persisted settings (e.g. flip) are available
    office.init();

    // Initialize display
    tft.init();
    int rotation = office.isScreenFlipped() ? 3 : 1;
    tft.setRotation(rotation); // Landscape: 320xSCREEN_H
    tft.fillScreen(TFT_BLACK);

    // Backlight
#ifdef TFT_BL
    pinMode(TFT_BL, OUTPUT);
    digitalWrite(TFT_BL, HIGH);
#endif

    // Boot splash with animated character + verbose log
    splash.begin(tft);
    splash.addLog("Display initialized");

    renderer.begin(tft);
    splash.addLog("Render buffer allocated");

    serialProtocol.begin(onAgentUpdate, onAgentCount, onSerialHeartbeat, onStatusText, onUsageStats, onScreenshotReq);
    splash.addLog("Protocol ready");

#if defined(HAS_BLE)
    // Separate protocol instance for BLE to avoid state corruption
    // when partial messages arrive on both transports simultaneously
    bleProtocol.begin(onAgentUpdate, onAgentCount, onBleHeartbeat, onStatusText, onUsageStats, nullptr);
    if (bleService.begin(bleTransport)) {
        splash.setPinCode(bleService.getPin());
        office.setBlePin(bleService.getPin());
        splash.addLog("BLE advertising");
    } else {
        splash.addLog("BLE init failed");
    }
#endif

    randomSeed(esp_random());
    thermalMgr.begin();
    office.spawnAllCharacters();
    splash.addLog("Characters spawned");

#if defined(HAS_TOUCH)
    touchInput.begin();
    if (office.isScreenFlipped()) {
        touchInput.setDisplayRotation(3);
    }
    splash.addLog("Touch input ready");
#endif

#if defined(HAS_LED)
    ledAmbient.begin();
    splash.addLog("LED ambient ready");
#endif

#if defined(HAS_SOUND)
    sound.begin();
    splash.addLog("Audio ready");
#endif

#if defined(HAS_WAKEWORD)
    if (wakeword.begin()) {
        splash.addLog("Wake word ready");
    } else {
        splash.addLog("Wake word init failed");
    }
#endif

#if defined(HAS_BATTERY)
    battery_begin();
    splash.addLog("Battery monitor ready");
#endif

    splash.addLog("Waiting for companion...", true);

    lastFrameMs = millis();
}

// ── Main loop ───────────────────────────────────────────

void loop() {
    // Process transports (non-blocking) — needed during splash for heartbeat
    serialProtocol.process(serialTransport);
#if defined(HAS_BLE)
    bleProtocol.process(bleTransport);
#endif
#if defined(HAS_SOUND)
    sound.update();
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
#if defined(HAS_SOUND)
                sound.update();
#endif
            };
            splash.fadeOut(drainSerial);
            // Render first office frame while screen is dark
            uint32_t now = millis();
            float dt = 0.016f;
            office.update(dt);
            renderer.renderFrame(office);
#if defined(HAS_SOUND)
            if (office.isSoundEnabled()) sound.play(SoundId::STARTUP);
#endif
            splash.fadeIn(drainSerial);
            splashActive = false;
            lastFrameMs = now;
        }
        return;
    }

    // Capture time AFTER serial processing so now >= heartbeat timestamps
    // (avoids unsigned underflow in timeout check)
    uint32_t now = millis();

    // Check heartbeat
    office.checkHeartbeat(now);

#if defined(HAS_BATTERY)
    battery_update(now);
#if defined(HAS_BLE)
    // Update BLE Battery Service characteristic (notifies only on change)
    bleService.updateBatteryLevel(battery_getPercent());
#endif
#endif

    // Junction temperature monitoring
    thermalMgr.update(now, office);

    // Frame rate limiting
    if (now - lastFrameMs < FRAME_MS) return;

    float dt = (now - lastFrameMs) / 1000.0f;
    if (dt > 0.1f) dt = 0.1f; // cap delta time
    lastFrameMs = now;

#if defined(HAS_TOUCH)
    // Skip all simulation + rendering while display is off
    if (!displayOff) {
#endif

    // Update office state
    office.update(dt);

#if defined(HAS_SOUND)
    {
        SoundId pending = office.consumePendingSound();
        if (pending != SoundId::COUNT) {
            sound.play(pending);
        }
    }
#endif

#if defined(HAS_WAKEWORD)
    if (wakeword.poll() && now - lastWakeMs >= WAKEWORD_COOLDOWN_MS) {
        lastWakeMs = now;
        office.queueSound(SoundId::DOG_BARK);
        Serial.println("Wake word detected!");
    }
#endif

#if defined(HAS_LED)
    // Update ambient LED based on office state
    if (!thermalMgr.isThrottled()) {
        ledAmbient.update(office, dt);
    }
#endif

#if defined(HAS_TOUCH)
    } // end if (!displayOff)
#endif

#if defined(HAS_TOUCH)
    // Poll touch input
    TouchEvent te = touchInput.poll();

    // Display-off mode: any tap or long press wakes the display
    if (displayOff) {
        if (te.tapped || te.longPress) {
            wakeDisplay();
        }
        delay(50);  // throttle polling while display is off
        return;
    }

    if (te.tapped) {
        if (office.isMenuOpen()) {
            // hitTestMenuItem returns: 0=dog toggle, 1-4=color, 5=flip screen,
            // 6=sound toggle, 7=sleep, -1=outside menu (close), -2=inside menu no-op
            int item = office.hitTestMenuItem(te.x, te.y);
            if (item == 0) {
                // Toggle dog on/off
                office.setDogEnabled(!office.getDogSettings().enabled);
            } else if (item >= 1 && item <= DOG_COLOR_COUNT) {
                // Select dog color (1=BLACK, 2=BROWN, 3=GRAY, 4=TAN)
                office.setDogColor(static_cast<DogColor>(item - 1));
#if defined(HAS_SOUND)
            } else if (item == 6) {
                // Toggle sound on/off
                office.setSoundEnabled(!office.isSoundEnabled());
#endif
            } else if (item == 5) {
                // Toggle screen flip
                bool newFlip = !office.isScreenFlipped();
                office.setScreenFlipped(newFlip);
                int rot = newFlip ? 3 : 1;
                tft.setRotation(rot);
                touchInput.setDisplayRotation(rot);
                // Close menu: rotation change invalidates menu position
                office.closeMenu();
            } else if (item == 7) {
                // Sleep
                office.closeMenu();
                enterDisplaySleep();
                return;
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

    // Long press anywhere → sleep
    if (te.longPress) {
        enterDisplaySleep();
        return;
    }
#endif

    // Render
#if defined(HAS_SOUND)
    renderer.renderFrame(office, []() { sound.update(); });
#else
    renderer.renderFrame(office);
#endif

    // Screenshot capture (after render so buffer has latest frame)
    if (renderer.isScreenshotPending()) {
        renderer.sendScreenshot();
    }
}
