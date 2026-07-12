import SwiftUI
import SwiftData

@main
struct GLPillApp: App {
    private let container: ModelContainer
    private let storageFailed: Bool
    @State private var subscriptions = SubscriptionStore()

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
        if ProcessInfo.processInfo.arguments.contains("-uiTestUnlocked") {
            _subscriptions = State(initialValue: SubscriptionStore(provider: AlwaysActiveProvider()))
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(storageFailed: storageFailed)
                .environment(subscriptions)
                .tint(Theme.primary)
                .task {
                    _ = subscriptions.startTransactionListener()
                    await subscriptions.refresh()
                    await subscriptions.loadProducts()
                }
        }
        .modelContainer(container)
    }
}
