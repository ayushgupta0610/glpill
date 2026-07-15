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

    static let cloudKitContainerID = "iCloud.com.ayushgupta.glpill"

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }

        // The Simulator can't apply the CloudKit entitlement, so SwiftData's
        // CloudKit mirroring setup traps at launch (PFCloudKitContainerProvider).
        // Always use the local store there; real devices still sync via CloudKit.
        #if targetEnvironment(simulator)
        let cloudDisabled = true
        #elseif DEBUG
        let cloudDisabled = ProcessInfo.processInfo.arguments.contains("-disableCloudKit")
        #else
        let cloudDisabled = false
        #endif

        // Sync privately through the user's OWN iCloud (CloudKit private database).
        // We run no servers and never see the data: it lives on the device and in
        // the user's private iCloud, keyed to their Apple ID. This is what lets a
        // paid user reinstall or switch phones without losing their history.
        if !cloudDisabled {
            do {
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private(cloudKitContainerID)
                )
                let container = try ModelContainer(for: schema, configurations: [cloudConfig])
                hardenFileProtection(storeURL: cloudConfig.url)
                return container
            } catch {
                // CloudKit unavailable (e.g. unsigned dev build with no iCloud
                // container provisioned) — fall back to a local-only store so the
                // app always works. Data still persists on device.
            }
        }

        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [localConfig])
        hardenFileProtection(storeURL: localConfig.url)
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
