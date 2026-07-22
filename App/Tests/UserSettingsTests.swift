import Testing
import SwiftData
@testable import GLPill

@MainActor
struct UserSettingsTests {
    @Test("New fields default safely for existing installs")
    func defaults() {
        let s = UserSettings()
        #expect(s.waitWindowMinutes == 30)
        #expect(s.onboardingStage == nil)
        #expect(s.sideEffectConcerns.isEmpty)
        #expect(s.goals.isEmpty)
        #expect(s.reminderStyle == "full")
        #expect(s.coachingDismissed == false)
    }
}
