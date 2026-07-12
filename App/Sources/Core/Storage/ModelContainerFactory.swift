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
        let container = try ModelContainer(for: schema, configurations: [configuration])
        if !inMemory {
            hardenFileProtection(storeURL: configuration.url)
        }
        return container
    }

    /// Health data deserves NSFileProtectionComplete (encrypted whenever the
    /// device is locked). SwiftData has no first-class knob for this on iOS 17,
    /// so set it on the SQLite store and its sidecar files; failure is
    /// non-fatal — iOS's default (CompleteUntilFirstUserAuthentication) still applies.
    private static func hardenFileProtection(storeURL: URL) {
        let paths = [storeURL.path, storeURL.path + "-wal", storeURL.path + "-shm"]
        for path in paths where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: path
            )
        }
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
