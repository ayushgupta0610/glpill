import Foundation
import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([
        Medication.self,
        TitrationStep.self,
        DoseLog.self,
        WeightEntry.self,
        SideEffectLog.self,
        IntakeDay.self,
        UserSettings.self,
    ])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    #if DEBUG
    /// Test-only full wipe, used by the -resetData launch argument.
    @MainActor
    static func wipe(_ container: ModelContainer) {
        let context = container.mainContext
        try? context.delete(model: Medication.self)
        try? context.delete(model: TitrationStep.self)
        try? context.delete(model: DoseLog.self)
        try? context.delete(model: WeightEntry.self)
        try? context.delete(model: SideEffectLog.self)
        try? context.delete(model: IntakeDay.self)
        try? context.delete(model: UserSettings.self)
        try? context.save()
    }
    #endif
}
