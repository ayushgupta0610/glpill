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

    static func scheduleEatTimer(using scheduler: NotificationScheduling) {
        scheduler.add(
            id: eatTimerId,
            title: "You can eat now ✅",
            body: "30 minutes are up — enjoy your meal.",
            trigger: .once(after: 30 * 60)
        )
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
