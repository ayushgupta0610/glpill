import XCTest
@testable import GLPill

final class ReportComposerTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var today: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 12))!)
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func makeInput(
        doseDays: [Date],
        weights: [(Date, Double)] = [],
        sideEffects: [(Date, String, Int)] = []
    ) -> ReportInput {
        ReportInput(
            medName: "Foundayo (orforglipron)",
            windowDays: 28,
            doseDays: doseDays,
            doses: doseDays.map { ($0, 0.8) },
            weights: weights,
            sideEffects: sideEffects,
            metric: true,
            today: today
        )
    }

    func testAdherenceLine() {
        let doseDays = (0...23).map { day(-$0) }
        let report = ReportComposer.compose(makeInput(doseDays: doseDays), calendar: calendar)
        XCTAssertTrue(report.contains("Adherence: 86% (24 of 28 days)"), report)
    }

    func testLongestGapLineWithHole() {
        // Dose every day in the 28-day window except a single 4-day hole
        // (day(-8)...day(-5)), so the longest gap is exactly 4.
        let hole: Set<Int> = [5, 6, 7, 8]
        let doseDays = (0...27).filter { !hole.contains($0) }.map { day(-$0) }
        let report = ReportComposer.compose(makeInput(doseDays: doseDays), calendar: calendar)
        XCTAssertTrue(report.contains("Longest gap: 4 days"), report)
    }

    func testLongestGapLineNone() {
        // Every day in the 28-day window is dosed.
        let doseDays = (0...27).map { day(-$0) }
        let report = ReportComposer.compose(makeInput(doseDays: doseDays), calendar: calendar)
        XCTAssertTrue(report.contains("Longest gap: none"), report)
    }

    func testWeightChangeLine() {
        let report = ReportComposer.compose(
            makeInput(doseDays: [day(0)], weights: [(day(-27), 90.0), (day(0), 87.5)]),
            calendar: calendar
        )
        XCTAssertTrue(report.contains("Weight change: -2.5 kg"), report)
    }

    func testSideEffectsSummaryAndNoneCase() {
        let withEffects = ReportComposer.compose(
            makeInput(doseDays: [day(0)], sideEffects: [(day(-1), "Nausea", 2), (day(-3), "Nausea", 1), (day(-2), "Fatigue", 3)]),
            calendar: calendar
        )
        XCTAssertTrue(withEffects.contains("Nausea: 2x (max severity 2/3)"), withEffects)
        XCTAssertTrue(withEffects.contains("Fatigue: 1x (max severity 3/3)"), withEffects)

        let without = ReportComposer.compose(makeInput(doseDays: [day(0)]), calendar: calendar)
        XCTAssertTrue(without.contains("None logged"), without)
    }

    func testHeaderMedNameDosesAndDisclaimerPresent() {
        let report = ReportComposer.compose(makeInput(doseDays: [day(0)]), calendar: calendar)
        XCTAssertTrue(report.contains("Foundayo (orforglipron)"))
        XCTAssertTrue(report.contains("0.8 mg"))
        XCTAssertTrue(report.contains("not medical advice"))
    }
}
