import Foundation
import UserNotifications

enum ReminderTrigger: Equatable {
    case daily(hour: Int, minute: Int)
    case once(after: TimeInterval)
}

protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
    func removePending(ids: [String])
    func add(id: String, title: String, body: String, trigger: ReminderTrigger)
    func pendingIds() async -> [String]
}

enum ReminderScheduler {
    static let dailyId = "glpill.daily"
    static let eatTimerId = "glpill.eattimer"

    static func scheduleDaily(hour: Int, minute: Int, using scheduler: NotificationScheduling) {
        scheduler.removePending(ids: [dailyId])
        scheduler.add(
            id: dailyId,
            title: "Pill time 💊",
            body: "Take your GLP-1 pill and keep the streak going.",
            trigger: .daily(hour: hour, minute: minute)
        )
    }

    static func eatTimerBody(waitWindowMinutes: Int = 30, meds: [String]) -> String {
        let base = "Your \(waitWindowMinutes)-minute wait is up — you can eat now."
        guard !meds.isEmpty else { return base }
        return base + " You can also take your \(meds.joined(separator: ", ")) now."
    }

    static func scheduleEatTimer(using scheduler: NotificationScheduling, waitWindowMinutes: Int = 30, meds: [String] = []) {
        scheduler.add(
            id: eatTimerId,
            title: "You can eat now ✅",
            body: eatTimerBody(waitWindowMinutes: waitWindowMinutes, meds: meds),
            trigger: .once(after: Double(waitWindowMinutes) * 60)
        )
    }

    /// If the daily reminder isn't already pending, (re)schedule it. Used at launch to
    /// re-assert reminders for already-onboarded users (upgrades, new devices) whose
    /// pending requests were never persisted across installs. Only reschedules when
    /// already authorized — never prompts.
    static func ensureDailyScheduled(hour: Int, minute: Int, using scheduler: NotificationScheduling) async {
        let pending = await scheduler.pendingIds()
        guard !pending.contains(dailyId) else { return }
        scheduleDaily(hour: hour, minute: minute, using: scheduler)
    }
}

final class UNNotificationScheduler: NotificationScheduling {
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func removePending(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func pendingIds() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    /// Current authorization status, read without prompting.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func add(id: String, title: String, body: String, trigger: ReminderTrigger) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let unTrigger: UNNotificationTrigger
        switch trigger {
        case .daily(let hour, let minute):
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            unTrigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .once(let interval):
            unTrigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: unTrigger)
        UNUserNotificationCenter.current().add(request)
    }
}
