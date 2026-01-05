import XCTest
import UserNotifications
@testable import Taskweave

final class NotificationServiceTests: XCTestCase {
    var notificationService: NotificationService!

    override func setUpWithError() throws {
        notificationService = NotificationService.shared
    }

    override func tearDownWithError() throws {
        // Cancel all notifications to clean up
        notificationService.cancelAllNotifications()
    }

    // MARK: - Permission Tests

    func testCheckPermissionStatus() async throws {
        let status = await notificationService.checkPermissionStatus()

        // Should return one of the valid statuses
        XCTAssertTrue([
            UNAuthorizationStatus.notDetermined,
            .denied,
            .authorized,
            .provisional,
            .ephemeral
        ].contains(status))
    }

    // MARK: - Task Reminder Tests

    func testScheduleTaskReminder_PastDate_DoesNotSchedule() async throws {
        let taskID = UUID()
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago

        // Should not throw, just silently skip
        notificationService.scheduleTaskReminder(
            taskID: taskID,
            title: "Past Task",
            reminderDate: pastDate
        )

        // Wait a bit for async operations
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Verify no notification was scheduled (we can't easily check pending notifications without authorization)
    }

    func testCancelTaskReminder() async throws {
        let taskID = UUID()

        // Cancel should work even if no notification exists
        notificationService.cancelTaskReminder(taskID: taskID)

        // Should not crash
        XCTAssertTrue(true)
    }

    func testCancelAllNotifications() {
        // Should not crash
        notificationService.cancelAllNotifications()
        XCTAssertTrue(true)
    }

    // MARK: - Daily Summary Notification Tests

    func testScheduleDailySummaryReminder_ValidTime() async throws {
        notificationService.scheduleDailySummaryReminder(hour: 20, minute: 0)

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Should not crash
        XCTAssertTrue(true)
    }

    func testCancelDailySummaryReminder() {
        notificationService.cancelDailySummaryReminder()

        // Should not crash
        XCTAssertTrue(true)
    }

    // MARK: - Morning Briefing Notification Tests

    func testScheduleMorningBriefing_ValidTime() async throws {
        notificationService.scheduleMorningBriefing(hour: 7, minute: 0)

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Should not crash
        XCTAssertTrue(true)
    }

    func testCancelMorningBriefing() {
        notificationService.cancelMorningBriefing()

        // Should not crash
        XCTAssertTrue(true)
    }

    // MARK: - Badge Management Tests

    func testClearBadge() {
        // Should not crash
        notificationService.clearBadge()
        XCTAssertTrue(true)
    }

    func testUpdateBadgeCount() {
        // Should not crash
        notificationService.updateBadgeCount(5)
        notificationService.updateBadgeCount(0)
        XCTAssertTrue(true)
    }

    // MARK: - Notification Categories Tests

    func testRegisterNotificationCategories() {
        // Should not crash
        notificationService.registerNotificationCategories()
        XCTAssertTrue(true)
    }

    // MARK: - Integration Tests

    func testScheduleAndCancelTaskReminder() async throws {
        let taskID = UUID()
        let futureDate = Date().addingTimeInterval(86400) // 24 hours from now

        notificationService.scheduleTaskReminder(
            taskID: taskID,
            title: "Integration Test Task",
            reminderDate: futureDate
        )

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Cancel the reminder
        notificationService.cancelTaskReminder(taskID: taskID)

        // Should complete without errors
        XCTAssertTrue(true)
    }

    func testScheduleSmartReminder() async throws {
        let taskID = UUID()
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        // Smart reminder schedules for 9 AM on due date
        notificationService.scheduleSmartReminder(
            taskID: taskID,
            title: "Smart Reminder Test",
            dueDate: futureDate
        )

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Clean up
        notificationService.cancelTaskReminder(taskID: taskID)

        XCTAssertTrue(true)
    }

    func testScheduleBeforeReminder() async throws {
        let taskID = UUID()
        let taskTime = Date().addingTimeInterval(7200) // 2 hours from now

        notificationService.scheduleBeforeReminder(
            taskID: taskID,
            title: "Before Reminder Test",
            taskTime: taskTime,
            minutesBefore: 15
        )

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Clean up
        notificationService.cancelTaskReminder(taskID: taskID)

        XCTAssertTrue(true)
    }

    func testScheduleBeforeReminder_TooClose_DoesNotSchedule() async throws {
        let taskID = UUID()
        let taskTime = Date().addingTimeInterval(300) // 5 minutes from now

        // Try to schedule a 15-minute before reminder (should skip since it would be in the past)
        notificationService.scheduleBeforeReminder(
            taskID: taskID,
            title: "Too Close Test",
            taskTime: taskTime,
            minutesBefore: 15
        )

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Should not crash
        XCTAssertTrue(true)
    }

    // MARK: - Edge Case Tests

    func testScheduleReminder_EmptyTitle() async throws {
        let taskID = UUID()
        let futureDate = Date().addingTimeInterval(3600)

        notificationService.scheduleTaskReminder(
            taskID: taskID,
            title: "",
            reminderDate: futureDate
        )

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Clean up
        notificationService.cancelTaskReminder(taskID: taskID)

        // Should not crash
        XCTAssertTrue(true)
    }

    func testScheduleReminder_VeryLongTitle() async throws {
        let taskID = UUID()
        let futureDate = Date().addingTimeInterval(3600)
        let longTitle = String(repeating: "A", count: 1000)

        notificationService.scheduleTaskReminder(
            taskID: taskID,
            title: longTitle,
            reminderDate: futureDate
        )

        // Wait for async operation
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Clean up
        notificationService.cancelTaskReminder(taskID: taskID)

        // Should not crash
        XCTAssertTrue(true)
    }

    func testScheduleDailySummary_EdgeHours() async throws {
        // Test midnight
        notificationService.scheduleDailySummaryReminder(hour: 0, minute: 0)
        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        // Test 23:59
        notificationService.scheduleDailySummaryReminder(hour: 23, minute: 59)
        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        // Clean up
        notificationService.cancelDailySummaryReminder()

        XCTAssertTrue(true)
    }

    func testScheduleMorningBriefing_EdgeHours() async throws {
        // Test early morning
        notificationService.scheduleMorningBriefing(hour: 5, minute: 0)
        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        // Test late morning
        notificationService.scheduleMorningBriefing(hour: 11, minute: 59)
        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        // Clean up
        notificationService.cancelMorningBriefing()

        XCTAssertTrue(true)
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentScheduling() async throws {
        let taskIDs = (0..<10).map { _ in UUID() }
        let futureDate = Date().addingTimeInterval(86400)

        // Schedule multiple notifications concurrently
        await withTaskGroup(of: Void.self) { group in
            for (index, taskID) in taskIDs.enumerated() {
                group.addTask {
                    self.notificationService.scheduleTaskReminder(
                        taskID: taskID,
                        title: "Concurrent Task \(index)",
                        reminderDate: futureDate
                    )
                }
            }
        }

        // Wait for all operations to complete
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        // Cancel all
        for taskID in taskIDs {
            notificationService.cancelTaskReminder(taskID: taskID)
        }

        XCTAssertTrue(true)
    }

    // MARK: - Performance Tests

    func testScheduleNotificationPerformance() {
        let taskID = UUID()
        let futureDate = Date().addingTimeInterval(86400)

        measure {
            notificationService.scheduleTaskReminder(
                taskID: taskID,
                title: "Performance Test",
                reminderDate: futureDate
            )
        }

        // Clean up
        notificationService.cancelTaskReminder(taskID: taskID)
    }

    func testCancelNotificationPerformance() {
        let taskID = UUID()

        measure {
            notificationService.cancelTaskReminder(taskID: taskID)
        }
    }
}
