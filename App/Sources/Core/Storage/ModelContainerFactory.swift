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
}
