import Foundation

/// Binary protocol message builder matching firmware protocol in config.h / protocol.cpp.
/// Frame: [0xAA][0x55][MSG_TYPE][PAYLOAD...][XOR_CHECKSUM]
enum ProtocolBuilder {

    // MARK: - Protocol constants (must match firmware config.h)

    static let syncByte1: UInt8 = 0xAA
    static let syncByte2: UInt8 = 0x55

    static let msgAgentUpdate: UInt8   = 0x01
    static let msgAgentCount: UInt8    = 0x02
    static let msgHeartbeat: UInt8     = 0x03
    static let msgUsageStats: UInt8    = 0x05
    static let msgScreenshotReq: UInt8    = 0x06
    static let msgDeviceSettings: UInt8   = 0x07
    static let msgSettingsState: UInt8    = 0x08

    static let maxToolNameLen = 24

    // Screenshot response sync (device → companion)
    static let screenshotSync1: UInt8 = 0xBB
    static let screenshotSync2: UInt8 = 0x66

    // MARK: - Message builders

    /// Wrap a payload with sync bytes, message type, and XOR checksum.
    static func buildMessage(type: UInt8, payload: Data) -> Data {
        var checksum: UInt8 = type
        for byte in payload {
            checksum ^= byte
        }
        var data = Data([syncByte1, syncByte2, type])
        data.append(payload)
        data.append(checksum)
        return data
    }

    /// AGENT_UPDATE: agent_id(1) + state(1) + tool_name_len(1) + tool_name(0-24)
    static func agentUpdate(id: UInt8, state: CharState, tool: String = "") -> Data {
        let toolData = Data(tool.utf8.prefix(maxToolNameLen))
        var payload = Data([id, state.rawValue, UInt8(toolData.count)])
        payload.append(toolData)
        return buildMessage(type: msgAgentUpdate, payload: payload)
    }

    /// AGENT_COUNT: count(1)
    static func agentCount(_ count: UInt8) -> Data {
        return buildMessage(type: msgAgentCount, payload: Data([count]))
    }

    /// HEARTBEAT: timestamp(4, big-endian)
    static func heartbeat() -> Data {
        let ts = UInt32(Date().timeIntervalSince1970) & 0xFFFF_FFFF
        var payload = Data(count: 4)
        payload[0] = UInt8((ts >> 24) & 0xFF)
        payload[1] = UInt8((ts >> 16) & 0xFF)
        payload[2] = UInt8((ts >> 8) & 0xFF)
        payload[3] = UInt8(ts & 0xFF)
        return buildMessage(type: msgHeartbeat, payload: payload)
    }

    /// USAGE_STATS: current_pct(1) + weekly_pct(1) + current_reset_min(2,BE) + weekly_reset_min(2,BE)
    static func usageStats(
        currentPct: UInt8,
        weeklyPct: UInt8,
        currentResetMin: UInt16,
        weeklyResetMin: UInt16
    ) -> Data {
        let cp = min(currentPct, 100)
        let wp = min(weeklyPct, 100)
        let payload = Data([
            cp, wp,
            UInt8((currentResetMin >> 8) & 0xFF), UInt8(currentResetMin & 0xFF),
            UInt8((weeklyResetMin >> 8) & 0xFF), UInt8(weeklyResetMin & 0xFF),
        ])
        return buildMessage(type: msgUsageStats, payload: payload)
    }

    /// SCREENSHOT_REQ: no payload
    static func screenshotRequest() -> Data {
        return buildMessage(type: msgScreenshotReq, payload: Data())
    }

    /// DEVICE_SETTINGS: dog_enabled(1) + dog_color(1) + screen_flip(1) + sound_enabled(1)
    static func deviceSettings(
        dogEnabled: Bool,
        dogColor: UInt8,
        screenFlip: Bool,
        soundEnabled: Bool,
        dogBarkEnabled: Bool
    ) -> Data {
        let payload = Data([
            dogEnabled ? 1 : 0,
            min(dogColor, 3),
            screenFlip ? 1 : 0,
            soundEnabled ? 1 : 0,
            dogBarkEnabled ? 1 : 0
        ])
        return buildMessage(type: msgDeviceSettings, payload: payload)
    }
}
