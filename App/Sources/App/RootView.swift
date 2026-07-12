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
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.heroGradient)
            ProgressView()
        }
    }
}
