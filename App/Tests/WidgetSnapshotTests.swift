import XCTest
import SwiftData
@testable import GLPill

final class WidgetSnapshotTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: GLPillWidgetBridge.appGroupID)?
            .removeObject(forKey: GLPillWidgetBridge.snapshotKey)
    }

    /// End-to-end: logging a dose must publish a streak of 1 to the App Group
    /// snapshot the widget reads. Reproduces the "widget shows 0" report.
    @MainActor
    func testLogDosePublishesStreakToWidget() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let store = TodayStore(context: container.mainContext)

        try store.logDose()

        let snapshot = GLPillWidgetBridge.load()
        XCTAssertEqual(snapshot.streak, 1)
        XCTAssertTrue(snapshot.doseTakenToday)
    }

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
