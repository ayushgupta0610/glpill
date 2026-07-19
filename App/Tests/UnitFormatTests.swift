import XCTest
@testable import GLPill

final class UnitFormatTests: XCTestCase {
    func testWeightStringMetric() {
        XCTAssertEqual(UnitFormat.weightString(kilograms: 72.5, metric: true), "72.5 kg")
    }

    func testWeightStringImperial() {
        XCTAssertEqual(UnitFormat.weightString(kilograms: 72.5, metric: false), "159.8 lb")
    }

    func testKilogramsFromDisplayMetricPassthrough() {
        XCTAssertEqual(UnitFormat.kilograms(fromDisplay: 80, metric: true), 80, accuracy: 0.0001)
    }

    func testKilogramsFromDisplayImperialConverts() {
        XCTAssertEqual(UnitFormat.kilograms(fromDisplay: 200, metric: false), 90.718474, accuracy: 0.0001)
    }

    func testWeightValidation() {
        XCTAssertTrue(UnitFormat.isValidWeight(kilograms: 80))
        XCTAssertTrue(UnitFormat.isValidWeight(kilograms: 25))
        XCTAssertTrue(UnitFormat.isValidWeight(kilograms: 500))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 24.9))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 500.1))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 0))
    }

    func testValidWeightBoundaries() {
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 0))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 24.9))
        XCTAssertTrue(UnitFormat.isValidWeight(kilograms: 25))
        XCTAssertTrue(UnitFormat.isValidWeight(kilograms: 500))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: 500.1))
        XCTAssertFalse(UnitFormat.isValidWeight(kilograms: -70))
    }

    func testValidDoseBoundaries() {
        XCTAssertFalse(UnitFormat.isValidDose(mg: 0))
        XCTAssertFalse(UnitFormat.isValidDose(mg: 0.04))
        XCTAssertTrue(UnitFormat.isValidDose(mg: 0.05))
        XCTAssertTrue(UnitFormat.isValidDose(mg: 50))
        XCTAssertFalse(UnitFormat.isValidDose(mg: 50.1))
    }
}
