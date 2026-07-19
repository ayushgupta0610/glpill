import XCTest
@testable import GLPill

final class RitualStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private var later: Date { now.addingTimeInterval(600) }

    func testNotLoggedRybelsus() {
        XCTAssertEqual(RitualState.make(todayLogged: false, requiresEmptyStomach: true, windowEnd: nil, meds: [], now: now), .notTaken(requiresEmptyStomach: true))
    }
    func testNotLoggedOrforglipron() {
        XCTAssertEqual(RitualState.make(todayLogged: false, requiresEmptyStomach: false, windowEnd: nil, meds: [], now: now), .notTaken(requiresEmptyStomach: false))
    }
    func testLoggedOrforglipronIsClearNoWindow() {
        XCTAssertEqual(RitualState.make(todayLogged: true, requiresEmptyStomach: false, windowEnd: nil, meds: ["Thyroid"], now: now), .clear(meds: ["Thyroid"], hadWindow: false))
    }
    func testLoggedRybelsusBeforeWindowEndIsRunning() {
        XCTAssertEqual(RitualState.make(todayLogged: true, requiresEmptyStomach: true, windowEnd: later, meds: ["Thyroid"], now: now), .windowRunning(end: later, meds: ["Thyroid"]))
    }
    func testLoggedRybelsusAtWindowEndIsClear() {
        XCTAssertEqual(RitualState.make(todayLogged: true, requiresEmptyStomach: true, windowEnd: now, meds: [], now: now), .clear(meds: [], hadWindow: true))
    }
    func testLoggedRybelsusAfterWindowEndIsClear() {
        XCTAssertEqual(RitualState.make(todayLogged: true, requiresEmptyStomach: true, windowEnd: now, meds: [], now: later), .clear(meds: [], hadWindow: true))
    }
    func testLoggedRybelsusWithNoWindowEndFallsBackToClear() {
        XCTAssertEqual(RitualState.make(todayLogged: true, requiresEmptyStomach: true, windowEnd: nil, meds: [], now: now), .clear(meds: [], hadWindow: false))
    }
    func testClearMessageKeepsOrforglipronContrast() {
        XCTAssertEqual(RitualState.clearMessage(hadWindow: true), "You're clear — you can eat now")
        XCTAssertEqual(RitualState.clearMessage(hadWindow: false), "Logged — no empty-stomach window")
    }
}
