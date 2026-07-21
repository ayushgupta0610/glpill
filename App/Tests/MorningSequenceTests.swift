import Testing
import Foundation
@testable import GLPill

struct MorningSequenceTests {
    private let clear = Date(timeIntervalSince1970: 1_000_000)
    @Test("Pill + meds produce ordered steps with a window")
    func withMeds() {
        let steps = MorningSequence.make(pillTaken: true, pillName: "Foundayo", hadWindow: true, clearTime: clear, meds: ["Levothyroxine"])
        #expect(steps.count == 3)
        #expect(steps[0].title == "Foundayo")
        #expect(steps[0].done == true)
        #expect(steps[1].title == "Levothyroxine")
        #expect(steps[2].title == "Breakfast")
    }
    @Test("No empty-stomach window drops the wait framing")
    func noWindow() {
        let steps = MorningSequence.make(pillTaken: false, pillName: "Foundayo", hadWindow: false, clearTime: nil, meds: [])
        #expect(steps.count == 1)
        #expect(steps[0].done == false)
        #expect(steps[0].subtitle == nil)
    }
}
