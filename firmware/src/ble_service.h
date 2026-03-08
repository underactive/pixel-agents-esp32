#pragma once
#if defined(HAS_BLE)

#include "transport.h"

class BleService {
public:
    void begin(BleTransport& transport);
    bool isConnected() const { return _connected; }

private:
    BleTransport* _transport = nullptr;
    volatile bool _connected = false;

    friend class NusServerCallbacks;
    friend class NusRxCallbacks;
};

#endif // HAS_BLE
