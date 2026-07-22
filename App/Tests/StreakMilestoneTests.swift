import Testing
@testable import GLPill

struct StreakMilestoneTests {
    @Test("Day-by-day path fires the tier it just reached")
    func dayByDayHitsSeven() {
        #expect(StreakMilestone.newlyReached(streak: 7, lastCelebrated: 0) == 7)
    }

    @Test("A jump past multiple tiers returns the lowest un-celebrated tier, not the highest")
    func jumpReturnsLowest() {
        // streak 5 → 100 must not skip 7 and 30.
        #expect(StreakMilestone.newlyReached(streak: 100, lastCelebrated: 0) == 7)
    }

    @Test("Successive logs walk the tiers up one at a time")
    func walksUpTiers() {
        #expect(StreakMilestone.newlyReached(streak: 100, lastCelebrated: 7) == 30)
        #expect(StreakMilestone.newlyReached(streak: 100, lastCelebrated: 30) == 100)
        #expect(StreakMilestone.newlyReached(streak: 100, lastCelebrated: 100) == nil)
    }

    @Test("No milestone before the first threshold")
    func noneBeforeSeven() {
        #expect(StreakMilestone.newlyReached(streak: 6, lastCelebrated: 0) == nil)
    }

    @Test("Full walk from a big jump eventually reaches every tier")
    func fullWalk() {
        var celebrated = 0
        var reached: [Int] = []
        while let m = StreakMilestone.newlyReached(streak: 365, lastCelebrated: celebrated) {
            reached.append(m)
            celebrated = m
        }
        #expect(reached == [7, 30, 100, 365])
    }
}
