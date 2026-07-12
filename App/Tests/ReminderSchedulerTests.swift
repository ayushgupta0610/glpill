import XCTest
@testable import GLPill

private final class SpyScheduler: NotificationScheduling {
    var removed: [[String]] = []
    var added: [(id: String, title: String, body: String, trigger: ReminderTrigger)] = []
    var authorized = true

    func requestAuthorization() async -> Bool { authorized }
    func removePending(ids: [String]) { removed.append(ids) }
    func add(id: String, title: String, body: String, trigger: ReminderTrigger) {
        added.append((id, title, body, trigger))
    }
}

final class ReminderSchedulerTests: XCTestCase {
    func testScheduleDailyReplacesExistingAndUsesTime() {
        let spy = SpyScheduler()
        ReminderScheduler.scheduleDaily(hour: 9, minute: 30, using: spy)

        XCTAssertEqual(spy.removed, [[ReminderScheduler.dailyId]])
        XCTAssertEqual(spy.added.count, 1)
        XCTAssertEqual(spy.added[0].id, ReminderScheduler.dailyId)
        XCTAssertEqual(spy.added[0].trigger, .daily(hour: 9, minute: 30))
    }

    func testEatTimerSchedulesThirtyMinuteOneOff() {
        let spy = SpyScheduler()
        ReminderScheduler.scheduleEatTimer(using: spy)

        XCTAssertEqual(spy.added.count, 1)
        XCTAssertEqual(spy.added[0].id, ReminderScheduler.eatTimerId)
        XCTAssertEqual(spy.added[0].trigger, .once(after: 1800))
    }
}
