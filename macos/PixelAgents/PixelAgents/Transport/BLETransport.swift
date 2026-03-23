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

    // MARK: - BLE Battery Service (BAS) UUIDs

    static let basServiceUUID = CBUUID(string: "180F")
    static let basLevelUUID   = CBUUID(string: "2A19")

    /// Manufacturer data company ID (must match firmware BLE_MFG_COMPANY_ID)
    static let mfgCompanyID: UInt16 = 0xFFFF

    /// Connect timeout — CoreBluetooth connect() has no built-in timeout.
    private static let connectTimeout: TimeInterval = 10.0

    // MARK: - Published state

    @Published private(set) var isConnected = false
    @Published private(set) var discoveredDevices: [BLEDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var batteryLevel: UInt8?

    /// UUID of the currently connected peripheral (for UI).
    var connectedPeripheralID: UUID? { connectedPeripheral?.identifier }

    /// UUID of the peripheral with a pending connect() (for UI).
    var pendingPeripheralID: UUID? { pendingPeripheral?.identifier }

    // MARK: - Private state

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?

    /// Peripheral with a pending connect() call (not yet connected).
    private var pendingPeripheral: CBPeripheral?

    /// UUID of the last successfully connected peripheral (for reconnection).
    private var lastConnectedID: UUID?

    /// Timeout work item for connect attempts.
    private var connectTimeoutWork: DispatchWorkItem?

    /// Set after UUID-based reconnect times out — skip UUID and rely on scan + auto-connect.
    private var skipUUIDReconnect = false

    /// When true, next cleanupConnection preserves discoveredDevices (for manual disconnect).
    private var keepDevicesOnCleanup = false

    /// Callback when connection is lost (for auto-reconnect).
    var onDisconnect: (() -> Void)?
    var onSettingsState: ((_ payload: Data) -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            NSLog("[BLE] Cannot scan — Bluetooth state: %d", centralManager.state.rawValue)
            return
        }
        discoveredDevices.removeAll()
        centralManager.stopScan() // Ensure clean scan session (resets duplicate tracking)
        centralManager.scanForPeripherals(
            withServices: [Self.nusServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
        NSLog("[BLE] Scan started")
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    // MARK: - Connection

    func connect(to device: BLEDevice) {
        stopScanning()
        cancelPendingConnect()
        skipUUIDReconnect = false

        NSLog("[BLE] Connecting to: %@ (id: %@)", device.name, device.id.uuidString)
        pendingPeripheral = device.peripheral
        centralManager.connect(device.peripheral, options: nil)
        startConnectTimeout()
    }

    func connectByPin(_ pin: UInt16) {
        guard !isConnected, pendingPeripheral == nil else { return }

        if let device = discoveredDevices.first(where: { $0.pin == pin }) {
            connect(to: device)
        } else if !isScanning {
            startScanning()
        }
    }

    /// Auto-reconnect: tries UUID-based reconnect first, falls back to scanning.
    /// Returns true if an active connection attempt is in progress.
    @discardableResult
    func reconnect() -> Bool {
        guard !isConnected else { return false }

        // Connection already in progress — report it
        if pendingPeripheral != nil { return true }

        // Try UUID-based reconnect (skip after first timeout — rely on scan + auto-connect)
        if let uuid = lastConnectedID, !skipUUIDReconnect {
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = peripherals.first {
                NSLog("[BLE] Reconnecting by UUID: %@", uuid.uuidString)
                stopScanning()
                pendingPeripheral = peripheral
                peripheral.delegate = self
                centralManager.connect(peripheral, options: nil)
                startConnectTimeout()
                return true
            }
            NSLog("[BLE] Could not retrieve peripheral %@, clearing", uuid.uuidString)
            lastConnectedID = nil
        }

        // Check if a previous scan already found the device we want
        if let uuid = lastConnectedID,
           let device = discoveredDevices.first(where: { $0.id == uuid }) {
            NSLog("[BLE] Found known device in scan results, connecting")
            connect(to: device)
            return true
        }

        // Fall back to scanning — next reconnect() call will check discoveredDevices
        if !isScanning {
            NSLog("[BLE] Starting scan for reconnect")
            startScanning()
        }
        return false
    }

    func disconnect() {
        cancelPendingConnect()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanupConnection()
    }

    /// Disconnect but preserve discovered devices so the user can reconnect manually.
    func disconnectKeepDevices() {
        keepDevicesOnCleanup = true
        cancelPendingConnect()
        if let peripheral = connectedPeripheral {
            // Keep connectedPeripheral set so didDisconnectPeripheral's guard passes
            // and cleanupConnection() consumes keepDevicesOnCleanup.
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            cleanupConnection()
        }
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

    private func cancelPendingConnect() {
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
        if let pending = pendingPeripheral {
            pendingPeripheral = nil // Clear before cancel to avoid callback interference
            centralManager.cancelPeripheralConnection(pending)
        }
    }

    private func startConnectTimeout() {
        connectTimeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.pendingPeripheral != nil else { return }
            NSLog("[BLE] Connect timeout after %.0fs — falling back to scan", Self.connectTimeout)
            self.cancelPendingConnect()
            // Don't clear lastConnectedID — didDiscover needs it for auto-connect
            self.skipUUIDReconnect = true
            self.startScanning()
        }
        connectTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectTimeout, execute: work)
    }

    private func cleanupConnection() {
        connectedPeripheral = nil
        pendingPeripheral = nil
        rxCharacteristic = nil
        connectedDeviceName = nil
        batteryLevel = nil
        isConnected = false
        if keepDevicesOnCleanup {
            keepDevicesOnCleanup = false
        } else {
            discoveredDevices.removeAll()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLETransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("[BLE] Central state changed: %d", central.state.rawValue)
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
            NSLog("[BLE] Discovered: %@ (PIN: %@, id: %@)", name, pin.map { String($0) } ?? "none", peripheral.identifier.uuidString)
            discoveredDevices.append(device)

            // Note: reconnect() checks discoveredDevices on each timer tick,
            // so we don't auto-connect here — that avoids state races with BridgeService.
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("[BLE] Connected: %@ (id: %@)", peripheral.name ?? "Unknown", peripheral.identifier.uuidString)
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
        lastConnectedID = peripheral.identifier
        skipUUIDReconnect = false
        pendingPeripheral = nil
        connectedPeripheral = peripheral
        connectedDeviceName = peripheral.name ?? "PixelAgents"
        peripheral.delegate = self
        peripheral.discoverServices([Self.nusServiceUUID, Self.basServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLE] Failed to connect: %@ — %@", peripheral.name ?? "Unknown", error?.localizedDescription ?? "unknown error")
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
        pendingPeripheral = nil
        cleanupConnection()
        onDisconnect?()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLE] Disconnected: %@ — %@", peripheral.name ?? "Unknown", error?.localizedDescription ?? "clean disconnect")

        // Ignore disconnect callbacks for peripherals we already cancelled/abandoned.
        // cancelPendingConnect() nils pendingPeripheral before calling cancelPeripheralConnection,
        // so the resulting callback arrives when neither pending nor connected matches.
        guard peripheral === connectedPeripheral || peripheral === pendingPeripheral else {
            NSLog("[BLE] Ignoring disconnect for stale peripheral")
            return
        }

        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
        cleanupConnection()
        onDisconnect?()
    }
}

// MARK: - CBPeripheralDelegate

extension BLETransport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            NSLog("[BLE] Service discovery failed: %@", error?.localizedDescription ?? "no services")
            centralManager.cancelPeripheralConnection(peripheral)
            cleanupConnection()
            onDisconnect?()
            return
        }
        for service in services {
            if service.uuid == Self.nusServiceUUID {
                peripheral.discoverCharacteristics([Self.nusRxUUID, Self.nusTxUUID], for: service)
            } else if service.uuid == Self.basServiceUUID {
                peripheral.discoverCharacteristics([Self.basLevelUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            NSLog("[BLE] Characteristic discovery failed: %@", error?.localizedDescription ?? "no characteristics")
            centralManager.cancelPeripheralConnection(peripheral)
            cleanupConnection()
            onDisconnect?()
            return
        }
        for char in characteristics {
            if char.uuid == Self.nusRxUUID {
                rxCharacteristic = char
            } else if char.uuid == Self.nusTxUUID {
                // Subscribe to notifications (future use)
                peripheral.setNotifyValue(true, for: char)
            } else if char.uuid == Self.basLevelUUID {
                // Read initial value and subscribe to battery level notifications
                peripheral.readValue(for: char)
                peripheral.setNotifyValue(true, for: char)
                NSLog("[BLE] Battery service discovered")
            }
        }

        // Mark connected once RX characteristic is found
        if rxCharacteristic != nil {
            NSLog("[BLE] NUS ready — transport connected")
            isConnected = true
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else { return }

        if characteristic.uuid == Self.basLevelUUID {
            let level = data[0]
            if level <= 100 {
                DispatchQueue.main.async {
                    self.batteryLevel = level
                }
                NSLog("[BLE] Battery level: %d%%", level)
            }
        } else if characteristic.uuid == Self.nusTxUUID {
            // Parse protocol frame: [0xAA][0x55][type][payload...][checksum]
            guard data.count >= 9,
                  data[0] == ProtocolBuilder.syncByte1,
                  data[1] == ProtocolBuilder.syncByte2,
                  data[2] == ProtocolBuilder.msgSettingsState else { return }
            let check = data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7]
            guard check == data[8] else { return }
            let payload = data.subdata(in: 3..<8)
            onSettingsState?(payload)
        }
    }
}
