#if defined(HAS_BLE)

#include "ble_service.h"
#include "config.h"
#include <NimBLEDevice.h>
#include <esp_random.h>

// Nordic UART Service UUIDs
static const char* NUS_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* NUS_RX_UUID     = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* NUS_TX_UUID     = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

static BleService* _instance = nullptr;

// ── Server connection callbacks ──────────────────────────

class NusServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
        if (_instance) {
            _instance->_connected.store(true, std::memory_order_release);
        }
    }

    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {
        if (_instance) {
            _instance->_connected.store(false, std::memory_order_release);
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

bool BleService::begin(BleTransport& transport) {
    _transport = &transport;
    _instance = this;

    Serial.println("[BLE] Initializing NimBLE...");
    if (!NimBLEDevice::init(BLE_DEVICE_NAME)) {
        Serial.println("[BLE] FAIL: NimBLEDevice::init");
        return false;
    }
    NimBLEDevice::setMTU(BLE_MTU);

    // Generate random 4-digit PIN for device pairing
    _pin = (esp_random() % (BLE_PIN_MAX - BLE_PIN_MIN + 1)) + BLE_PIN_MIN;

    Serial.print("[BLE] Address: ");
    Serial.println(NimBLEDevice::getAddress().toString().c_str());
    char pinBuf[16];
    snprintf(pinBuf, sizeof(pinBuf), "[BLE] PIN: %04u", _pin);
    Serial.println(pinBuf);
    Serial.println("[BLE] NimBLE initialized");

    NimBLEServer* pServer = NimBLEDevice::createServer();
    if (!pServer) { Serial.println("[BLE] FAIL: createServer"); return false; }
    pServer->setCallbacks(&serverCallbacks);

    NimBLEService* pService = pServer->createService(NUS_SERVICE_UUID);
    if (!pService) { Serial.println("[BLE] FAIL: createService"); return false; }

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
    if (!pAdvertising) { Serial.println("[BLE] FAIL: getAdvertising"); return false; }

    // Split advertising data across two packets to fit 31-byte limit:
    // - Advertising packet: flags (3) + service UUID (18) + manufacturer data (6) = 27 bytes
    // - Scan response: device name (13 bytes)
    NimBLEAdvertisementData advData;
    advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
    advData.addServiceUUID(NUS_SERVICE_UUID);

    // Embed PIN in manufacturer-specific data for multi-device selection
    // Company ID: little-endian per BT spec; PIN: big-endian (matches companion decode)
    uint8_t mfgData[] = {
        (uint8_t)(BLE_MFG_COMPANY_ID & 0xFF),
        (uint8_t)(BLE_MFG_COMPANY_ID >> 8),
        (uint8_t)(_pin >> 8),
        (uint8_t)(_pin & 0xFF)
    };
    advData.setManufacturerData(std::string((char*)mfgData, sizeof(mfgData)));

    NimBLEAdvertisementData scanResponse;
    scanResponse.setName(BLE_DEVICE_NAME);

    pAdvertising->setAdvertisementData(advData);
    pAdvertising->setScanResponseData(scanResponse);
    if (!pAdvertising->start()) {
        Serial.println("[BLE] FAIL: advertising start");
        return false;
    }

    Serial.println("[BLE] Advertising started OK");
    return true;
}

#endif // HAS_BLE
