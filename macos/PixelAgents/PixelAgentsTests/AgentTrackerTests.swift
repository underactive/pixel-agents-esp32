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

    func testIdWrapsAt256() {
        let tracker = AgentTracker()
        // Create 256 agents to fill the ID space
        for i in 0..<256 {
            _ = tracker.getOrCreate(key: "p\(i)")
        }
        // Next ID should wrap to 0
        let overflow = tracker.getOrCreate(key: "overflow")
        XCTAssertEqual(overflow.id, 0)
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
}
