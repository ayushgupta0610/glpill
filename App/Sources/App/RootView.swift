import SwiftUI
import SwiftData

struct RootView: View {
    var storageFailed = false
    @Query private var settingsList: [UserSettings]

    private var onboardingComplete: Bool {
        settingsList.first?.onboardingComplete ?? false
    }

    var body: some View {
        Group {
            if !onboardingComplete {
                OnboardingFlow()
            } else {
                MainTabView()
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
}
