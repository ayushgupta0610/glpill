import Testing
import SwiftData
@testable import GLPill

@MainActor struct TodayStoreIntakeTests {
    private func ctx() throws -> ModelContext {
        ModelContext(try ModelContainer(for: IntakeDay.self, configurations: .init(isStoredInMemoryOnly: true)))
    }
    @Test("setProtein sets an absolute clamped value, creating the day")
    func setProtein() throws {
        let c = try ctx(); let s = TodayStore(context: c)
        try s.setProtein(grams: 60)
        #expect(try c.fetch(FetchDescriptor<IntakeDay>()).first?.proteinGrams == 60)
        try s.setProtein(grams: -5)
        #expect(try c.fetch(FetchDescriptor<IntakeDay>()).first?.proteinGrams == 0)
    }
    @Test("setWater sets an absolute clamped value")
    func setWater() throws {
        let c = try ctx(); let s = TodayStore(context: c)
        try s.setWater(ml: 500)
        #expect(try c.fetch(FetchDescriptor<IntakeDay>()).first?.waterMl == 500)
    }
}
