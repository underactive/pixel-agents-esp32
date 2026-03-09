import SwiftUI

/// Transport mode selector with serial port / BLE device picker.
struct TransportPicker: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Transport mode toggle
            Picker("Transport", selection: $bridge.transportMode) {
                ForEach(TransportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: bridge.transportMode) { newValue in
                bridge.setTransport(newValue)
            }

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
            Picker("Port", selection: $bridge.selectedPort) {
                Text("Auto").tag(nil as String?)
                ForEach(bridge.serialPortDetector.availablePorts) { port in
                    Text(port.name).tag(port.path as String?)
                }
            }
            .font(.system(size: 11))
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
                if bridge.bleTransport.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Button("Scan for Devices") {
                        bridge.bleTransport.startScanning()
                    }
                    .font(.system(size: 11))
                }
            }
        } else {
            ForEach(bridge.bleTransport.discoveredDevices) { device in
                Button {
                    bridge.connectBLEDevice(device)
                } label: {
                    HStack {
                        Text(device.name)
                            .font(.system(size: 11))
                        if let pin = device.pin {
                            Text("PIN: \(pin)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if bridge.bleTransport.isConnected && bridge.bleTransport.connectedDeviceName == device.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
