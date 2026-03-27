import XCTest
@testable import PixelAgents

final class CursorStateDeriverTests: XCTestCase {

    // MARK: - Tool Use Parsing

    func testToolUseDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Shell"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "Shell")
        XCTAssertTrue(agent.hadToolInTurn)
        XCTAssertTrue(agent.activeTools.contains("Shell"))
    }

    func testReadToolDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Read"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "Read")
    }

    func testGrepToolDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Grep"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
    }

    func testGlobToolDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Glob"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
    }

    func testWriteToolDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Edit"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "Edit")
    }

    // MARK: - Text-Only Fallback

    func testTextOnlyDerivesTypeCursor() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [
                    ["type": "text", "text": "Hello"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "Cursor")
    }

    // MARK: - Mixed Content

    func testMixedContentPrefersToolUse() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [
                    ["type": "text", "text": "Let me check..."] as [String: Any],
                    ["type": "tool_use", "name": "Shell"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "Shell")
    }

    // MARK: - User Role

    func testUserRoleDerivesIdle() {
        var agent = Agent(id: 0)
        agent.hadToolInTurn = true
        agent.activeTools = ["Shell"]

        let record: [String: Any] = [
            "role": "user",
            "message": [
                "content": [
                    ["type": "text", "text": "do something"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
        XCTAssertEqual(result?.1, "")
        XCTAssertFalse(agent.hadToolInTurn)
        XCTAssertTrue(agent.activeTools.isEmpty)
    }

    // MARK: - Edge Cases

    func testEmptyContentReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "role": "assistant",
            "message": [
                "content": [] as [[String: Any]]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    func testMissingRoleReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "message": [
                "content": [
                    ["type": "text", "text": "Hello"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = CursorStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }
}
