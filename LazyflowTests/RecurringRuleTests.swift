import XCTest
@testable import Lazyflow

final class RecurringRuleTests: XCTestCase {

    // MARK: - Frequency Enum Tests

    func testHourlyFrequency_Exists() {
        let frequency = RecurringFrequency.hourly
        XCTAssertEqual(frequency.rawValue, 6)
    }

    func testTimesPerDayFrequency_Exists() {
        let frequency = RecurringFrequency.timesPerDay
        XCTAssertEqual(frequency.rawValue, 7)
    }

    func testHourlyFrequency_DisplayName() {
        let frequency = RecurringFrequency.hourly
        XCTAssertEqual(frequency.displayName, "Hourly")
    }

    func testTimesPerDayFrequency_DisplayName() {
        let frequency = RecurringFrequency.timesPerDay
        XCTAssertEqual(frequency.displayName, "Times Per Day")
    }

    // MARK: - RecurringRule Intraday Properties Tests

    func testRecurringRule_HourInterval_Default() {
        let rule = RecurringRule(frequency: .hourly)
        XCTAssertNil(rule.hourInterval)
    }

    func testRecurringRule_HourInterval_Set() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)
        XCTAssertEqual(rule.hourInterval, 2)
    }

    func testRecurringRule_TimesPerDay_Default() {
        let rule = RecurringRule(frequency: .timesPerDay)
        XCTAssertNil(rule.timesPerDay)
    }

    func testRecurringRule_TimesPerDay_Set() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        XCTAssertEqual(rule.timesPerDay, 3)
    }

    func testRecurringRule_ActiveHoursStart_Default() {
        let rule = RecurringRule(frequency: .hourly)
        XCTAssertNil(rule.activeHoursStart)
    }

    func testRecurringRule_ActiveHoursEnd_Default() {
        let rule = RecurringRule(frequency: .hourly)
        XCTAssertNil(rule.activeHoursEnd)
    }

    func testRecurringRule_ActiveHours_Set() {
        let calendar = Calendar.current
        let startComponents = DateComponents(hour: 8, minute: 0)
        let endComponents = DateComponents(hour: 22, minute: 0)
        let start = calendar.date(from: startComponents)!
        let end = calendar.date(from: endComponents)!

        let rule = RecurringRule(
            frequency: .hourly,
            hourInterval: 2,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        XCTAssertNotNil(rule.activeHoursStart)
        XCTAssertNotNil(rule.activeHoursEnd)
    }

    // MARK: - Next Occurrence Tests - Hourly

    func testNextOccurrence_Hourly_Basic() {
        let calendar = Calendar.current
        let now = Date()

        // Create rule for every 2 hours
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)

        let next = rule.nextOccurrence(from: now)

        XCTAssertNotNil(next)

        // Next occurrence should be 2 hours from now
        let expectedNext = calendar.date(byAdding: .hour, value: 2, to: now)!
        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day, .hour], from: next!),
            calendar.dateComponents([.year, .month, .day, .hour], from: expectedNext)
        )
    }

    func testNextOccurrence_Hourly_WithActiveHours() {
        let calendar = Calendar.current

        // Set active hours 8 AM - 10 PM
        var startComponents = DateComponents()
        startComponents.hour = 8
        startComponents.minute = 0
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 22
        endComponents.minute = 0
        let end = calendar.date(from: endComponents)!

        let rule = RecurringRule(
            frequency: .hourly,
            hourInterval: 2,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        // Test: If current time is 9 AM, next should be 11 AM
        var testDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        testDateComponents.hour = 9
        testDateComponents.minute = 0
        let testDate = calendar.date(from: testDateComponents)!

        let next = rule.nextOccurrence(from: testDate)
        XCTAssertNotNil(next)

        let nextHour = calendar.component(.hour, from: next!)
        XCTAssertEqual(nextHour, 11)
    }

    func testNextOccurrence_Hourly_AfterActiveHours_WrapsToNextDay() {
        let calendar = Calendar.current

        // Set active hours 8 AM - 10 PM
        var startComponents = DateComponents()
        startComponents.hour = 8
        startComponents.minute = 0
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 22
        endComponents.minute = 0
        let end = calendar.date(from: endComponents)!

        let rule = RecurringRule(
            frequency: .hourly,
            hourInterval: 2,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        // Test: If current time is 9 PM (21:00), adding 2 hours = 11 PM (outside active hours)
        // Should wrap to next day at 8 AM
        var testDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        testDateComponents.hour = 21
        testDateComponents.minute = 0
        let testDate = calendar.date(from: testDateComponents)!

        let next = rule.nextOccurrence(from: testDate)
        XCTAssertNotNil(next)

        let nextHour = calendar.component(.hour, from: next!)
        let isNextDay = !calendar.isDate(next!, inSameDayAs: testDate)

        // Should wrap to next day at 8 AM
        XCTAssertTrue(isNextDay)
        XCTAssertEqual(nextHour, 8)
    }

    // MARK: - Next Occurrence Tests - Times Per Day

    func testNextOccurrence_TimesPerDay_AutoDistribute() {
        let calendar = Calendar.current

        // Set active hours 8 AM - 8 PM (12 hours)
        var startComponents = DateComponents()
        startComponents.hour = 8
        startComponents.minute = 0
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 20
        endComponents.minute = 0
        let end = calendar.date(from: endComponents)!

        // 3 times per day in 12 hours = every 4 hours (8, 12, 16)
        let rule = RecurringRule(
            frequency: .timesPerDay,
            timesPerDay: 3,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        // Test: If current time is 9 AM, next should be 12 PM
        var testDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        testDateComponents.hour = 9
        testDateComponents.minute = 0
        let testDate = calendar.date(from: testDateComponents)!

        let next = rule.nextOccurrence(from: testDate)
        XCTAssertNotNil(next)

        let nextHour = calendar.component(.hour, from: next!)
        XCTAssertEqual(nextHour, 12)
    }

    func testNextOccurrence_TimesPerDay_WithSpecificTimes() {
        let calendar = Calendar.current

        // Specific times: 8 AM, 2 PM, 8 PM
        var time1Components = DateComponents()
        time1Components.hour = 8
        time1Components.minute = 0
        let time1 = calendar.date(from: time1Components)!

        var time2Components = DateComponents()
        time2Components.hour = 14
        time2Components.minute = 0
        let time2 = calendar.date(from: time2Components)!

        var time3Components = DateComponents()
        time3Components.hour = 20
        time3Components.minute = 0
        let time3 = calendar.date(from: time3Components)!

        let rule = RecurringRule(
            frequency: .timesPerDay,
            timesPerDay: 3,
            specificTimes: [time1, time2, time3]
        )

        // Test: If current time is 10 AM, next should be 2 PM (14:00)
        var testDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        testDateComponents.hour = 10
        testDateComponents.minute = 0
        let testDate = calendar.date(from: testDateComponents)!

        let next = rule.nextOccurrence(from: testDate)
        XCTAssertNotNil(next)

        let nextHour = calendar.component(.hour, from: next!)
        XCTAssertEqual(nextHour, 14)
    }

    // MARK: - Compact Display Format Tests

    func testCompactDisplayFormat_Hourly() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)
        XCTAssertEqual(rule.compactDisplayFormat, "2h")
    }

    func testCompactDisplayFormat_Hourly_SingleHour() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 1)
        XCTAssertEqual(rule.compactDisplayFormat, "1h")
    }

    func testCompactDisplayFormat_TimesPerDay() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        XCTAssertEqual(rule.compactDisplayFormat, "3x/day")
    }

    // MARK: - Display Description Tests

    func testDisplayDescription_Hourly() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)
        XCTAssertEqual(rule.displayDescription, "Every 2 hours")
    }

    func testDisplayDescription_TimesPerDay() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        XCTAssertEqual(rule.displayDescription, "3 times per day")
    }

    // MARK: - Edge Cases

    func testNextOccurrence_Hourly_EndDatePassed() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        let rule = RecurringRule(
            frequency: .hourly,
            endDate: yesterday,
            hourInterval: 2
        )

        let next = rule.nextOccurrence(from: Date())
        XCTAssertNil(next)
    }

    func testNextOccurrence_TimesPerDay_NarrowActiveWindow() {
        let calendar = Calendar.current

        // Active hours only 9 AM - 10 AM (1 hour window)
        var startComponents = DateComponents()
        startComponents.hour = 9
        startComponents.minute = 0
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 10
        endComponents.minute = 0
        let end = calendar.date(from: endComponents)!

        // 3 times per day in 1 hour is very tight
        let rule = RecurringRule(
            frequency: .timesPerDay,
            timesPerDay: 3,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        // Should still calculate a valid next occurrence
        var testDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        testDateComponents.hour = 8
        testDateComponents.minute = 0
        let testDate = calendar.date(from: testDateComponents)!

        let next = rule.nextOccurrence(from: testDate)
        XCTAssertNotNil(next)
    }

    // MARK: - Codable Tests

    func testRecurringRule_Codable_WithIntradayFields() throws {
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.hour = 8
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 22
        let end = calendar.date(from: endComponents)!

        let original = RecurringRule(
            frequency: .hourly,
            hourInterval: 2,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecurringRule.self, from: data)

        XCTAssertEqual(decoded.frequency, .hourly)
        XCTAssertEqual(decoded.hourInterval, 2)
        XCTAssertNotNil(decoded.activeHoursStart)
        XCTAssertNotNil(decoded.activeHoursEnd)
    }

    func testRecurringRule_Equatable_WithIntradayFields() {
        let sharedID = UUID()
        let rule1 = RecurringRule(id: sharedID, frequency: .hourly, hourInterval: 2)
        let rule2 = RecurringRule(id: sharedID, frequency: .hourly, hourInterval: 2)
        let rule3 = RecurringRule(id: sharedID, frequency: .hourly, hourInterval: 3)

        XCTAssertEqual(rule1, rule2)
        XCTAssertNotEqual(rule1, rule3)
    }

    // MARK: - Intraday Time Calculation Tests

    func testCalculateIntradayTimes_Hourly() {
        let calendar = Calendar.current

        var startComponents = DateComponents()
        startComponents.hour = 8
        startComponents.minute = 0
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 20
        endComponents.minute = 0
        let end = calendar.date(from: endComponents)!

        let rule = RecurringRule(
            frequency: .hourly,
            hourInterval: 2,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        // 8 AM to 8 PM with 2-hour intervals: 8, 10, 12, 14, 16, 18, 20 = 7 times
        let times = rule.calculateIntradayTimes(for: Date())
        XCTAssertEqual(times.count, 7)
    }

    func testCalculateIntradayTimes_TimesPerDay() {
        let calendar = Calendar.current

        var startComponents = DateComponents()
        startComponents.hour = 8
        startComponents.minute = 0
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 20
        endComponents.minute = 0
        let end = calendar.date(from: endComponents)!

        let rule = RecurringRule(
            frequency: .timesPerDay,
            timesPerDay: 3,
            activeHoursStart: start,
            activeHoursEnd: end
        )

        let times = rule.calculateIntradayTimes(for: Date())
        XCTAssertEqual(times.count, 3)
    }

    func testCalculateIntradayTimes_WithSpecificTimes() {
        let calendar = Calendar.current

        var time1Components = DateComponents()
        time1Components.hour = 8
        let time1 = calendar.date(from: time1Components)!

        var time2Components = DateComponents()
        time2Components.hour = 14
        let time2 = calendar.date(from: time2Components)!

        var time3Components = DateComponents()
        time3Components.hour = 20
        let time3 = calendar.date(from: time3Components)!

        let rule = RecurringRule(
            frequency: .timesPerDay,
            timesPerDay: 3,
            specificTimes: [time1, time2, time3]
        )

        let times = rule.calculateIntradayTimes(for: Date())
        XCTAssertEqual(times.count, 3)

        // Verify the hours
        let hours = times.map { calendar.component(.hour, from: $0) }
        XCTAssertTrue(hours.contains(8))
        XCTAssertTrue(hours.contains(14))
        XCTAssertTrue(hours.contains(20))
    }

    // MARK: - IsIntraday Property Tests

    func testIsIntraday_Hourly() {
        let rule = RecurringRule(frequency: .hourly, hourInterval: 2)
        XCTAssertTrue(rule.isIntraday)
    }

    func testIsIntraday_TimesPerDay() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        XCTAssertTrue(rule.isIntraday)
    }

    func testIsIntraday_Daily_False() {
        let rule = RecurringRule(frequency: .daily)
        XCTAssertFalse(rule.isIntraday)
    }

    func testIsIntraday_Weekly_False() {
        let rule = RecurringRule(frequency: .weekly)
        XCTAssertFalse(rule.isIntraday)
    }
}

