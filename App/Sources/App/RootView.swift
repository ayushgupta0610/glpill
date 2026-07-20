import SwiftUI
import SwiftData

struct RootView: View {
    var storageFailed = false
    @Environment(SubscriptionStore.self) private var subscriptions
    @Query private var settingsList: [UserSettings]

    private var onboardingComplete: Bool {
        settingsList.first?.onboardingComplete ?? false
    }

    var body: some View {
        Group {
            if !onboardingComplete {
                OnboardingFlow()
            } else if subscriptions.isUnlocked {
                MainTabView()
            } else if subscriptions.state == .unknown {
                loadingSplash
            } else {
                PaywallView()
            }
        }
        .safeAreaInset(edge: .top) {
            if storageFailed {
                Text("Storage unavailable — data won't be saved. Free up space and relaunch.")
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.warn, in: Capsule())
                    .padding(.horizontal)
            }
        }
    }

    private var loadingSplash: some View {
        LoadingSplashView()
    }
}

private struct LoadingSplashView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var showRetry = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.heroGradient)
            ProgressView()
            if showRetry {
                VStack(spacing: 8) {
                    Text("Taking longer than expected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Tap to retry") {
                        retry()
                    }
                    .buttonStyle(.bordered)
                }
                .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            showRetry = true
        }
    }

    private func retry() {
        showRetry = false
        Task {
            async let refreshTask: Void = subscriptions.refresh()
            async let productsTask: Void = subscriptions.loadProducts()
            _ = await (refreshTask, productsTask)
        }
    }
}
