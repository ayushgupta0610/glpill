import XCTest
@testable import GLPill

final class WidgetSnapshotTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: .now)!)
    }

    @MainActor
    func testSnapshotStreakAndTakenToday() {
        let snap = WidgetSnapshotBuilder.snapshot(
            doseDays: [day(-2), day(-1), day(0)],
            today: .now,
            medShortName: "Rybelsus",
            doseMg: 7,
            calendar: calendar
        )
        XCTAssertEqual(snap.streak, 3)
        XCTAssertTrue(snap.doseTakenToday)
        XCTAssertEqual(snap.medShortName, "Rybelsus")
        XCTAssertEqual(snap.doseMg, 7)
    }

    @MainActor
    func testSnapshotNotTakenTodayKeepsStreakAlive() {
        // Logged yesterday but not today — streak stays 1, not taken today.
        let snap = WidgetSnapshotBuilder.snapshot(
            doseDays: [day(-1)],
            today: .now,
            medShortName: "Foundayo",
            doseMg: 0.8,
            calendar: calendar
        )
        XCTAssertEqual(snap.streak, 1)
        XCTAssertFalse(snap.doseTakenToday)
    }

    func testSnapshotCodableRoundTrip() throws {
        let original = GLPillWidgetSnapshot(streak: 12, doseTakenToday: true, medShortName: "Rybelsus", doseMg: 14)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GLPillWidgetSnapshot.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
