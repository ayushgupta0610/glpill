import SwiftUI
import SwiftData
import UserNotifications

struct RootView: View {
    var storageFailed = false
    @Query(sort: \UserSettings.createdAt) private var settingsList: [UserSettings]

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
        .task {
            await reassertDailyReminderIfNeeded()
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

    /// On launch, re-assert the daily reminder for an already-onboarded user who wants
    /// reminders and has already granted notification permission. Covers upgrades and
    /// new devices where the pending request was never carried over. Never prompts.
    private func reassertDailyReminderIfNeeded() async {
        guard let settings = settingsList.first,
              settings.onboardingComplete,
              settings.reminderStyle != "none" else { return }
        let scheduler = UNNotificationScheduler()
        guard await scheduler.authorizationStatus() == .authorized else { return }
        await ReminderScheduler.ensureDailyScheduled(
            hour: settings.reminderHour,
            minute: settings.reminderMinute,
            using: scheduler
        )
    }
}