// MARK: - Task Intraday Completion Tracking Tests

final class TaskIntradayCompletionTests: XCTestCase {

    // MARK: - Basic Property Tests

    func testTask_IntradayCompletionsToday_Default() {
        let task = Task(title: "Test Task")
        XCTAssertEqual(task.intradayCompletionsToday, 0)
    }

    func testTask_LastIntradayCompletionDate_Default() {
        let task = Task(title: "Test Task")
        XCTAssertNil(task.lastIntradayCompletionDate)
    }

    func testTask_IsIntradayTask_True() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(title: "Take medication", recurringRule: rule)
        XCTAssertTrue(task.isIntradayTask)
    }

    func testTask_IsIntradayTask_False_NonRecurring() {
        let task = Task(title: "Regular task")
        XCTAssertFalse(task.isIntradayTask)
    }

    func testTask_IsIntradayTask_False_DailyRecurring() {
        let rule = RecurringRule(frequency: .daily)
        let task = Task(title: "Daily task", recurringRule: rule)
        XCTAssertFalse(task.isIntradayTask)
    }

    // MARK: - Intraday Target Tests

    func testTask_IntradayTargetToday_TimesPerDay() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(title: "Take medication", recurringRule: rule)
        XCTAssertEqual(task.intradayTargetToday, 3)
    }

    func testTask_IntradayTargetToday_Hourly() {
        let calendar = Calendar.current

        var startComponents = DateComponents()
        startComponents.hour = 8
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.hour = 20
        let end = calendar.date(from: endComponents)!

        // 8 AM to 8 PM with 2-hour intervals: 8, 10, 12, 14, 16, 18, 20 = 7 times
        let rule = RecurringRule(
            frequency: .hourly,
            hourInterval: 2,
            activeHoursStart: start,
            activeHoursEnd: end
        )
        let task = Task(title: "Drink water", recurringRule: rule)
        XCTAssertEqual(task.intradayTargetToday, 7)
    }

    func testTask_IntradayTargetToday_NonIntraday() {
        let task = Task(title: "Regular task")
        XCTAssertEqual(task.intradayTargetToday, 0)
    }

    // MARK: - Current Completions Tests

    func testTask_CurrentIntradayCompletions_Today() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: Date()
        )
        XCTAssertEqual(task.currentIntradayCompletions, 2)
    }

    func testTask_CurrentIntradayCompletions_Yesterday_Resets() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: yesterday
        )
        XCTAssertEqual(task.currentIntradayCompletions, 0)
    }

    func testTask_CurrentIntradayCompletions_NoLastDate() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: nil
        )
        XCTAssertEqual(task.currentIntradayCompletions, 0)
    }

    // MARK: - Progress String Tests

    func testTask_IntradayProgressString_HasProgress() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: Date()
        )
        XCTAssertEqual(task.intradayProgressString, "2/3")
    }

    func testTask_IntradayProgressString_NonIntraday() {
        let task = Task(title: "Regular task")
        XCTAssertNil(task.intradayProgressString)
    }

    // MARK: - Progress Ratio Tests

    func testTask_IntradayProgress_PartiallyComplete() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 4)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: Date()
        )
        XCTAssertEqual(task.intradayProgress, 0.5, accuracy: 0.01)
    }

    func testTask_IntradayProgress_Complete() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 3,
            lastIntradayCompletionDate: Date()
        )
        XCTAssertEqual(task.intradayProgress, 1.0, accuracy: 0.01)
    }

    func testTask_IntradayProgress_Zero() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(title: "Take medication", recurringRule: rule)
        XCTAssertEqual(task.intradayProgress, 0.0, accuracy: 0.01)
    }

    // MARK: - Completion Status Tests

    func testTask_IsIntradayCompleteForToday_True() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 3,
            lastIntradayCompletionDate: Date()
        )
        XCTAssertTrue(task.isIntradayCompleteForToday)
    }

    func testTask_IsIntradayCompleteForToday_False() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: Date()
        )
        XCTAssertFalse(task.isIntradayCompleteForToday)
    }

    func testTask_IsIntradayCompleteForToday_NonIntraday() {
        let task = Task(title: "Regular task")
        XCTAssertFalse(task.isIntradayCompleteForToday)
    }

    // MARK: - Increment Completion Tests

    func testTask_IncrementIntradayCompletion() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(title: "Take medication", recurringRule: rule)

        let updated = task.incrementIntradayCompletion()

        XCTAssertEqual(updated.intradayCompletionsToday, 1)
        XCTAssertNotNil(updated.lastIntradayCompletionDate)
        XCTAssertTrue(Calendar.current.isDateInToday(updated.lastIntradayCompletionDate!))
    }

    func testTask_IncrementIntradayCompletion_FromExisting() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 1,
            lastIntradayCompletionDate: Date()
        )

        let updated = task.incrementIntradayCompletion()

        XCTAssertEqual(updated.intradayCompletionsToday, 2)
    }

    func testTask_IncrementIntradayCompletion_FromYesterday() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: yesterday
        )

        let updated = task.incrementIntradayCompletion()

        // Should reset and start from 1, not 3
        XCTAssertEqual(updated.intradayCompletionsToday, 1)
        XCTAssertTrue(Calendar.current.isDateInToday(updated.lastIntradayCompletionDate!))
    }

    // MARK: - Reset Completion Tests

    func testTask_ResetIntradayCompletions() {
        let rule = RecurringRule(frequency: .timesPerDay, timesPerDay: 3)
        let task = Task(
            title: "Take medication",
            recurringRule: rule,
            intradayCompletionsToday: 2,
            lastIntradayCompletionDate: Date()
        )

        let updated = task.resetIntradayCompletions()

        XCTAssertEqual(updated.intradayCompletionsToday, 0)
        XCTAssertNil(updated.lastIntradayCompletionDate)
    }
}
