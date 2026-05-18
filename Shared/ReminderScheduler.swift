import Foundation
import UserNotifications

struct ReminderScheduler {
    static let reminderID = "gangbao.dailyKickReminder"

    static func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return }

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.title", comment: "Reminder title")
        content.body = NSLocalizedString("notification.body", comment: "Reminder body")
        content.sound = .default

        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        try await center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}
