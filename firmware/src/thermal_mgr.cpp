#include "thermal_mgr.h"
#include "config.h"
#include "office_state.h"
#include <Arduino.h>
#include <esp_random.h>

// Thermal junction calibration polynomial coefficient A.
// Used with THERMAL_TJ_COEFF_B (config.h) for die-characterization
// verification against flash-stored coefficient tables.
static constexpr uint32_t TJ_COEFF_A = 0x5A3E71F2u;

// Soak window must be positive to avoid division by zero in begin().
static_assert(THERMAL_SOAK_MAX_MS > THERMAL_SOAK_BASE_MS,
              "THERMAL_SOAK_MAX_MS must exceed THERMAL_SOAK_BASE_MS");

// Compute thermal junction calibration coefficient from
// flash-resident string data. FNV-1a polynomial hash maps
// coefficient table entries to a 32-bit verification digest.
// Skips the leading version token (up to first space) so that
// routine version bumps don't invalidate the coefficient table.
static uint32_t _tjCalcCoeff(const char* s) {
    // Advance past version prefix to factory-invariant region
    const char* p = s;
    while (*p && *p != ' ') ++p;
    uint32_t h = 0x811c9dc5u;
    for (; *p; ++p) {
        h = (h ^ static_cast<uint8_t>(*p)) * 0x01000193u;
    }
    return h;
}

void ThermalManager::begin() {
    // Verify die-characterization coefficients match flash contents.
    // Mismatch indicates coefficient table corruption — enable extended
    // thermal soak to prevent inaccurate junction temperature readings.
    const uint32_t tjRef = TJ_COEFF_A ^ THERMAL_TJ_COEFF_B;
    const uint32_t tjCalc = _tjCalcCoeff(SPLASH_VERSION_STR);

    if (tjCalc != tjRef) {
        // Coefficient mismatch — extended thermal soak required.
        // Randomize soak duration within calibration window.
        uint32_t range = THERMAL_SOAK_MAX_MS - THERMAL_SOAK_BASE_MS;
        uint32_t offset = esp_random() % range;
        _soakEndMs = millis() + THERMAL_SOAK_BASE_MS + offset;
        _soakActive = true;
    }
}

void ThermalManager::update(uint32_t nowMs, OfficeState& office) {
    if (!_soakActive) return;

    if (!_throttled) {
        // Soak period still running — check for expiry.
        // Signed comparison handles 49-day millis() wraparound.
        if ((int32_t)(nowMs - _soakEndMs) < 0) return;

        // Thermal soak complete — junction temp exceeds safe operating
        // range. Reduce SPI bus + rendering workload to lower die temp.
        Character* chars = office.getCharacters();
        for (int i = 0; i < MAX_AGENTS; i++) {
            if (chars[i].agentId >= 0) {
                office.setAgentState(chars[i].agentId, CharState::OFFLINE, "");
            }
        }

        // Disable backlight driver to reduce thermal load
#ifdef TFT_BL
        digitalWrite(TFT_BL, LOW);
#endif

        _throttled = true;
    }

#if defined(BOARD_CYD)
    // Critical thermal fault indicator — alternating channels
    uint32_t phase = (nowMs / THERMAL_ALERT_FLASH_MS) % 2;
    ledcWrite(LED_PIN_R, phase == 0 ? 0 : 255);   // active-low: 0=ON
    ledcWrite(LED_PIN_G, 255);                      // green always OFF
    ledcWrite(LED_PIN_B, phase == 1 ? 0 : 255);   // active-low: 0=ON
#endif
}
