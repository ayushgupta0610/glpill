import XCTest
@testable import GLPill

final class MorningMedsTests: XCTestCase {
    func testTrimsDropsBlanksAndDedupesCaseInsensitively() {
        let input = ["  Thyroid ", "", "   ", "thyroid", "BP med", "BP med"]
        XCTAssertEqual(MorningMeds.normalize(input), ["Thyroid", "BP med"])
    }
    func testEmptyStaysEmpty() {
        XCTAssertEqual(MorningMeds.normalize([]), [])
        XCTAssertEqual(MorningMeds.normalize(["  ", ""]), [])
    }
    func testPreservesFirstSeenCasingAndOrder() {
        XCTAssertEqual(MorningMeds.normalize(["Levo", "aspirin", "LEVO"]), ["Levo", "aspirin"])
    }
}
