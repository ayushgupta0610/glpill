import XCTest
@testable import GLPill

private final class SpyScheduler: NotificationScheduling {
    var removed: [[String]] = []
    var added: [(id: String, title: String, body: String, trigger: ReminderTrigger)] = []
    var authorized = true
    var pending: [String] = []

    func requestAuthorization() async -> Bool { authorized }
    func removePending(ids: [String]) { removed.append(ids) }
    func add(id: String, title: String, body: String, trigger: ReminderTrigger) {
        added.append((id, title, body, trigger))
    }
    func pendingIds() async -> [String] { pending }
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

    func testEatTimerSchedulesThirtyMinuteOneOffByDefault() {
        let spy = SpyScheduler()
        ReminderScheduler.scheduleEatTimer(using: spy)

        XCTAssertEqual(spy.added.count, 1)
        XCTAssertEqual(spy.added[0].id, ReminderScheduler.eatTimerId)
        XCTAssertEqual(spy.added[0].trigger, .once(after: 1800))
        XCTAssertEqual(spy.added[0].body, "Your 30-minute wait is up — you can eat now.")
    }

    func testEatTimerHonorsWaitWindowMinutes() {
        let spy = SpyScheduler()
        ReminderScheduler.scheduleEatTimer(using: spy, waitWindowMinutes: 60)

        XCTAssertEqual(spy.added.count, 1)
        XCTAssertEqual(spy.added[0].trigger, .once(after: 3600))
        XCTAssertEqual(spy.added[0].body, "Your 60-minute wait is up — you can eat now.")
    }

    func testEatTimerBodyIsNeutralAndNamesNoMeds() {
        // Privacy: the body must never mention the user's other medications (lock-screen visible).
        let body = ReminderScheduler.eatTimerBody(waitWindowMinutes: 45)
        XCTAssertEqual(body, "Your 45-minute wait is up — you can eat now.")
        XCTAssertFalse(body.lowercased().contains("also take"))
    }
    func testEatTimerScheduledBodyNamesNoMeds() {
        let spy = SpyScheduler()
        ReminderScheduler.scheduleEatTimer(using: spy, waitWindowMinutes: 60)
        XCTAssertEqual(spy.added.first?.body, "Your 60-minute wait is up — you can eat now.")
    }

    func testEnsureDailyScheduledSkipsWhenAlreadyPending() async {
        let spy = SpyScheduler()
        spy.pending = [ReminderScheduler.dailyId]
        await ReminderScheduler.ensureDailyScheduled(hour: 8, minute: 0, using: spy)
        XCTAssertTrue(spy.added.isEmpty)
    }

    func testEnsureDailyScheduledReschedulesWhenMissing() async {
        let spy = SpyScheduler()
        spy.pending = []
        await ReminderScheduler.ensureDailyScheduled(hour: 8, minute: 15, using: spy)
        XCTAssertEqual(spy.added.count, 1)
        XCTAssertEqual(spy.added[0].id, ReminderScheduler.dailyId)
        XCTAssertEqual(spy.added[0].trigger, .daily(hour: 8, minute: 15))
    }
}
