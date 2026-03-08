#pragma once
#if defined(HAS_BLE)

#include "transport.h"
#include <atomic>

class BleService {
public:
    bool begin(BleTransport& transport);
    bool isConnected() const { return _connected.load(std::memory_order_acquire); }
    uint16_t getPin() const { return _pin; }

private:
    BleTransport* _transport = nullptr;
    std::atomic<bool> _connected{false};
    uint16_t _pin = 0;  // Set once in begin(), read-only after init

    friend class NusServerCallbacks;
    friend class NusRxCallbacks;
};

#endif // HAS_BLE
