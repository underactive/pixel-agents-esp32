import XCTest
@testable import PixelAgents

final class GeminiStateDeriverTests: XCTestCase {

    func testWriteToolDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "write_file", "displayName": "WriteFile", "status": "success"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "WriteFile")
        XCTAssertTrue(agent.hadToolInTurn)
    }

    func testRunCommandDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "run_command", "displayName": "RunCommand"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "RunCommand")
    }

    func testWebFetchDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "web_fetch", "displayName": "WebFetch"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "WebFetch")
    }

    func testGoogleSearchDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "google_web_search", "displayName": "GoogleSearch"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
        XCTAssertEqual(result?.1, "GoogleSearch")
    }

    func testReadFileDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "read_file", "displayName": "ReadFile"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
    }

    func testListDirectoryDerivesRead() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "list_directory"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .read)
    }

    func testTextOnlyGeminiDerivesType() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "content": "Here is my response..."
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "Gemini")
        XCTAssertTrue(agent.hadToolInTurn)
    }

    func testUserMessageDerivesIdle() {
        var agent = Agent(id: 0)
        agent.hadToolInTurn = true
        agent.activeTools = ["web_fetch"]

        let record: [String: Any] = [
            "type": "user",
            "content": [["text": "What is this?"] as [String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .idle)
        XCTAssertEqual(result?.1, "")
        XCTAssertFalse(agent.hadToolInTurn)
        XCTAssertTrue(agent.activeTools.isEmpty)
    }

    func testUnknownTypeReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "system",
            "content": "metadata"
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    func testMissingTypeReturnsNil() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "content": "no type field"
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertNil(result)
    }

    func testFallsBackToNameWhenNoDisplayName() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "edit_file"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "edit_file")
    }

    func testUsesLastToolCallForDisplay() {
        var agent = Agent(id: 0)
        let record: [String: Any] = [
            "type": "gemini",
            "toolCalls": [
                ["name": "read_file", "displayName": "ReadFile"] as [String: Any],
                ["name": "write_file", "displayName": "WriteFile"] as [String: Any]
            ] as [[String: Any]]
        ]

        let result = GeminiStateDeriver.derive(from: record, agent: &agent)
        XCTAssertEqual(result?.0, .type)
        XCTAssertEqual(result?.1, "WriteFile")
    }
}
