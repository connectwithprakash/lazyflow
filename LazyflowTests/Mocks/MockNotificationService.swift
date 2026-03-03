import Foundation
import UserNotifications
@testable import Lazyflow

/// No-op mock of NotificationServiceProtocol that records method calls.
final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private(set) var calls: [String] = []

    func requestPermission() async -> Bool {
        calls.append("requestPermission")
        return true
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        calls.append("checkPermissionStatus")
        return .authorized
    }

    func scheduleTaskReminder(taskID: UUID, title: String, reminderDate: Date) {
        calls.append("scheduleTaskReminder")
    }

    func scheduleSmartReminder(taskID: UUID, title: String, dueDate: Date) {
        calls.append("scheduleSmartReminder")
    }

    func scheduleBeforeReminder(taskID: UUID, title: String, taskTime: Date, minutesBefore: Int) {
        calls.append("scheduleBeforeReminder")
    }

    func scheduleIntradayReminders(for task: Task) {
        calls.append("scheduleIntradayReminders")
    }

    func rescheduleAllIntradayReminders(tasks: [Task]) {
        calls.append("rescheduleAllIntradayReminders")
    }

    func cancelIntradayReminders(for taskID: UUID) {
        calls.append("cancelIntradayReminders")
    }

    func cancelNextIntradayReminder(for taskID: UUID) {
        calls.append("cancelNextIntradayReminder")
    }

    func scheduleDailySummaryReminder(hour: Int, minute: Int) {
        calls.append("scheduleDailySummaryReminder")
    }

    func cancelDailySummaryReminder() {
        calls.append("cancelDailySummaryReminder")
    }

    func scheduleMorningBriefing(hour: Int, minute: Int) {
        calls.append("scheduleMorningBriefing")
    }

    func cancelMorningBriefing() {
        calls.append("cancelMorningBriefing")
    }

    func cancelTaskReminder(taskID: UUID) {
        calls.append("cancelTaskReminder")
    }

    func cancelAllNotifications() {
        calls.append("cancelAllNotifications")
    }

    func clearBadge() {
        calls.append("clearBadge")
    }

    func updateBadgeCount(_ count: Int) {
        calls.append("updateBadgeCount")
    }

    func registerNotificationCategories() {
        calls.append("registerNotificationCategories")
    }
}
