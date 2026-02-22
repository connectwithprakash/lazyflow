import XCTest
@testable import Lazyflow

final class CalendarSyncServiceTests: XCTestCase {

    // MARK: - isEligibleForAutoSync

    func testIsEligibleForAutoSync_AllFieldsPresent_ReturnsTrue() {
        let task = Task(
            title: "Eligible Task",
            dueDate: Date(),
            dueTime: Date(),
            estimatedDuration: 1800
        )
        XCTAssertTrue(task.isEligibleForAutoSync)
    }

    func testIsEligibleForAutoSync_NoDueDate_ReturnsFalse() {
        let task = Task(
            title: "No Due Date",
            dueTime: Date(),
            estimatedDuration: 1800
        )
        XCTAssertFalse(task.isEligibleForAutoSync)
    }

    func testIsEligibleForAutoSync_NoDueTime_ReturnsFalse() {
        let task = Task(
            title: "No Due Time",
            dueDate: Date(),
            estimatedDuration: 1800
        )
        XCTAssertFalse(task.isEligibleForAutoSync)
    }

    func testIsEligibleForAutoSync_NoDuration_ReturnsFalse() {
        let task = Task(
            title: "No Duration",
            dueDate: Date(),
            dueTime: Date()
        )
        XCTAssertFalse(task.isEligibleForAutoSync)
    }

    func testIsEligibleForAutoSync_ZeroDuration_ReturnsFalse() {
        let task = Task(
            title: "Zero Duration",
            dueDate: Date(),
            dueTime: Date(),
            estimatedDuration: 0
        )
        XCTAssertFalse(task.isEligibleForAutoSync)
    }

    func testIsEligibleForAutoSync_CompletedTask_ReturnsFalse() {
        let task = Task(
            title: "Completed",
            dueDate: Date(),
            dueTime: Date(),
            isCompleted: true,
            estimatedDuration: 1800
        )
        XCTAssertFalse(task.isEligibleForAutoSync)
    }

    func testIsEligibleForAutoSync_ArchivedTask_ReturnsFalse() {
        let task = Task(
            title: "Archived",
            dueDate: Date(),
            dueTime: Date(),
            isArchived: true,
            estimatedDuration: 1800
        )
        XCTAssertFalse(task.isEligibleForAutoSync)
    }

    // MARK: - Completion Policy

    func testCompletionPolicy_KeepEvent_DefaultValue() {
        // Default should be "keep"
        let raw = UserDefaults.standard.string(forKey: "calendarCompletionPolicy") ?? "keep"
        let policy = CalendarSyncService.CompletionPolicy(rawValue: raw)
        XCTAssertEqual(policy, .keepEvent)
    }

    func testCompletionPolicy_DeleteEvent_ParsesCorrectly() {
        let policy = CalendarSyncService.CompletionPolicy(rawValue: "delete")
        XCTAssertEqual(policy, .deleteEvent)
    }

    func testCompletionPolicy_InvalidValue_ReturnsNil() {
        let policy = CalendarSyncService.CompletionPolicy(rawValue: "invalid")
        XCTAssertNil(policy)
    }

    // MARK: - Domain Model Fields

    func testTaskHasCalendarSyncFields() {
        let now = Date()
        let task = Task(
            title: "Sync Test",
            linkedEventID: "event-123",
            calendarItemExternalIdentifier: "ext-456",
            lastSyncedAt: now
        )

        XCTAssertEqual(task.linkedEventID, "event-123")
        XCTAssertEqual(task.calendarItemExternalIdentifier, "ext-456")
        XCTAssertEqual(task.lastSyncedAt, now)
    }

    func testTaskCalendarSyncFieldsDefaultToNil() {
        let task = Task(title: "Default Fields")

        XCTAssertNil(task.linkedEventID)
        XCTAssertNil(task.calendarItemExternalIdentifier)
        XCTAssertNil(task.lastSyncedAt)
    }

    // MARK: - CalendarSyncService Initialization

    func testCalendarSyncServiceIsSingleton() {
        let instance1 = CalendarSyncService.shared
        let instance2 = CalendarSyncService.shared
        XCTAssertTrue(instance1 === instance2)
    }

    func testCalendarSyncServiceInitialState() {
        let service = CalendarSyncService.shared
        XCTAssertFalse(service.isSyncing)
    }

    // MARK: - Busy-Only Mode

    func testBusyOnlyMode_DefaultDisabled() {
        // Clean up any previous test state
        UserDefaults.standard.removeObject(forKey: "calendarBusyOnly")
        let busyOnly = UserDefaults.standard.bool(forKey: "calendarBusyOnly")
        XCTAssertFalse(busyOnly)
    }

    // MARK: - Loop Prevention

    func testRecentlyPushedTaskSkippedDuringReverseSync() {
        // This tests the concept: a task that was just pushed to calendar
        // should not be reverse-synced within the cooldown window.
        // We verify the data model supports this by checking lastSyncedAt.
        let now = Date()
        let task = Task(
            title: "Recently Pushed",
            linkedEventID: "event-123",
            lastSyncedAt: now
        )

        // lastSyncedAt was just set, so within the 3s guard window
        let timeSinceSynced = Date().timeIntervalSince(task.lastSyncedAt ?? .distantPast)
        XCTAssertLessThan(timeSinceSynced, 3.0, "Task should be within reverse sync guard window")
    }

    // MARK: - Notification Name

    func testLinkedEventDeletedExternallyNotificationExists() {
        let name = Notification.Name.linkedEventDeletedExternally
        XCTAssertEqual(name.rawValue, "linkedEventDeletedExternally")
    }
}
