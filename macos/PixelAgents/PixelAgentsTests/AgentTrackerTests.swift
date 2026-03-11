import XCTest
@testable import PixelAgents

final class AgentTrackerTests: XCTestCase {

    func testGetOrCreateAssignsIncrementingIds() {
        let tracker = AgentTracker()
        let a = tracker.getOrCreate(key: "project1")
        let b = tracker.getOrCreate(key: "project2")
        XCTAssertEqual(a.id, 0)
        XCTAssertEqual(b.id, 1)
    }

    func testGetOrCreateReturnsSameAgent() {
        let tracker = AgentTracker()
        let a = tracker.getOrCreate(key: "project1")
        let b = tracker.getOrCreate(key: "project1")
        XCTAssertEqual(a.id, b.id)
    }

    func testPruneStale() {
        let tracker = AgentTracker()
        _ = tracker.getOrCreate(key: "project1")
        tracker.update(key: "project1") { $0.lastSeen = Date().addingTimeInterval(-60) }

        _ = tracker.getOrCreate(key: "project2")
        tracker.update(key: "project2") { $0.lastSeen = Date() }

        let pruned = tracker.pruneStale(timeout: 30)
        XCTAssertEqual(pruned.count, 1)
        XCTAssertEqual(pruned[0].id, 0)
        XCTAssertEqual(tracker.count, 1)
    }

    func testCount() {
        let tracker = AgentTracker()
        XCTAssertEqual(tracker.count, 0)
        _ = tracker.getOrCreate(key: "a")
        XCTAssertEqual(tracker.count, 1)
        _ = tracker.getOrCreate(key: "b")
        XCTAssertEqual(tracker.count, 2)
    }

    func testReset() {
        let tracker = AgentTracker()
        _ = tracker.getOrCreate(key: "a")
        _ = tracker.getOrCreate(key: "b")
        tracker.reset()
        XCTAssertEqual(tracker.count, 0)

        // After reset, IDs start from 0 again
        let c = tracker.getOrCreate(key: "c")
        XCTAssertEqual(c.id, 0)
    }

    func testPrunedIdsAreRecycled() {
        let tracker = AgentTracker()
        _ = tracker.getOrCreate(key: "project1") // id 0
        _ = tracker.getOrCreate(key: "project2") // id 1

        // Make project1 stale and prune it
        tracker.update(key: "project1") { $0.lastSeen = Date().addingTimeInterval(-60) }
        let pruned = tracker.pruneStale(timeout: 30)
        XCTAssertEqual(pruned.count, 1)
        XCTAssertEqual(pruned[0].id, 0)

        // New agent should reuse recycled id 0, not get id 2
        let c = tracker.getOrCreate(key: "project3")
        XCTAssertEqual(c.id, 0)
    }

    func testNewIdAfterRecyclePoolExhausted() {
        let tracker = AgentTracker()
        _ = tracker.getOrCreate(key: "project1") // id 0
        _ = tracker.getOrCreate(key: "project2") // id 1

        // Prune project1, recycling id 0
        tracker.update(key: "project1") { $0.lastSeen = Date().addingTimeInterval(-60) }
        _ = tracker.pruneStale(timeout: 30)

        // Use the recycled id
        _ = tracker.getOrCreate(key: "project3") // reuses id 0

        // Next agent should get id 2 (next fresh id)
        let d = tracker.getOrCreate(key: "project4")
        XCTAssertEqual(d.id, 2)
    }

    func testResetClearsRecycledIds() {
        let tracker = AgentTracker()
        _ = tracker.getOrCreate(key: "a") // id 0
        tracker.update(key: "a") { $0.lastSeen = Date().addingTimeInterval(-60) }
        _ = tracker.pruneStale(timeout: 30) // id 0 recycled
        tracker.reset()

        // After reset, next ID is 0 from fresh counter, not from recycled pool
        let b = tracker.getOrCreate(key: "b")
        XCTAssertEqual(b.id, 0)

        // And the next one increments normally
        let c = tracker.getOrCreate(key: "c")
        XCTAssertEqual(c.id, 1)
    }

    func testSortedAgents() {
        let tracker = AgentTracker()
        _ = tracker.getOrCreate(key: "c")
        _ = tracker.getOrCreate(key: "a")
        _ = tracker.getOrCreate(key: "b")

        let sorted = tracker.sortedAgents
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].id, 0)
        XCTAssertEqual(sorted[1].id, 1)
        XCTAssertEqual(sorted[2].id, 2)
    }

    func testSourceIsStoredOnCreation() {
        let tracker = AgentTracker()
        let claude = tracker.getOrCreate(key: "claude-project", source: .claude)
        let codex = tracker.getOrCreate(key: "codex-project", source: .codex)
        XCTAssertEqual(claude.source, .claude)
        XCTAssertEqual(codex.source, .codex)

        // Re-fetching returns the same source
        let claudeAgain = tracker.getOrCreate(key: "claude-project", source: .codex)
        XCTAssertEqual(claudeAgain.source, .claude)
    }
}
