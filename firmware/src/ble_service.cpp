#if defined(HAS_BLE)

#include "ble_service.h"
#include "config.h"
#include <NimBLEDevice.h>

// Nordic UART Service UUIDs
static const char* NUS_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* NUS_RX_UUID     = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* NUS_TX_UUID     = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

static BleService* _instance = nullptr;

// ── Server connection callbacks ──────────────────────────

class NusServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
        if (_instance) {
            _instance->_connected = true;
        }
    }

    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {
        if (_instance) {
            _instance->_connected = false;
            // Flag ring buffer for reset — actual reset happens in main loop
            // context to avoid racing with pop() on the other core
            if (_instance->_transport) {
                _instance->_transport->requestReset();
            }
            // Restart advertising for reconnection
            NimBLEDevice::startAdvertising();
        }
    }
};

// ── RX characteristic callbacks (companion writes here) ──

class NusRxCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        if (_instance && _instance->_transport) {
            NimBLEAttValue val = pChar->getValue();
            _instance->_transport->push(val.data(), val.size());
        }
    }
};

// ── BleService implementation ────────────────────────────

static NusServerCallbacks serverCallbacks;
static NusRxCallbacks rxCallbacks;

void BleService::begin(BleTransport& transport) {
    _transport = &transport;
    _instance = this;

    NimBLEDevice::init(BLE_DEVICE_NAME);
    NimBLEDevice::setMTU(BLE_MTU);

    NimBLEServer* pServer = NimBLEDevice::createServer();
    if (!pServer) return;
    pServer->setCallbacks(&serverCallbacks);

    NimBLEService* pService = pServer->createService(NUS_SERVICE_UUID);
    if (!pService) return;

    // RX characteristic — companion writes protocol messages here
    NimBLECharacteristic* pRx = pService->createCharacteristic(
        NUS_RX_UUID,
        NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
    );
    if (pRx) {
        pRx->setCallbacks(&rxCallbacks);
    }

    // TX characteristic — reserved for future bidirectional messages
    pService->createCharacteristic(
        NUS_TX_UUID,
        NIMBLE_PROPERTY::NOTIFY
    );

    pService->start();

    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    if (!pAdvertising) return;
    pAdvertising->addServiceUUID(NUS_SERVICE_UUID);
    pAdvertising->setName(BLE_DEVICE_NAME);
    pAdvertising->start();
}

#endif // HAS_BLE
