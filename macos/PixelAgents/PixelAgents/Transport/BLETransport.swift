import Foundation
import CoreBluetooth

/// Discovered BLE device with NUS service.
struct BLEDevice: Identifiable, Hashable {
    let id: UUID              // CBPeripheral identifier
    let name: String
    let pin: UInt16?          // 4-digit PIN from manufacturer data (nil if not present)
    let peripheral: CBPeripheral

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id
    }
}

/// CoreBluetooth NUS (Nordic UART Service) client transport.
final class BLETransport: NSObject, TransportProtocol, ObservableObject {

    // MARK: - NUS UUIDs (must match firmware ble_service.cpp)

    static let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nusRxUUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // write to device
    static let nusTxUUID      = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // notify from device

    /// Manufacturer data company ID (must match firmware BLE_MFG_COMPANY_ID)
    static let mfgCompanyID: UInt16 = 0xFFFF

    // MARK: - Published state

    @Published private(set) var isConnected = false
    @Published private(set) var discoveredDevices: [BLEDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var connectedDeviceName: String?

    // MARK: - Private state

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?

    /// Callback when connection is lost (for auto-reconnect).
    var onDisconnect: (() -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(
            withServices: [Self.nusServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    // MARK: - Connection

    func connect(to device: BLEDevice) {
        stopScanning()
        centralManager.connect(device.peripheral, options: nil)
    }

    func connectByPin(_ pin: UInt16) {
        if let device = discoveredDevices.first(where: { $0.pin == pin }) {
            connect(to: device)
        }
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanupConnection()
    }

    func send(_ data: Data) -> Bool {
        guard let peripheral = connectedPeripheral,
              let rx = rxCharacteristic,
              isConnected else { return false }

        peripheral.writeValue(data, for: rx, type: .withoutResponse)
        return true
    }

    // MARK: - PIN extraction

    /// Extract 4-digit PIN from manufacturer advertising data.
    static func extractPin(from advertisementData: [String: Any]) -> UInt16? {
        guard let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              mfgData.count >= 4 else { return nil }

        // Company ID is little-endian in first 2 bytes
        let companyID = UInt16(mfgData[0]) | (UInt16(mfgData[1]) << 8)
        guard companyID == mfgCompanyID else { return nil }

        // PIN is big-endian in next 2 bytes
        let pin = (UInt16(mfgData[2]) << 8) | UInt16(mfgData[3])
        guard pin >= 1000, pin <= 9999 else { return nil }
        return pin
    }

    // MARK: - Private

    private func cleanupConnection() {
        connectedPeripheral = nil
        rxCharacteristic = nil
        connectedDeviceName = nil
        isConnected = false
    }
}

// MARK: - CBCentralManagerDelegate

extension BLETransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state != .poweredOn {
            stopScanning()
            if isConnected {
                cleanupConnection()
                onDisconnect?()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let pin = Self.extractPin(from: advertisementData)

        let device = BLEDevice(id: peripheral.identifier, name: name, pin: pin, peripheral: peripheral)

        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedDeviceName = peripheral.name ?? "PixelAgents"
        peripheral.delegate = self
        peripheral.discoverServices([Self.nusServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        cleanupConnection()
        onDisconnect?()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cleanupConnection()
        onDisconnect?()
    }
}

// MARK: - CBPeripheralDelegate

extension BLETransport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.nusServiceUUID {
            peripheral.discoverCharacteristics([Self.nusRxUUID, Self.nusTxUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == Self.nusRxUUID {
                rxCharacteristic = char
            } else if char.uuid == Self.nusTxUUID {
                // Subscribe to notifications (future use)
                peripheral.setNotifyValue(true, for: char)
            }
        }

        // Mark connected once RX characteristic is found
        if rxCharacteristic != nil {
            isConnected = true
        }
    }
}
