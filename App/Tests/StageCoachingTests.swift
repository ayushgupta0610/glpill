import Testing
@testable import GLPill

struct StageCoachingTests {
    @Test("Switching message differs with empty-stomach requirement")
    func switchingVaries() {
        let withWindow = StageCoaching.message(stage: "switchingFromInjections", requiresEmptyStomach: true)
        let withoutWindow = StageCoaching.message(stage: "switchingFromInjections", requiresEmptyStomach: false)
        #expect(withWindow != nil)
        #expect(withoutWindow != nil)
        #expect(withWindow != withoutWindow)
    }

    @Test("aboutToStart and firstWeeks return a message")
    func startStagesNonNil() {
        #expect(StageCoaching.message(stage: "aboutToStart", requiresEmptyStomach: false) != nil)
        #expect(StageCoaching.message(stage: "firstWeeks", requiresEmptyStomach: false) != nil)
    }

    @Test("aWhile and nil produce no card")
    func noCardStages() {
        #expect(StageCoaching.message(stage: "aWhile", requiresEmptyStomach: true) == nil)
        #expect(StageCoaching.message(stage: nil, requiresEmptyStomach: true) == nil)
    }
}
