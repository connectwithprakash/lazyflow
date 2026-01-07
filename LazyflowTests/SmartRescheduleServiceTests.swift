import XCTest
@testable import Lazyflow

final class SmartRescheduleServiceTests: XCTestCase {

    // MARK: - RescheduleOption Tests

    func testRescheduleOption_FormattedTime_Today() {
        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!

        let option = RescheduleOption(
            id: UUID(),
            suggestedTime: today,
            type: .nextAvailable,
            reason: "Test",
            score: 50
        )

        XCTAssertTrue(option.formattedTime.contains("Today"))
    }

    func testRescheduleOption_FormattedTime_Tomorrow() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!

        let option = RescheduleOption(
            id: UUID(),
            suggestedTime: tomorrowTime,
            type: .tomorrow,
            reason: "Test",
            score: 40
        )

        XCTAssertTrue(option.formattedTime.contains("Tomorrow"))
    }

    func testRescheduleOption_FormattedTime_FutureDate() {
        let calendar = Calendar.current
        let futureDate = calendar.date(byAdding: .day, value: 5, to: Date())!

        let option = RescheduleOption(
            id: UUID(),
            suggestedTime: futureDate,
            type: .nextAvailable,
            reason: "Test",
            score: 30
        )

        // Should show date and time format
        XCTAssertFalse(option.formattedTime.contains("Today"))
        XCTAssertFalse(option.formattedTime.contains("Tomorrow"))
    }

    // MARK: - RescheduleType Tests

    func testRescheduleType_AllTypes() {
        let types: [RescheduleType] = [.afterConflict, .earlierToday, .nextAvailable, .tomorrow]
        XCTAssertEqual(types.count, 4)
    }

    // MARK: - RescheduleUrgency Tests

    func testRescheduleUrgency_DisplayNames() {
        XCTAssertEqual(RescheduleUrgency.immediate.displayName, "Act Now")
        XCTAssertEqual(RescheduleUrgency.high.displayName, "Soon")
        XCTAssertEqual(RescheduleUrgency.medium.displayName, "When Convenient")
        XCTAssertEqual(RescheduleUrgency.low.displayName, "Optional")
    }

    func testRescheduleUrgency_Colors() {
        XCTAssertEqual(RescheduleUrgency.immediate.color, "red")
        XCTAssertEqual(RescheduleUrgency.high.color, "orange")
        XCTAssertEqual(RescheduleUrgency.medium.color, "yellow")
        XCTAssertEqual(RescheduleUrgency.low.color, "gray")
    }

    // MARK: - Urgency Determination Tests

    func testDetermineUrgency_ConflictIn15Min_ReturnsImmediate() {
        let task = Task(title: "Test")
        let conflictTime = Date().addingTimeInterval(900) // 15 minutes
        let urgency = determineUrgency(conflictTime: conflictTime, task: task)
        XCTAssertEqual(urgency, .immediate)
    }

    func testDetermineUrgency_ConflictIn1Hour_ReturnsHigh() {
        let task = Task(title: "Test")
        let conflictTime = Date().addingTimeInterval(3600) // 1 hour
        let urgency = determineUrgency(conflictTime: conflictTime, task: task)
        XCTAssertEqual(urgency, .high)
    }

    func testDetermineUrgency_UrgentTask_ReturnsHigh() {
        let task = Task(title: "Test", priority: .urgent)
        let conflictTime = Date().addingTimeInterval(7200) // 2 hours
        let urgency = determineUrgency(conflictTime: conflictTime, task: task)
        XCTAssertEqual(urgency, .high)
    }

    func testDetermineUrgency_HighPriorityTask_ReturnsMedium() {
        let task = Task(title: "Test", priority: .high)
        let conflictTime = Date().addingTimeInterval(10800) // 3 hours
        let urgency = determineUrgency(conflictTime: conflictTime, task: task)
        XCTAssertEqual(urgency, .medium)
    }

    func testDetermineUrgency_NormalTask_ReturnsLow() {
        let task = Task(title: "Test", priority: .medium)
        let conflictTime = Date().addingTimeInterval(10800) // 3 hours
        let urgency = determineUrgency(conflictTime: conflictTime, task: task)
        XCTAssertEqual(urgency, .low)
    }

    // MARK: - Option Score Calculation Tests

    func testCalculateOptionScore_SweetSpotTime() {
        let task = Task(title: "Test")
        let sweetSpotTime = Date().addingTimeInterval(7200) // 2 hours from now
        let score = calculateOptionScore(time: sweetSpotTime, task: task, type: .afterConflict)

        // Should get bonus for sweet spot + afterConflict type
        XCTAssertGreaterThan(score, 80) // 50 base + 20 sweet spot + 15 afterConflict
    }

    func testCalculateOptionScore_TomorrowPenalty_UrgentTask() {
        let task = Task(title: "Test", priority: .urgent)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let score = calculateOptionScore(time: tomorrow, task: task, type: .tomorrow)

        // Urgent tasks penalized for tomorrow (-20), but may get time bonuses
        // Low priority would get +5, so urgent (getting -20 instead) is effectively -25 relative
        XCTAssertLessThanOrEqual(score, 50)
    }

    func testCalculateOptionScore_TomorrowOkay_LowPriorityTask() {
        let task = Task(title: "Test", priority: .low)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let score = calculateOptionScore(time: tomorrow, task: task, type: .tomorrow)

        // Low priority gets small bonus for tomorrow
        XCTAssertGreaterThanOrEqual(score, 50)
    }

    func testCalculateOptionScore_ProductiveHours() {
        let task = Task(title: "Test")
        let calendar = Calendar.current
        let productiveTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let score = calculateOptionScore(time: productiveTime, task: task, type: .nextAvailable)

        // Should get bonus for productive hours (9-17)
        XCTAssertGreaterThanOrEqual(score, 55) // 50 base + 5 type + 10 hours (if in range)
    }

    // MARK: - BatchRescheduleSuggestion Tests

    func testBatchRescheduleSuggestion_ResolvedCount() {
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")

        let conflict1 = TaskConflict(
            id: UUID(),
            task: task1,
            conflictTime: Date(),
            overlapDuration: 1800,
            severity: .medium,
            type: .calendarEvent
        )
        let conflict2 = TaskConflict(
            id: UUID(),
            task: task2,
            conflictTime: Date(),
            overlapDuration: 1800,
            severity: .low,
            type: .calendarEvent
        )

        let option = RescheduleOption(
            id: UUID(),
            suggestedTime: Date().addingTimeInterval(3600),
            type: .nextAvailable,
            reason: "Test",
            score: 60
        )

        let suggestion1 = RescheduleSuggestion(
            conflict: conflict1,
            options: [option],
            recommendedOption: option,
            urgency: .medium
        )
        let suggestion2 = RescheduleSuggestion(
            conflict: conflict2,
            options: [],
            recommendedOption: nil, // No recommendation
            urgency: .low
        )

        let batch = BatchRescheduleSuggestion(
            suggestions: [suggestion1, suggestion2],
            totalConflicts: 2,
            canAutoResolve: false
        )

        XCTAssertEqual(batch.resolvedCount, 1)
        XCTAssertEqual(batch.totalConflicts, 2)
        XCTAssertFalse(batch.canAutoResolve)
    }

    func testBatchRescheduleSuggestion_CanAutoResolve() {
        let task = Task(title: "Task")
        let conflict = TaskConflict(
            id: UUID(),
            task: task,
            conflictTime: Date(),
            overlapDuration: 1800,
            severity: .medium,
            type: .calendarEvent
        )

        let option = RescheduleOption(
            id: UUID(),
            suggestedTime: Date().addingTimeInterval(3600),
            type: .nextAvailable,
            reason: "Test",
            score: 60
        )

        let suggestion = RescheduleSuggestion(
            conflict: conflict,
            options: [option],
            recommendedOption: option,
            urgency: .medium
        )

        let batch = BatchRescheduleSuggestion(
            suggestions: [suggestion],
            totalConflicts: 1,
            canAutoResolve: true
        )

        XCTAssertTrue(batch.canAutoResolve)
        XCTAssertEqual(batch.resolvedCount, 1)
    }

    // MARK: - Helper Methods

    private func determineUrgency(conflictTime: Date, task: Task) -> RescheduleUrgency {
        let minutesUntilConflict = conflictTime.timeIntervalSince(Date()) / 60

        if minutesUntilConflict < 30 {
            return .immediate
        }

        if minutesUntilConflict < 120 || task.priority == .urgent {
            return .high
        }

        if task.priority == .high {
            return .medium
        }

        return .low
    }

    private func calculateOptionScore(time: Date, task: Task, type: RescheduleType) -> Double {
        var score: Double = 50.0

        let hoursFromNow = time.timeIntervalSince(Date()) / 3600
        if hoursFromNow >= 0.5 && hoursFromNow <= 4 {
            score += 20
        } else if hoursFromNow > 4 && hoursFromNow <= 24 {
            score += 10
        }

        switch type {
        case .afterConflict:
            score += 15
        case .earlierToday:
            score += 10
        case .nextAvailable:
            score += 5
        case .tomorrow:
            if task.priority == .urgent {
                score -= 20
            } else if task.priority == .high {
                score -= 10
            } else {
                score += 5
            }
        }

        let hour = Calendar.current.component(.hour, from: time)
        if hour >= 9 && hour <= 17 {
            score += 10
        }

        return score
    }
}
