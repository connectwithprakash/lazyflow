import Foundation
import UserNotifications
import LazyflowCore

/// Protocol defining the public API surface of NotificationService consumed by services.
protocol NotificationServiceProtocol: AnyObject, Sendable {
    // MARK: - Permission

    func requestPermission() async -> Bool
    func checkPermissionStatus() async -> UNAuthorizationStatus

    // MARK: - Task Reminders

    func scheduleTaskReminder(taskID: UUID, title: String, reminderDate: Date)
    func scheduleSmartReminder(taskID: UUID, title: String, dueDate: Date)
    func scheduleBeforeReminder(taskID: UUID, title: String, taskTime: Date, minutesBefore: Int)

    // MARK: - Intraday Reminders

    func scheduleIntradayReminders(for task: Task)
    func rescheduleAllIntradayReminders(tasks: [Task])
    func cancelIntradayReminders(for taskID: UUID)
    func cancelNextIntradayReminder(for taskID: UUID)

    // MARK: - Daily Summary

    func scheduleDailySummaryReminder(hour: Int, minute: Int)
    func cancelDailySummaryReminder()

    // MARK: - Morning Briefing

    func scheduleMorningBriefing(hour: Int, minute: Int)
    func cancelMorningBriefing()

    // MARK: - Cancellation

    func cancelTaskReminder(taskID: UUID)
    func cancelAllNotifications()

    // MARK: - Badge Management

    func clearBadge()
    func updateBadgeCount(_ count: Int)

    // MARK: - Setup

    func registerNotificationCategories()
}

// MARK: - Default Parameter Values

extension NotificationServiceProtocol {
    func scheduleBeforeReminder(taskID: UUID, title: String, taskTime: Date, minutesBefore: Int = 15) {
        scheduleBeforeReminder(taskID: taskID, title: title, taskTime: taskTime, minutesBefore: minutesBefore)
    }
}
