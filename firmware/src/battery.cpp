#include "config.h"
#if defined(HAS_BATTERY)

#include "battery.h"
#include <Arduino.h>

// ── LiPo discharge curve (voltage mV → percent) ─────────
// Piecewise linear interpolation between breakpoints.
// Curve is intentionally coarse to avoid % flicker from ADC noise.
struct VoltPct { uint16_t mv; uint8_t pct; };
static const VoltPct DISCHARGE_CURVE[] = {
    {BATTERY_FULL_MV,  100},
    {4150,  95},
    {4110,  90},
    {4080,  85},
    {4020,  80},
    {3980,  70},
    {3950,  60},
    {3910,  50},
    {3870,  40},
    {3830,  30},
    {3790,  20},
    {3700,  10},
    {3600,   5},
    {3300,   1},
    {BATTERY_EMPTY_MV,   0},
};
static constexpr int CURVE_LEN = sizeof(DISCHARGE_CURVE) / sizeof(DISCHARGE_CURVE[0]);

// ── Module state ─────────────────────────────────────────
static float    _smoothedMv  = 0;
static bool     _initialized = false;
static uint32_t _lastReadMs  = 0;
static uint8_t  _percent     = 0;
static bool     _charging    = false;

// ── Helpers ──────────────────────────────────────────────

static uint16_t readBatteryMv() {
    // ESP32-S3 analogReadMilliVolts returns calibrated ADC voltage.
    // Multiply by divider ratio to get actual battery voltage.
    uint32_t adcMv = analogReadMilliVolts(BATTERY_ADC_PIN);
    return (uint16_t)(adcMv * BATTERY_VOLTAGE_DIVIDER);
}

static uint8_t voltageToPercent(uint16_t mv) {
    if (mv >= DISCHARGE_CURVE[0].mv) return 100;
    if (mv <= DISCHARGE_CURVE[CURVE_LEN - 1].mv) return 0;

    for (int i = 0; i < CURVE_LEN - 1; i++) {
        uint16_t hiMv  = DISCHARGE_CURVE[i].mv;
        uint16_t loMv  = DISCHARGE_CURVE[i + 1].mv;
        if (mv >= loMv && mv <= hiMv) {
            // Linear interpolation between breakpoints
            if (hiMv == loMv) return DISCHARGE_CURVE[i].pct;
            uint8_t hiPct = DISCHARGE_CURVE[i].pct;
            uint8_t loPct = DISCHARGE_CURVE[i + 1].pct;
            float frac = (float)(mv - loMv) / (float)(hiMv - loMv);
            return loPct + (uint8_t)(frac * (hiPct - loPct));
        }
    }
    return 0;
}

// ── Public API ───────────────────────────────────────────

void battery_begin() {
    analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);  // full range (0-3.3V)
    // Take initial reading to seed the EMA filter
    _smoothedMv = (float)readBatteryMv();
    _percent = voltageToPercent((uint16_t)_smoothedMv);
    _initialized = true;
    _lastReadMs = millis();
}

void battery_update(uint32_t nowMs) {
    if (!_initialized) return;
    if (nowMs - _lastReadMs < BATTERY_READ_INTERVAL_MS) return;
    _lastReadMs = nowMs;

    float raw = (float)readBatteryMv();
    _smoothedMv = BATTERY_SMOOTH_ALPHA * raw + (1.0f - BATTERY_SMOOTH_ALPHA) * _smoothedMv;

    uint16_t mv = (uint16_t)_smoothedMv;
    _percent  = voltageToPercent(mv);
    // Voltage above 4.1V under load implies external power (USB) is connected.
    // No dedicated charge IC pin — voltage-only heuristic is sufficient because
    // the ESP32-S3 draws enough current that an unpowered battery drops below 4.1V quickly.
    _charging = (mv > BATTERY_CHARGING_MV);
}

uint8_t battery_getPercent() {
    return _percent;
}

bool battery_isCharging() {
    return _charging;
}

#endif // HAS_BATTERY
