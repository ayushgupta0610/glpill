import SwiftUI
import SwiftData

@main
struct GLPillApp: App {
    private let container: ModelContainer
    private let storageFailed: Bool

    init() {
        do {
            container = try ModelContainerFactory.make()
            storageFailed = false
        } catch {
            // In-memory fallback keeps the app usable; RootView surfaces a warning.
            container = try! ModelContainerFactory.make(inMemory: true)
            storageFailed = true
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            ModelContainerFactory.wipe(container)
            UserDefaults.standard.removeObject(forKey: "eatTimerEnd")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(storageFailed: storageFailed)
                .tint(Theme.primary)
                .task {
                    // Collapse CloudKit-synced duplicates before any read so
                    // `.first` on UserSettings/Medication is deterministic.
                    ModelMaintenance.deduplicate(in: container.mainContext)
                    WidgetSnapshotBuilder.refresh(context: container.mainContext)
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-exportCards") {
                        ShareCardExporter.exportSamples()
                    }
                    if ProcessInfo.processInfo.arguments.contains("-exportScreenshots") {
                        ScreenshotExporter.export()
                    }
                    #endif
                }
        }
        .modelContainer(container)
    }
}
