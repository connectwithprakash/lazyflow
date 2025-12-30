import Foundation
import UserNotifications

/// Service responsible for managing local notifications for task reminders
final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Schedule Notifications

    /// Schedule a reminder notification for a task
    func scheduleTaskReminder(taskID: UUID, title: String, reminderDate: Date) {
        // Don't schedule if the date is in the past
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = title
        content.sound = .default
        content.badge = 1
        content.userInfo = ["taskID": taskID.uuidString]
        content.categoryIdentifier = "TASK_REMINDER"

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: taskID.uuidString,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    /// Schedule a smart reminder (e.g., morning reminder for tasks without time)
    func scheduleSmartReminder(taskID: UUID, title: String, dueDate: Date) {
        let calendar = Calendar.current

        // Schedule for 9 AM on the due date
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        guard let reminderDate = calendar.date(from: components),
              reminderDate > Date() else { return }

        scheduleTaskReminder(taskID: taskID, title: title, reminderDate: reminderDate)
    }

    /// Schedule a reminder before the task time (e.g., 15 minutes before)
    func scheduleBeforeReminder(taskID: UUID, title: String, taskTime: Date, minutesBefore: Int = 15) {
        guard let reminderDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: taskTime),
              reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Task"
        content.body = "\(title) starts in \(minutesBefore) minutes"
        content.sound = .default
        content.userInfo = ["taskID": taskID.uuidString]
        content.categoryIdentifier = "TASK_UPCOMING"

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "\(taskID.uuidString)-before",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule before notification: \(error)")
            }
        }
    }

    // MARK: - Cancel Notifications

    /// Cancel a specific task reminder
    func cancelTaskReminder(taskID: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            taskID.uuidString,
            "\(taskID.uuidString)-before"
        ])
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Badge Management

    /// Clear the notification badge
    func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    /// Update badge count to reflect pending tasks
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    // MARK: - Notification Categories

    /// Register notification categories with actions
    func registerNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.authenticationRequired]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze (1 hour)",
            options: []
        )

        let taskReminderCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let taskUpcomingCategory = UNNotificationCategory(
            identifier: "TASK_UPCOMING",
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([taskReminderCategory, taskUpcomingCategory])
    }
}
