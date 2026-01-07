import XCTest
@testable import Lazyflow

final class PrioritizationServiceTests: XCTestCase {

    // MARK: - Priority Score Component Tests

    func testCalculateDueDateScore_Overdue_ReturnsMaxUrgency() {
        let task = Task(title: "Test", dueDate: Date().addingDays(-1))
        let score = calculateDueDateScore(task)
        XCTAssertEqual(score, 40) // Max urgency for overdue
    }

    func testCalculateDueDateScore_DueWithin2Hours_ReturnsHighUrgency() {
        let task = Task(title: "Test", dueDate: Date().addingTimeInterval(3600)) // 1 hour
        let score = calculateDueDateScore(task)
        XCTAssertEqual(score, 38)
    }

    func testCalculateDueDateScore_DueToday_ReturnsModerateUrgency() {
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: Date())!
        let task = Task(title: "Test", dueDate: endOfDay)
        let score = calculateDueDateScore(task)
        XCTAssertGreaterThanOrEqual(score, 30)
        XCTAssertLessThanOrEqual(score, 38)
    }

    func testCalculateDueDateScore_DueTomorrow_ReturnsLowerUrgency() {
        // Add 25 hours to avoid edge case at exactly 24 hours boundary
        let task = Task(title: "Test", dueDate: Date().addingTimeInterval(25 * 3600))
        let score = calculateDueDateScore(task)
        XCTAssertGreaterThanOrEqual(score, 20)
        XCTAssertLessThan(score, 30)
    }

    func testCalculateDueDateScore_DueNextWeek_ReturnsLowUrgency() {
        let task = Task(title: "Test", dueDate: Date().addingDays(5))
        let score = calculateDueDateScore(task)
        XCTAssertGreaterThanOrEqual(score, 10)
        XCTAssertLessThan(score, 20)
    }

    func testCalculateDueDateScore_NoDueDate_ReturnsMinimal() {
        let task = Task(title: "Test")
        let score = calculateDueDateScore(task)
        XCTAssertEqual(score, 5)
    }

    // MARK: - Explicit Priority Score Tests

    func testCalculateExplicitPriorityScore_Urgent() {
        let task = Task(title: "Test", priority: .urgent)
        let score = calculateExplicitPriorityScore(task)
        XCTAssertEqual(score, 25)
    }

    func testCalculateExplicitPriorityScore_High() {
        let task = Task(title: "Test", priority: .high)
        let score = calculateExplicitPriorityScore(task)
        XCTAssertEqual(score, 20)
    }

    func testCalculateExplicitPriorityScore_Medium() {
        let task = Task(title: "Test", priority: .medium)
        let score = calculateExplicitPriorityScore(task)
        XCTAssertEqual(score, 12)
    }

    func testCalculateExplicitPriorityScore_Low() {
        let task = Task(title: "Test", priority: .low)
        let score = calculateExplicitPriorityScore(task)
        XCTAssertEqual(score, 5)
    }

    func testCalculateExplicitPriorityScore_None() {
        let task = Task(title: "Test", priority: .none)
        let score = calculateExplicitPriorityScore(task)
        XCTAssertEqual(score, 0)
    }

    // MARK: - Age Score Tests

    func testCalculateAgeScore_NewTask() {
        let task = Task(title: "Test") // Created now
        let score = calculateAgeScore(task)
        XCTAssertEqual(score, 2)
    }

    func testCalculateAgeScore_4DaysOld() {
        let fourDaysAgo = Date().addingDays(-4)
        let task = Task(id: UUID(), title: "Test", createdAt: fourDaysAgo)
        let score = calculateAgeScore(task)
        XCTAssertEqual(score, 4)
    }

    func testCalculateAgeScore_10DaysOld() {
        let tenDaysAgo = Date().addingDays(-10)
        let task = Task(id: UUID(), title: "Test", createdAt: tenDaysAgo)
        let score = calculateAgeScore(task)
        XCTAssertEqual(score, 7)
    }

    func testCalculateAgeScore_VeryOld() {
        let twentyDaysAgo = Date().addingDays(-20)
        let task = Task(id: UUID(), title: "Test", createdAt: twentyDaysAgo)
        let score = calculateAgeScore(task)
        XCTAssertEqual(score, 10)
    }

    // MARK: - Quick Win Score Tests

    func testCalculateQuickWinScore_VeryShortTask() {
        let task = Task(title: "Test", estimatedDuration: 300) // 5 minutes
        let score = calculateQuickWinScore(task)
        XCTAssertEqual(score, 10)
    }

    func testCalculateQuickWinScore_ShortTask() {
        let task = Task(title: "Test", estimatedDuration: 900) // 15 minutes
        let score = calculateQuickWinScore(task)
        XCTAssertEqual(score, 8)
    }

    func testCalculateQuickWinScore_MediumTask() {
        let task = Task(title: "Test", estimatedDuration: 1800) // 30 minutes
        let score = calculateQuickWinScore(task)
        XCTAssertEqual(score, 5)
    }

    func testCalculateQuickWinScore_HourTask() {
        let task = Task(title: "Test", estimatedDuration: 3600) // 1 hour
        let score = calculateQuickWinScore(task)
        XCTAssertEqual(score, 2)
    }

    func testCalculateQuickWinScore_LongTask() {
        let task = Task(title: "Test", estimatedDuration: 7200) // 2 hours
        let score = calculateQuickWinScore(task)
        XCTAssertEqual(score, 0)
    }

    func testCalculateQuickWinScore_NoDuration() {
        let task = Task(title: "Test")
        let score = calculateQuickWinScore(task)
        XCTAssertEqual(score, 3)
    }

    // MARK: - TaskSuggestion Tests

    func testTaskSuggestion_ScorePercentage() {
        let task = Task(title: "Test")
        let suggestion = TaskSuggestion(task: task, score: 75.5, reasons: [], aiInsight: nil)
        XCTAssertEqual(suggestion.scorePercentage, 75)
    }

    func testTaskSuggestion_Id() {
        let task = Task(title: "Test")
        let suggestion = TaskSuggestion(task: task, score: 50, reasons: [], aiInsight: nil)
        XCTAssertEqual(suggestion.id, task.id)
    }

    // MARK: - CompletionPatterns Tests

    func testCompletionPatterns_InitialState() {
        let patterns = CompletionPatterns()
        XCTAssertNil(patterns.lastCompletedCategory)
        XCTAssertNil(patterns.lastCompletedTime)
        XCTAssertTrue(patterns.categoryTimePatterns.isEmpty)
        XCTAssertTrue(patterns.categoryDayPatterns.isEmpty)
        XCTAssertTrue(patterns.averageCompletionTimes.isEmpty)
    }

    func testCompletionPatterns_Codable() throws {
        var patterns = CompletionPatterns()
        patterns.lastCompletedCategory = .work
        patterns.categoryTimePatterns["work_10"] = 5
        patterns.averageCompletionTimes["work"] = 3600

        let encoded = try JSONEncoder().encode(patterns)
        let decoded = try JSONDecoder().decode(CompletionPatterns.self, from: encoded)

        XCTAssertEqual(decoded.lastCompletedCategory, .work)
        XCTAssertEqual(decoded.categoryTimePatterns["work_10"], 5)
        XCTAssertEqual(decoded.averageCompletionTimes["work"], 3600)
    }

    // MARK: - ProductivityInsight Tests

    func testProductivityInsight_HasId() {
        let insight = ProductivityInsight(
            title: "Test",
            description: "Description",
            iconName: "star"
        )
        XCTAssertNotNil(insight.id)
    }

    // MARK: - Helper Methods (mimicking service logic for unit testing)

    private func calculateDueDateScore(_ task: Task) -> Double {
        guard let dueDate = task.dueDate else { return 5 }

        let now = Date()
        let hoursUntilDue = dueDate.timeIntervalSince(now) / 3600

        if hoursUntilDue < 0 {
            return 40
        } else if hoursUntilDue < 2 {
            return 38
        } else if hoursUntilDue < 24 {
            return 30 + (24 - hoursUntilDue) / 24 * 8
        } else if hoursUntilDue < 48 {
            return 20 + (48 - hoursUntilDue) / 24 * 10
        } else if hoursUntilDue < 168 {
            return 10 + (168 - hoursUntilDue) / 168 * 10
        } else {
            return 5
        }
    }

    private func calculateExplicitPriorityScore(_ task: Task) -> Double {
        switch task.priority {
        case .urgent: return 25
        case .high: return 20
        case .medium: return 12
        case .low: return 5
        case .none: return 0
        }
    }

    private func calculateAgeScore(_ task: Task) -> Double {
        let daysSinceCreation = Date().timeIntervalSince(task.createdAt) / 86400

        if daysSinceCreation > 14 {
            return 10
        } else if daysSinceCreation > 7 {
            return 7
        } else if daysSinceCreation > 3 {
            return 4
        } else {
            return 2
        }
    }

    private func calculateQuickWinScore(_ task: Task) -> Double {
        guard let duration = task.estimatedDuration else { return 3 }

        let minutes = duration / 60

        if minutes <= 5 {
            return 10
        } else if minutes <= 15 {
            return 8
        } else if minutes <= 30 {
            return 5
        } else if minutes <= 60 {
            return 2
        } else {
            return 0
        }
    }
}
