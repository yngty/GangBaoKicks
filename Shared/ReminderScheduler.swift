import Foundation
import UserNotifications

struct ReminderClockTime: Codable, Hashable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    var minutesFromMidnight: Int {
        hour * 60 + minute
    }

    static let defaultEvening = ReminderClockTime(hour: 20, minute: 0)
}

struct ReminderScheduler {
    private static let reminderID = "gangbao.dailyKickReminder"
    private static let reminderIDPrefix = "gangbao.dailyKickReminder."

    static func scheduleDailyReminders(times: [ReminderClockTime]) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])

        await removeExistingReminderRequests(from: center)
        guard granted else { return }

        let uniqueTimes = Array(Set(times)).sorted { lhs, rhs in
            lhs.minutesFromMidnight < rhs.minutesFromMidnight
        }

        for time in uniqueTimes {
            var date = DateComponents()
            date.hour = time.hour
            date.minute = time.minute

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("notification.title", comment: "Reminder title")
            content.body = NSLocalizedString("notification.body", comment: "Reminder body")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(reminderIDPrefix)\(time.hour)-\(time.minute)",
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    static func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        try await scheduleDailyReminders(times: [ReminderClockTime(hour: hour, minute: minute)])
    }

    static func cancelDailyReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter {
                $0 == reminderID || $0.hasPrefix(reminderIDPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func cancelDailyReminder() {
        cancelDailyReminders()
    }

    private static func removeExistingReminderRequests(from center: UNUserNotificationCenter) async {
        let requests = await pendingRequests(from: center)
        let ids = requests.map(\.identifier).filter {
            $0 == reminderID || $0.hasPrefix(reminderIDPrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func pendingRequests(from center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
