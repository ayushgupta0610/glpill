import Testing
@testable import GLPill

struct TodayLayoutTests {
    @Test("Empty goals give the default order")
    func emptyGoals() {
        #expect(TodayLayout.sections(goals: []) == [.medLevel, .streak, .intake, .sideEffects])
    }

    @Test("sideEffects goal floats the side-effect section to the front, no duplicate")
    func sideEffectsGoalLeads() {
        let out = TodayLayout.sections(goals: ["sideEffects"])
        #expect(out.first == .sideEffects)
        #expect(out.filter { $0 == .sideEffects }.count == 1)
        #expect(out == [.sideEffects, .medLevel, .streak, .intake])
    }

    @Test("weight and doctor goals lead with their shortcuts in order")
    func weightAndDoctorLead() {
        let out = TodayLayout.sections(goals: ["weight", "doctor"])
        #expect(Array(out.prefix(2)) == [.weightShortcut, .reportShortcut])
    }

    @Test("No duplicate sideEffects even when requested")
    func noDuplicateSideEffects() {
        let out = TodayLayout.sections(goals: ["sideEffects"])
        #expect(out.filter { $0 == .sideEffects }.count == 1)
    }
}
