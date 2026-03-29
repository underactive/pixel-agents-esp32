import SwiftUI

/// Device settings tab: controls for dog, screen flip, and sound synced to the ESP32.
struct DeviceSettingsView: View {
    @ObservedObject var bridge: BridgeService

    private static let dogColorNames = ["Black", "Brown", "Gray", "Tan"]

    private var isConnected: Bool {
        if case .connected = bridge.connectionState, bridge.displayMode == .hardware {
            return true
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !isConnected {
                Text("Connect to a device to configure settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            } else if bridge.deviceIdentified == false {
                Text("Connected device is not a Pixel Agents device.")
                    .font(.subheadline)
                    .foregroundColor(.orange)

                Button("Disconnect") {
                    bridge.disconnect()
                }
                .font(.subheadline)

                Spacer()
            } else if !bridge.deviceSettingsReceived {
                Text("Waiting for device settings...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Text("Dog")
                    .font(.subheadline.weight(.semibold))

                Toggle("Show dog", isOn: Binding(
                    get: { bridge.deviceDogEnabled },
                    set: { bridge.setDeviceDogEnabled($0) }
                ))
                .font(.subheadline)

                Picker("Color", selection: Binding(
                    get: { bridge.deviceDogColor },
                    set: { bridge.setDeviceDogColor($0) }
                )) {
                    ForEach(0..<Self.dogColorNames.count, id: \.self) { i in
                        Text(Self.dogColorNames[i]).tag(UInt8(i))
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!bridge.deviceDogEnabled)

                Divider()
                    .padding(.vertical, 4)

                Text("Display")
                    .font(.subheadline.weight(.semibold))

                Toggle("Flip screen", isOn: Binding(
                    get: { bridge.deviceScreenFlip },
                    set: { bridge.setDeviceScreenFlip($0) }
                ))
                .font(.subheadline)

                Divider()
                    .padding(.vertical, 4)

                Text("Audio")
                    .font(.subheadline.weight(.semibold))

                Toggle("Sound effects", isOn: Binding(
                    get: { bridge.deviceSoundEnabled },
                    set: { bridge.setDeviceSoundEnabled($0) }
                ))
                .font(.subheadline)

                Toggle("Dog bark", isOn: Binding(
                    get: { bridge.deviceDogBarkEnabled },
                    set: { bridge.setDeviceDogBarkEnabled($0) }
                ))
                .font(.subheadline)
                .disabled(!bridge.deviceSoundEnabled)

                Divider()
                    .padding(.vertical, 4)

                Button("Reboot Device") {
                    bridge.rebootDevice()
                }
                .font(.subheadline)

                Spacer()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
