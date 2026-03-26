import XCTest
@testable import PixelAgents

final class ProtocolBuilderTests: XCTestCase {

    func testBuildMessageFraming() {
        // Empty payload: [0xAA][0x55][TYPE][CHECKSUM]
        let msg = ProtocolBuilder.buildMessage(type: 0x06, payload: Data())
        XCTAssertEqual(msg[0], 0xAA) // sync1
        XCTAssertEqual(msg[1], 0x55) // sync2
        XCTAssertEqual(msg[2], 0x06) // type
        XCTAssertEqual(msg[3], 0x06) // checksum = type XOR (nothing) = type
    }

    func testBuildMessageChecksum() {
        // Payload [0x01, 0x02]: checksum = 0x03 ^ 0x01 ^ 0x02 = 0x00
        let msg = ProtocolBuilder.buildMessage(type: 0x03, payload: Data([0x01, 0x02]))
        XCTAssertEqual(msg.last, 0x03 ^ 0x01 ^ 0x02)
    }

    func testAgentUpdate() {
        let msg = ProtocolBuilder.agentUpdate(id: 2, state: .type, tool: "Edit")
        XCTAssertEqual(msg[0], 0xAA)
        XCTAssertEqual(msg[1], 0x55)
        XCTAssertEqual(msg[2], 0x01) // MSG_AGENT_UPDATE
        XCTAssertEqual(msg[3], 2)    // agent_id
        XCTAssertEqual(msg[4], 3)    // STATE_TYPE
        XCTAssertEqual(msg[5], 4)    // tool_name_len
        // Tool name bytes
        XCTAssertEqual(String(data: msg[6..<10], encoding: .utf8), "Edit")
    }

    func testAgentCount() {
        let msg = ProtocolBuilder.agentCount(5)
        XCTAssertEqual(msg[2], 0x02) // MSG_AGENT_COUNT
        XCTAssertEqual(msg[3], 5)    // count
    }

    func testHeartbeatLength() {
        let msg = ProtocolBuilder.heartbeat()
        // [sync1][sync2][type][4 bytes timestamp][checksum] = 8 bytes
        XCTAssertEqual(msg.count, 8)
        XCTAssertEqual(msg[2], 0x03) // MSG_HEARTBEAT
    }

    func testUsageStats() {
        let msg = ProtocolBuilder.usageStats(
            currentPct: 80, weeklyPct: 20,
            currentResetMin: 60, weeklyResetMin: 1200
        )
        XCTAssertEqual(msg[2], 0x05) // MSG_USAGE_STATS
        XCTAssertEqual(msg[3], 80)   // current_pct
        XCTAssertEqual(msg[4], 20)   // weekly_pct
        // current_reset_min = 60 = 0x003C big-endian
        XCTAssertEqual(msg[5], 0x00)
        XCTAssertEqual(msg[6], 0x3C)
        // weekly_reset_min = 1200 = 0x04B0 big-endian
        XCTAssertEqual(msg[7], 0x04)
        XCTAssertEqual(msg[8], 0xB0)
    }

    func testUsageStatsClamps() {
        let msg = ProtocolBuilder.usageStats(
            currentPct: 150, weeklyPct: 255,
            currentResetMin: 0, weeklyResetMin: 0
        )
        XCTAssertEqual(msg[3], 100)  // clamped to 100
        XCTAssertEqual(msg[4], 100)  // clamped to 100
    }

    func testToolNameTruncation() {
        let longTool = String(repeating: "A", count: 50)
        let msg = ProtocolBuilder.agentUpdate(id: 0, state: .read, tool: longTool)
        // tool_name_len should be capped at 24
        XCTAssertEqual(msg[5], 24)
    }

    func testScreenshotRequest() {
        let msg = ProtocolBuilder.screenshotRequest()
        XCTAssertEqual(msg.count, 4) // [sync1][sync2][type][checksum]
        XCTAssertEqual(msg[2], 0x06) // MSG_SCREENSHOT_REQ
    }

    func testDeviceSettings() {
        let msg = ProtocolBuilder.deviceSettings(
            dogEnabled: true, dogColor: 2, screenFlip: false, soundEnabled: true, dogBarkEnabled: true
        )
        // [sync1][sync2][type][5 payload bytes][checksum] = 9 bytes
        XCTAssertEqual(msg.count, 9)
        XCTAssertEqual(msg[2], 0x07) // MSG_DEVICE_SETTINGS
        XCTAssertEqual(msg[3], 1)    // dog_enabled
        XCTAssertEqual(msg[4], 2)    // dog_color (GRAY)
        XCTAssertEqual(msg[5], 0)    // screen_flip
        XCTAssertEqual(msg[6], 1)    // sound_enabled
        XCTAssertEqual(msg[7], 1)    // dog_bark_enabled
        // Verify checksum
        let check: UInt8 = msg[2] ^ msg[3] ^ msg[4] ^ msg[5] ^ msg[6] ^ msg[7]
        XCTAssertEqual(msg[8], check)
    }

    func testDeviceSettingsBooleanEncoding() {
        let msg = ProtocolBuilder.deviceSettings(
            dogEnabled: false, dogColor: 0, screenFlip: true, soundEnabled: false, dogBarkEnabled: false
        )
        XCTAssertEqual(msg[3], 0) // dog_enabled = false
        XCTAssertEqual(msg[4], 0) // dog_color = BLACK
        XCTAssertEqual(msg[5], 1) // screen_flip = true
        XCTAssertEqual(msg[6], 0) // sound_enabled = false
        XCTAssertEqual(msg[7], 0) // dog_bark_enabled = false
    }

    func testDeviceSettingsColorClamping() {
        let msg = ProtocolBuilder.deviceSettings(
            dogEnabled: true, dogColor: 99, screenFlip: false, soundEnabled: false, dogBarkEnabled: true
        )
        XCTAssertEqual(msg[4], 3) // clamped to max (TAN)
    }

    func testIdentifyRequest() {
        let msg = ProtocolBuilder.identifyRequest()
        // [sync1][sync2][type][checksum] = 4 bytes (no payload)
        XCTAssertEqual(msg.count, 4)
        XCTAssertEqual(msg[0], 0xAA) // sync1
        XCTAssertEqual(msg[1], 0x55) // sync2
        XCTAssertEqual(msg[2], 0x09) // MSG_IDENTIFY_REQ
        XCTAssertEqual(msg[3], 0x09) // checksum = type XOR (nothing) = type
    }

    func testParseIdentifyResponse() {
        // Valid payload: "PXAG" + protocol(1) + board(1) + version(0x0070 = 112 → 0.11.2)
        let payload = Data([0x50, 0x58, 0x41, 0x47, 1, 1, 0x00, 0x70])
        let result = ProtocolBuilder.parseIdentifyResponse(payload)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.protocolVersion, 1)
        XCTAssertEqual(result?.boardType, 1)
        XCTAssertEqual(result?.boardName, "CYD-S3")
        XCTAssertEqual(result?.firmwareVersion, "0.11.2")
    }

    func testParseIdentifyResponseBadMagic() {
        let payload = Data([0x00, 0x00, 0x00, 0x00, 1, 0, 0x00, 0x70])
        XCTAssertNil(ProtocolBuilder.parseIdentifyResponse(payload))
    }

    func testParseIdentifyResponseTooShort() {
        let payload = Data([0x50, 0x58, 0x41])
        XCTAssertNil(ProtocolBuilder.parseIdentifyResponse(payload))
    }
}
