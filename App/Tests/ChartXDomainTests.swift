import XCTest
@testable import GLPill

final class ChartXDomainTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86400)
    }

    func testDomainPadsSlightlyPastLastEntryForShortSpan() {
        // 14-day span -> 15% pad (2.1 days) loses to the 3-day floor.
        let domain = ChartXDomain.weightTrendDomain(firstEntryDate: day(0), lastEntryDate: day(14))
        XCTAssertEqual(domain.lowerBound, day(0))
        XCTAssertEqual(domain.upperBound, day(14).addingTimeInterval(60 * 60 * 24 * 3))
    }

    func testDomainDoesNotStretchToFarProjectedDate() {
        // 84-day real span; a projected-completion mark ~120 days past the
        // last entry (the reported regression) must not enlarge the domain -
        // the real curve should occupy the vast majority of the axis.
        let domain = ChartXDomain.weightTrendDomain(firstEntryDate: day(0), lastEntryDate: day(84))
        let realSpan = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let fullSpanIncludingProjection = day(84).addingTimeInterval(120 * 60 * 60 * 24).timeIntervalSince(day(0))
        XCTAssertLessThan(realSpan, fullSpanIncludingProjection * 0.5)
    }

    func testDomainCollapsesToSinglePointWhenDatesInverted() {
        let domain = ChartXDomain.weightTrendDomain(firstEntryDate: day(10), lastEntryDate: day(5))
        XCTAssertEqual(domain.lowerBound, day(10))
        XCTAssertEqual(domain.upperBound, day(10))
    }
}
