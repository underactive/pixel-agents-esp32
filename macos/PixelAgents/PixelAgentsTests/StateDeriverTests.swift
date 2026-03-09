import XCTest
@testable import PixelAgents

final class StateDeriverTests: XCTestCase {

    func testToolUseDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Bash"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = StateDeriver.derive(from: record, agent: &agent)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "Bash")
        XCTAssertTrue(agent.hadToolInTurn)
    }

    func testReadToolDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Read"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = StateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "Read")
    }

    func testGrepToolDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    ["type": "tool_use", "name": "Grep"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = StateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
    }

    func testEndTurnDerivesIdle() {
        var agent = Agent(id: 0)
        agent.hadToolInTurn = true
        agent.activeTools = ["Bash"]

        let record: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [] as [[String: Any]],
                "stop_reason": "end_turn"
            ] as [String: Any]
        ]

        let result = StateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
        XCTAssertFalse(agent.hadToolInTurn)
        XCTAssertTrue(agent.activeTools.isEmpty)
    }

    func testSystemTurnDurationDerivesIdle() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "system",
            "turn_duration": 1.5
        ]

        let result = StateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
    }

    func testNoToolUseReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    ["type": "text", "text": "Hello"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = StateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    func testUserRecordReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "user",
            "message": [
                "content": [
                    ["type": "tool_result", "content": "ok"] as [String: Any]
                ]
            ] as [String: Any]
        ]

        let result = StateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }
}
