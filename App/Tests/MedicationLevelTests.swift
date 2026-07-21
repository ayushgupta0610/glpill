import Testing
import Foundation
@testable import GLPill

struct MedicationLevelTests {
    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    @Test("Empty log yields an empty curve")
    func empty() {
        #expect(MedicationLevel.curve(doses: [], halfLifeHours: 168, samples: 10, now: day(5)).isEmpty)
    }
    @Test("Daily dosing climbs monotonically toward steady state")
    func climbs() {
        let doses = (0..<7).map { (date: day($0), mg: 7.0) }
        let curve = MedicationLevel.curve(doses: doses, halfLifeHours: 168, samples: 7, now: day(6))
        for i in 1..<curve.count { #expect(curve[i].level >= curve[i - 1].level) }
        #expect(curve.last!.level > curve.first!.level)
    }
    @Test("Half-life decay: one dose halves after one half-life")
    func decay() {
        let start = day(0)
        let curve = MedicationLevel.curve(doses: [(date: start, mg: 10)], halfLifeHours: 24, samples: 2, now: start.addingTimeInterval(24 * 3600))
        #expect(abs(curve.last!.level - 5) < 0.01)
    }
    @Test("Half-life constants per kind")
    func halfLives() {
        #expect(MedicationLevel.halfLifeHours(for: .rybelsus) == 168)
        #expect(MedicationLevel.halfLifeHours(for: .wegovyPill) == 168)
        #expect(MedicationLevel.halfLifeHours(for: .foundayo) == 40)
    }
    @Test("hasEnoughData needs >=3 points spanning >=2 days")
    func enough() {
        let d0 = Date(timeIntervalSince1970: 0)
        let sparse = [MedicationLevel.Point(date: d0, level: 1), MedicationLevel.Point(date: d0.addingTimeInterval(3600), level: 2)]
        #expect(MedicationLevel.hasEnoughData(points: sparse) == false)
        let enough = (0..<4).map { MedicationLevel.Point(date: d0.addingTimeInterval(Double($0)*86_400), level: Double($0)) }
        #expect(MedicationLevel.hasEnoughData(points: enough) == true)
    }
    @Test("projection climbs for a positive daily dose and is empty for zero")
    func projection() {
        let start = Date(timeIntervalSince1970: 0)
        let p = MedicationLevel.projection(dailyDoseMg: 7, halfLifeHours: 168, days: 7, samples: 14, startingFrom: start)
        #expect(p.count == 14)
        #expect(p.last!.level > p.first!.level)
        #expect(MedicationLevel.projection(dailyDoseMg: 0, halfLifeHours: 168, days: 7, samples: 14, startingFrom: start).isEmpty)
    }
}
