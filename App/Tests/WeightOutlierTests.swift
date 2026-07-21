import Testing
@testable import GLPill

struct WeightOutlierTests {
    @Test("Flags a jump greater than 25%")
    func flagsLargeJump() {
        #expect(WeightOutlier.isSuspicious(newKg: 130, lastKg: 90))
        #expect(WeightOutlier.isSuspicious(newKg: 60, lastKg: 90))
    }

    @Test("Does not flag a change within 25%")
    func withinTolerance() {
        #expect(!WeightOutlier.isSuspicious(newKg: 92, lastKg: 90))
        #expect(!WeightOutlier.isSuspicious(newKg: 90, lastKg: 90))
        // exactly 25% is the boundary and not suspicious
        #expect(!WeightOutlier.isSuspicious(newKg: 112.5, lastKg: 90))
    }

    @Test("First-ever entry is never suspicious")
    func firstEntry() {
        #expect(!WeightOutlier.isSuspicious(newKg: 90, lastKg: nil))
        #expect(!WeightOutlier.isSuspicious(newKg: 500, lastKg: nil))
    }
}
