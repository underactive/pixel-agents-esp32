import XCTest
@testable import PixelAgents

final class CodexStateDeriverTests: XCTestCase {

    // MARK: - response_item / function_call (exec_command)

    func testExecCommandWriteDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "function_call",
                "name": "exec_command",
                "arguments": "{\"cmd\": \"python3 build.py\"}"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "python3")
        XCTAssertTrue(agent.hadToolInTurn)
    }

    func testExecCommandReadDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "function_call",
                "name": "exec_command",
                "arguments": "{\"cmd\": \"cat src/main.cpp\"}"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "cat")
    }

    func testExecCommandMalformedArgsDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "function_call",
                "name": "exec_command",
                "arguments": "not valid json {{"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "exec_command")
    }

    // MARK: - response_item / function_call (other names)

    func testFunctionCallOtherNameDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "function_call",
                "name": "apply_patch"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "apply_patch")
    }

    // MARK: - response_item / custom_tool_call

    func testCustomToolCallDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "custom_tool_call",
                "name": "my_custom_tool"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "my_custom_tool")
    }

    // MARK: - response_item / web_search_call

    func testWebSearchCallDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "web_search_call"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "WebSearch")
    }

    // MARK: - response_item / reasoning (no state change)

    func testReasoningReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "reasoning"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    // MARK: - event_msg / task_complete

    func testTaskCompleteDerivesIdle() {
        var agent = Agent(id: 0)
        agent.hadToolInTurn = true
        agent.activeTools = ["cat"]

        let record: [String: Any] = [
            "type": "event_msg",
            "payload": [
                "type": "task_complete"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
        XCTAssertFalse(agent.hadToolInTurn)
        XCTAssertTrue(agent.activeTools.isEmpty)
    }

    // MARK: - event_msg / turn_aborted

    func testTurnAbortedDerivesIdle() {
        var agent = Agent(id: 0)
        agent.hadToolInTurn = true
        agent.activeTools = ["cat"]

        let record: [String: Any] = [
            "type": "event_msg",
            "payload": [
                "type": "turn_aborted"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
        XCTAssertFalse(agent.hadToolInTurn)
        XCTAssertTrue(agent.activeTools.isEmpty)
    }

    // MARK: - event_msg / task_started (no state change)

    func testTaskStartedReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "event_msg",
            "payload": [
                "type": "task_started"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    // MARK: - No-op record types

    func testSessionMetaReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "session_meta",
            "payload": ["session_id": "abc"] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    func testTurnContextReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = ["type": "turn_context"]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    func testCompactedReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = ["type": "compacted"]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    // MARK: - Legacy ResponseItem backward compat

    func testLegacyResponseItemStillWorks() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "ResponseItem",
            "payload": [
                "type": "function_call",
                "name": "shell"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "shell")
    }

    // MARK: - Legacy EventMsg backward compat

    func testLegacyEventMsgTurnCompleteStillWorks() {
        var agent = Agent(id: 0)
        agent.hadToolInTurn = true

        let record: [String: Any] = [
            "type": "EventMsg",
            "payload": [
                "type": "turn_complete"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
        XCTAssertFalse(agent.hadToolInTurn)
    }

    // MARK: - exec_command with dict arguments (fallback)

    func testExecCommandDictArgumentsDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "response_item",
            "payload": [
                "type": "function_call",
                "name": "exec_command",
                "arguments": ["cmd": "grep -r TODO ."] as [String: Any]
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "grep")
    }

    // MARK: - codex exec --json format (item.started / item.completed)

    func testItemStartedCommandExecutionDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "item.started",
            "item": [
                "type": "command_execution",
                "command": "npm run build"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "npm")
        XCTAssertTrue(agent.hadToolInTurn)
    }

    func testItemCompletedReadCommandDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "item.completed",
            "item": [
                "type": "command_execution",
                "command": "find . -name '*.py'"
            ] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "find")
    }

    func testItemStartedFileChangeDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "item.started",
            "item": ["type": "file_change"] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "Edit")
    }

    func testItemStartedWebSearchDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "item.started",
            "item": ["type": "web_search"] as [String: Any]
        ]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "WebSearch")
    }

    func testTurnCompletedDerivesIdle() {
        var agent = Agent(id: 0)
        agent.hadToolInTurn = true
        agent.activeTools = ["npm"]

        let record: [String: Any] = ["type": "turn.completed"]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
        XCTAssertFalse(agent.hadToolInTurn)
        XCTAssertTrue(agent.activeTools.isEmpty)
    }

    func testTurnStartedReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = ["type": "turn.started"]

        let result = CodexStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }
}
