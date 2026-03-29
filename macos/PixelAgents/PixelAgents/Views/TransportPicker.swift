import SwiftUI

/// Transport mode selector with serial port / BLE device picker.
struct TransportPicker: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Transport mode toggle
            Picker("Transport", selection: Binding(
                get: { bridge.transportMode },
                set: { bridge.setTransport($0) }
            )) {
                ForEach(TransportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Transport-specific options
            switch bridge.transportMode {
            case .serial:
                serialPicker

            case .ble:
                blePicker
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var serialPicker: some View {
        if bridge.serialPortDetector.availablePorts.isEmpty {
            Text("No USB serial devices found")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } else {
            HStack {
                Picker("Port", selection: $bridge.selectedPort) {
                    Text("Auto").tag(nil as String?)
                    ForEach(bridge.serialPortDetector.availablePorts) { port in
                        Text(port.name).tag(port.path as String?)
                    }
                }
                .font(.system(size: 11))

                if bridge.serialTransportConnected {
                    Button("Disconnect") {
                        bridge.disconnect()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                } else if case .disconnected = bridge.connectionState {
                    Button("Connect") {
                        bridge.connect()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var blePicker: some View {
        if bridge.bleTransport.bluetoothState != .poweredOn {
            Text("Bluetooth is off")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } else if bridge.bleTransport.discoveredDevices.isEmpty {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .onAppear {
                if !bridge.bleTransport.isScanning {
                    bridge.bleTransport.startScanning()
                }
            }
        } else {
            ForEach(bridge.bleTransport.discoveredDevices) { device in
                let isThisDeviceConnected = bridge.bleTransport.isConnected && device.id == bridge.bleTransport.connectedPeripheralID
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        if isThisDeviceConnected, let level = bridge.deviceBatteryLevel {
                            HStack(spacing: 3) {
                                Image(systemName: batteryIconName(level))
                                    .foregroundColor(batteryColor(level))
                                    .font(.system(size: 11))
                                Text("\(level)%")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(batteryColor(level))
                            }
                        } else {
                            Text(device.name)
                                .font(.system(size: 11))
                        }
                        if let pin = device.pin {
                            Text("PIN: \(String(format: "%04d", pin))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isThisDeviceConnected {
                        Button("Disconnect") {
                            bridge.disconnect()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                    } else if bridge.bleTransport.pendingPeripheralID == device.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Connect") {
                            bridge.connectBLEDevice(device)
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}
