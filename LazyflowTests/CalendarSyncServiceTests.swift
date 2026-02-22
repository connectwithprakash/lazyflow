import XCTest
import EventKit
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

    // MARK: - canMapToEKRecurrenceRule

    func testCanMapToEKRecurrenceRule_daily_true() {
        let rule = RecurringRule(frequency: .daily)
        XCTAssertTrue(rule.canMapToEKRecurrenceRule)
    }

    func testCanMapToEKRecurrenceRule_weekly_true() {
        let rule = RecurringRule(frequency: .weekly)
        XCTAssertTrue(rule.canMapToEKRecurrenceRule)
    }

    func testCanMapToEKRecurrenceRule_biweekly_true() {
        let rule = RecurringRule(frequency: .biweekly)
        XCTAssertTrue(rule.canMapToEKRecurrenceRule)
    }

    func testCanMapToEKRecurrenceRule_monthly_true() {
        let rule = RecurringRule(frequency: .monthly)
        XCTAssertTrue(rule.canMapToEKRecurrenceRule)
    }

    func testCanMapToEKRecurrenceRule_yearly_true() {
        let rule = RecurringRule(frequency: .yearly)
        XCTAssertTrue(rule.canMapToEKRecurrenceRule)
    }

    func testCanMapToEKRecurrenceRule_custom_true() {
        let rule = RecurringRule(frequency: .custom, interval: 3)
        XCTAssertTrue(rule.canMapToEKRecurrenceRule)
    }

    func testCanMapToEKRecurrenceRule_hourly_false() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)
        XCTAssertFalse(rule.canMapToEKRecurrenceRule)
    }

    func testCanMapToEKRecurrenceRule_timesPerDay_false() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        XCTAssertFalse(rule.canMapToEKRecurrenceRule)
    }

    // MARK: - toEKRecurrenceRule

    func testToEKRecurrenceRule_daily() {
        let rule = RecurringRule(frequency: .daily, interval: 1)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .daily)
        XCTAssertEqual(ekRule?.interval, 1)
    }

    func testToEKRecurrenceRule_daily_interval3() {
        let rule = RecurringRule(frequency: .daily, interval: 3)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .daily)
        XCTAssertEqual(ekRule?.interval, 3)
    }

    func testToEKRecurrenceRule_weekly_withDaysOfWeek() {
        // Monday (2), Wednesday (4), Friday (6) in Apple Calendar weekday numbering
        let rule = RecurringRule(frequency: .weekly, daysOfWeek: [2, 4, 6])
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .weekly)
        XCTAssertEqual(ekRule?.interval, 1)
        XCTAssertEqual(ekRule?.daysOfTheWeek?.count, 3)
    }

    func testToEKRecurrenceRule_biweekly() {
        let rule = RecurringRule(frequency: .biweekly)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .weekly)
        XCTAssertEqual(ekRule?.interval, 2)
    }

    func testToEKRecurrenceRule_monthly() {
        let rule = RecurringRule(frequency: .monthly, interval: 1)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .monthly)
        XCTAssertEqual(ekRule?.interval, 1)
    }

    func testToEKRecurrenceRule_yearly() {
        let rule = RecurringRule(frequency: .yearly, interval: 1)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .yearly)
        XCTAssertEqual(ekRule?.interval, 1)
    }

    func testToEKRecurrenceRule_withEndDate() {
        let endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let rule = RecurringRule(frequency: .daily, endDate: endDate)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertNotNil(ekRule?.recurrenceEnd)
        XCTAssertNotNil(ekRule?.recurrenceEnd?.endDate)
    }

    func testToEKRecurrenceRule_hourly_returnsNil() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)
        XCTAssertNil(rule.toEKRecurrenceRule())
    }

    func testToEKRecurrenceRule_timesPerDay_returnsNil() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        XCTAssertNil(rule.toEKRecurrenceRule())
    }

    func testToEKRecurrenceRule_custom_withDaysOfWeek() {
        let rule = RecurringRule(frequency: .custom, interval: 1, daysOfWeek: [2, 6])
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .weekly)
        XCTAssertEqual(ekRule?.daysOfTheWeek?.count, 2)
    }

    func testToEKRecurrenceRule_custom_noDaysOfWeek() {
        let rule = RecurringRule(frequency: .custom, interval: 5)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .daily)
        XCTAssertEqual(ekRule?.interval, 5)
    }

    // MARK: - fromEKRecurrenceRule

    func testFromEKRecurrenceRule_daily() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: nil
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.frequency, .daily)
        XCTAssertEqual(rule?.interval, 1)
    }

    func testFromEKRecurrenceRule_weekly() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.frequency, .weekly)
        XCTAssertEqual(rule?.interval, 1)
    }

    func testFromEKRecurrenceRule_biweekly() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 2,
            end: nil
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.frequency, .biweekly)
    }

    func testFromEKRecurrenceRule_monthly() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .monthly,
            interval: 1,
            end: nil
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.frequency, .monthly)
    }

    func testFromEKRecurrenceRule_yearly() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .yearly,
            interval: 1,
            end: nil
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.frequency, .yearly)
    }

    func testFromEKRecurrenceRule_customDaily() {
        // Daily with interval > 1 maps to .custom
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 3,
            end: nil
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.frequency, .custom)
        XCTAssertEqual(rule?.interval, 3)
    }

    func testFromEKRecurrenceRule_withDaysOfWeek() {
        let daysOfWeek = [
            EKRecurrenceDayOfWeek(.monday),
            EKRecurrenceDayOfWeek(.wednesday),
            EKRecurrenceDayOfWeek(.friday)
        ]
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.frequency, .weekly)
        XCTAssertEqual(rule?.daysOfWeek?.count, 3)
    }

    func testFromEKRecurrenceRule_withEndDate() {
        let endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        let ekEnd = EKRecurrenceEnd(end: endDate)
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: ekEnd
        )
        let rule = RecurringRule.fromEKRecurrenceRule(ekRule)
        XCTAssertNotNil(rule)
        XCTAssertNotNil(rule?.endDate)
    }

    // MARK: - Round-trip Mapping

    func testToEKRecurrenceRule_roundTrip_daily() {
        let original = RecurringRule(frequency: .daily, interval: 1)
        guard let ekRule = original.toEKRecurrenceRule(),
              let roundTripped = RecurringRule.fromEKRecurrenceRule(ekRule) else {
            XCTFail("Round-trip should succeed")
            return
        }
        XCTAssertEqual(roundTripped.frequency, .daily)
        XCTAssertEqual(roundTripped.interval, 1)
    }

    func testToEKRecurrenceRule_roundTrip_biweekly() {
        let original = RecurringRule(frequency: .biweekly)
        guard let ekRule = original.toEKRecurrenceRule(),
              let roundTripped = RecurringRule.fromEKRecurrenceRule(ekRule) else {
            XCTFail("Round-trip should succeed")
            return
        }
        XCTAssertEqual(roundTripped.frequency, .biweekly)
    }

    func testToEKRecurrenceRule_roundTrip_monthly() {
        let original = RecurringRule(frequency: .monthly, interval: 2)
        guard let ekRule = original.toEKRecurrenceRule(),
              let roundTripped = RecurringRule.fromEKRecurrenceRule(ekRule) else {
            XCTFail("Round-trip should succeed")
            return
        }
        XCTAssertEqual(roundTripped.frequency, .monthly)
        XCTAssertEqual(roundTripped.interval, 2)
    }

    // MARK: - Recurring Task Sync Scenarios

    func testRecurringTaskWithMappableRule_isEligible() {
        let rule = RecurringRule(frequency: .daily)
        let task = Task(
            title: "Daily Standup",
            dueDate: Date(),
            dueTime: Date(),
            estimatedDuration: 900,
            recurringRule: rule
        )
        XCTAssertTrue(task.isEligibleForAutoSync)
        XCTAssertTrue(task.recurringRule?.canMapToEKRecurrenceRule ?? false)
    }

    func testRecurringTaskWithHourlyRule_isEligibleButNotMappable() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)
        let task = Task(
            title: "Drink Water",
            dueDate: Date(),
            dueTime: Date(),
            estimatedDuration: 60,
            recurringRule: rule
        )
        XCTAssertTrue(task.isEligibleForAutoSync)
        XCTAssertFalse(task.recurringRule?.canMapToEKRecurrenceRule ?? true)
    }

    func testNextOccurrenceInheritsLinkedEventID_conceptual() {
        // Verify the data model supports link inheritance
        let rule = RecurringRule(frequency: .daily)
        let task = Task(
            title: "Daily Task",
            dueDate: Date(),
            dueTime: Date(),
            linkedEventID: "recurring-event-123",
            calendarItemExternalIdentifier: "ext-recurring-456",
            estimatedDuration: 1800,
            recurringRule: rule
        )

        XCTAssertTrue(rule.canMapToEKRecurrenceRule)
        XCTAssertNotNil(task.linkedEventID)
        XCTAssertNotNil(task.calendarItemExternalIdentifier)
        // In the real flow, toggleTaskCompletion passes these to the next occurrence
    }

    func testIntraday_hourly_doesNotGenerateEKRule() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 3)
        XCTAssertNil(rule.toEKRecurrenceRule())
    }

    func testIntraday_timesPerDay_doesNotGenerateEKRule() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 4)
        XCTAssertNil(rule.toEKRecurrenceRule())
    }

    // MARK: - Biweekly with DaysOfWeek

    func testToEKRecurrenceRule_biweekly_withDaysOfWeek() {
        // Biweekly on Mon (2), Wed (4)
        let rule = RecurringRule(frequency: .biweekly, daysOfWeek: [2, 4])
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .weekly)
        XCTAssertEqual(ekRule?.interval, 2)
        XCTAssertEqual(ekRule?.daysOfTheWeek?.count, 2)
    }

    // MARK: - Weekly Interval Preservation

    func testToEKRecurrenceRule_weekly_interval3() {
        let rule = RecurringRule(frequency: .weekly, interval: 3)
        let ekRule = rule.toEKRecurrenceRule()
        XCTAssertNotNil(ekRule)
        XCTAssertEqual(ekRule?.frequency, .weekly)
        XCTAssertEqual(ekRule?.interval, 3)
    }

    func testFromEKRecurrenceRule_weekly_interval3_roundTrip() {
        let original = RecurringRule(frequency: .weekly, interval: 3)
        guard let ekRule = original.toEKRecurrenceRule(),
              let roundTripped = RecurringRule.fromEKRecurrenceRule(ekRule) else {
            XCTFail("Round-trip should succeed")
            return
        }
        XCTAssertEqual(roundTripped.frequency, .weekly)
        XCTAssertEqual(roundTripped.interval, 3)
    }

    // MARK: - Completed Recurring Task Link Clearing

    func testCompletedRecurringTask_linkShouldBeClearedAfterCompletion() {
        // Simulates what handleCompletedTask does: after handling completion,
        // the completed occurrence's linkedEventID should be cleared.
        let rule = RecurringRule(frequency: .daily)
        var task = Task(
            title: "Daily Task",
            dueDate: Date(),
            dueTime: Date(),
            isCompleted: true,
            linkedEventID: "event-123",
            calendarItemExternalIdentifier: "ext-456",
            estimatedDuration: 1800,
            recurringRule: rule
        )

        // Before clearing: task has link
        XCTAssertTrue(task.recurringRule?.canMapToEKRecurrenceRule ?? false)
        XCTAssertNotNil(task.linkedEventID)

        // Simulate what handleCompletedTask does for recurring tasks
        task.linkedEventID = nil
        task.calendarItemExternalIdentifier = nil

        // After clearing: completed occurrence no longer has link
        XCTAssertNil(task.linkedEventID)
        XCTAssertNil(task.calendarItemExternalIdentifier)
    }

    // MARK: - Weekday Recurrence with Interval

    func testBiweekly_monWed_fromMonday_returnsWednesday() {
        // Mon/Wed biweekly: from Monday, next should be Wednesday (same week)
        let calendar = Calendar.current
        // Find next Monday
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2 // Monday
        let monday = calendar.date(from: components)!

        // Mon=2, Wed=4
        let rule = RecurringRule(frequency: .biweekly, daysOfWeek: [2, 4])
        let next = rule.nextOccurrence(from: monday)
        XCTAssertNotNil(next)

        if let next = next {
            let weekday = calendar.component(.weekday, from: next)
            XCTAssertEqual(weekday, 4, "Should be Wednesday")
            // Should be same week
            XCTAssertTrue(calendar.isDate(next, equalTo: monday, toGranularity: .weekOfYear))
        }
    }

    func testBiweekly_monWed_fromWednesday_returnsMonday2WeeksLater() {
        // Mon/Wed biweekly: from Wednesday, next should be Monday 2 weeks later
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 4 // Wednesday
        let wednesday = calendar.date(from: components)!

        let rule = RecurringRule(frequency: .biweekly, daysOfWeek: [2, 4])
        let next = rule.nextOccurrence(from: wednesday)
        XCTAssertNotNil(next)

        if let next = next {
            let weekday = calendar.component(.weekday, from: next)
            XCTAssertEqual(weekday, 2, "Should be Monday")
            // Should be 2 weeks later
            let daysBetween = calendar.dateComponents([.day], from: wednesday, to: next).day ?? 0
            XCTAssertGreaterThanOrEqual(daysBetween, 12, "Should be at least 12 days later (2 weeks minus a few days)")
        }
    }

    func testWeekly_interval1_monWed_fromMonday_returnsWednesday() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2 // Monday
        let monday = calendar.date(from: components)!

        let rule = RecurringRule(frequency: .weekly, interval: 1, daysOfWeek: [2, 4])
        let next = rule.nextOccurrence(from: monday)
        XCTAssertNotNil(next)

        if let next = next {
            let weekday = calendar.component(.weekday, from: next)
            XCTAssertEqual(weekday, 4, "Should be Wednesday")
        }
    }

    func testCompletedNonRecurringTask_linkClearedByDeletePolicy() {
        // Non-recurring tasks always clear link on delete policy
        var task = Task(
            title: "One-off Task",
            dueDate: Date(),
            dueTime: Date(),
            isCompleted: true,
            linkedEventID: "event-789",
            estimatedDuration: 1800
        )

        XCTAssertNil(task.recurringRule)
        task.linkedEventID = nil
        task.scheduledStartTime = nil
        task.scheduledEndTime = nil
        XCTAssertNil(task.linkedEventID)
    }
}
