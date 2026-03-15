#pragma once
#if defined(HAS_BLE)

#include "config.h"
#include "transport.h"
#include <atomic>

class NimBLECharacteristic;  // forward declaration

class BleService {
public:
    bool begin(BleTransport& transport);
    bool isConnected() const { return _connected.load(std::memory_order_acquire); }
    uint16_t getPin() const { return _pin; }

#if defined(HAS_BATTERY)
    void updateBatteryLevel(uint8_t percent);
#endif

private:
    BleTransport* _transport = nullptr;
    std::atomic<bool> _connected{false};
    uint16_t _pin = 0;  // Set once in begin(), read-only after init

#if defined(HAS_BATTERY)
    NimBLECharacteristic* _battLevelChar = nullptr;
    uint8_t _lastBattLevel = 0xFF;  // force first update (0xFF != any valid 0-100)
#endif

    friend class NusServerCallbacks;
    friend class NusRxCallbacks;
};

#endif // HAS_BLE
