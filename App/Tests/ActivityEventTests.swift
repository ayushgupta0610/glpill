import XCTest
@testable import GLPill

final class ActivityEventTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86400)
    }

    func testMergesAndSortsDescending() {
        let milestone = JourneyMilestone(id: 0, label: "20%", targetKg: 88, reachedDate: day(2))
        let events = ActivityFeed.merge(
            weightEntries: [(id: "w1", date: day(0), kg: 90.0)],
            doseLogs: [(id: "d1", date: day(1))],
            milestones: [milestone]
        )

        XCTAssertEqual(events.map(\.id), ["milestone-0", "dose-d1", "weight-w1"])
        XCTAssertEqual(events.map(\.date), [day(2), day(1), day(0)])
    }

    func testExcludesUnreachedMilestones() {
        let unreached = JourneyMilestone(id: 1, label: "40%", targetKg: 84, reachedDate: nil)
        let events = ActivityFeed.merge(weightEntries: [], doseLogs: [], milestones: [unreached])
        XCTAssertTrue(events.isEmpty)
    }

    func testEmptyInputsGiveEmptyFeed() {
        let events = ActivityFeed.merge(weightEntries: [], doseLogs: [], milestones: [])
        XCTAssertTrue(events.isEmpty)
    }

    func testEventKindsCarryTheirPayload() {
        let events = ActivityFeed.merge(
            weightEntries: [(id: "w1", date: day(0), kg: 90.5)],
            doseLogs: [],
            milestones: []
        )
        guard case .weighIn(let kg) = events[0].kind else {
            return XCTFail("expected .weighIn")
        }
        XCTAssertEqual(kg, 90.5, accuracy: 0.0001)
    }
}
