import Testing
import Foundation
@testable import GLPill

struct MedicationLevelTests {
    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    @Test("Empty log yields an empty curve")
    func empty() {
        #expect(MedicationLevel.curve(doses: [], halfLifeHours: 168, samples: 10, now: day(5)).isEmpty)
    }
    @Test("All-zero (unknown) doses yield an empty curve, never a flat-zero line")
    func allZeroDosesEmpty() {
        let doses = (0..<4).map { (date: day($0), mg: 0.0) }
        #expect(MedicationLevel.curve(doses: doses, halfLifeHours: 168, samples: 10, now: day(3)).isEmpty)
    }
    @Test("hasEnoughData is false when every point is at zero level")
    func allZeroLevelsNotEnough() {
        let d0 = Date(timeIntervalSince1970: 0)
        let flat = (0..<4).map { MedicationLevel.Point(date: d0.addingTimeInterval(Double($0) * 86_400), level: 0) }
        #expect(MedicationLevel.hasEnoughData(points: flat) == false)
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
    @Test("timeToSteadyStateText is drug-derived (5 half-lives)")
    func steadyStateText() {
        #expect(MedicationLevel.timeToSteadyStateText(for: .foundayo) == "about a week")
        #expect(MedicationLevel.timeToSteadyStateText(for: .rybelsus) == "about 4–5 weeks")
        #expect(MedicationLevel.timeToSteadyStateText(for: .wegovyPill) == "about 4–5 weeks")
        #expect(MedicationLevel.timeToSteadyStateText(for: .custom) == "about 3 weeks")
    }

    @Test("isNearSteadyState: elapsed >= 3 half-lives")
    func nearSteadyState() {
        let now = day(30)
        let semaHalf = MedicationLevel.halfLifeHours(for: .rybelsus) // 168h = 7d
        // 2 days elapsed for semaglutide -> not near steady state
        #expect(MedicationLevel.isNearSteadyState(firstDose: now.addingTimeInterval(-2 * 86_400), now: now, halfLifeHours: semaHalf) == false)
        // 25 days elapsed for semaglutide (3 * 7 = 21d threshold) -> near steady state
        #expect(MedicationLevel.isNearSteadyState(firstDose: now.addingTimeInterval(-25 * 86_400), now: now, halfLifeHours: semaHalf) == true)
        // orforglipron 40h = ~1.67d, threshold 3 * 1.67 = 5d; 6 days elapsed -> true
        let orfoHalf = MedicationLevel.halfLifeHours(for: .foundayo)
        #expect(MedicationLevel.isNearSteadyState(firstDose: now.addingTimeInterval(-6 * 86_400), now: now, halfLifeHours: orfoHalf) == true)
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
