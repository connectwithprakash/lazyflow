import XCTest
@testable import Lazyflow

final class AIContextTests: XCTestCase {

    // MARK: - UserPatterns Tests

    func testUserPatterns_RecordCompletion() {
        var patterns = UserPatterns()

        patterns.recordCompletion(
            category: "Work",
            priority: "High",
            duration: 60,
            completedAt: Date()
        )

        XCTAssertEqual(patterns.categoryUsage["work"], 1)
        XCTAssertNotNil(patterns.averageDurations["work"])
    }

    func testUserPatterns_TopCategories() {
        var patterns = UserPatterns()

        // Record multiple completions
        for _ in 0..<5 {
            patterns.recordCompletion(category: "Work", priority: "High", duration: 30, completedAt: Date())
        }
        for _ in 0..<3 {
            patterns.recordCompletion(category: "Personal", priority: "Medium", duration: 15, completedAt: Date())
        }
        patterns.recordCompletion(category: "Health", priority: "Low", duration: 45, completedAt: Date())

        let top = patterns.topCategories(limit: 2)
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top.first, "work")
    }

    func testUserPatterns_PreferredTime_Morning() {
        var patterns = UserPatterns()

        // Record work tasks in morning hours (9 AM)
        let calendar = Calendar.current
        let morningDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

        for _ in 0..<5 {
            patterns.recordCompletion(category: "Work", priority: "High", duration: 60, completedAt: morningDate)
        }

        let preferred = patterns.preferredTime(for: "work")
        XCTAssertEqual(preferred, "morning")
    }

    func testUserPatterns_PreferredTime_Evening() {
        var patterns = UserPatterns()

        let calendar = Calendar.current
        let eveningDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!

        for _ in 0..<5 {
            patterns.recordCompletion(category: "Personal", priority: "Medium", duration: 30, completedAt: eveningDate)
        }

        let preferred = patterns.preferredTime(for: "personal")
        XCTAssertEqual(preferred, "evening")
    }

    func testUserPatterns_AverageDuration() {
        var patterns = UserPatterns()

        patterns.recordCompletion(category: "Work", priority: "High", duration: 60, completedAt: Date())
        patterns.recordCompletion(category: "Work", priority: "High", duration: 40, completedAt: Date())

        let avg = patterns.averageDuration(for: "work")
        XCTAssertNotNil(avg)
        XCTAssertGreaterThan(avg!, 0)
    }

    // MARK: - AIContext Tests

    func testAIContext_TimeContext_Morning() {
        let calendar = Calendar.current
        let morningDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

        let timeContext = AIContext.TimeContext(date: morningDate)

        XCTAssertEqual(timeContext.timeOfDay, "morning")
        XCTAssertEqual(timeContext.currentHour, 9)
    }

    func testAIContext_TimeContext_Afternoon() {
        let calendar = Calendar.current
        let afternoonDate = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!

        let timeContext = AIContext.TimeContext(date: afternoonDate)

        XCTAssertEqual(timeContext.timeOfDay, "afternoon")
    }

    func testAIContext_TimeContext_Evening() {
        let calendar = Calendar.current
        let eveningDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!

        let timeContext = AIContext.TimeContext(date: eveningDate)

        XCTAssertEqual(timeContext.timeOfDay, "evening")
    }

    func testAIContext_TimeContext_Weekend() {
        // Find next Saturday
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilSaturday = (7 - weekday) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: today)!

        let timeContext = AIContext.TimeContext(date: saturday)

        XCTAssertTrue(timeContext.isWeekend)
    }

    func testAIContext_EmptyContext() {
        let context = AIContext.empty

        XCTAssertTrue(context.recentTasks.isEmpty)
        XCTAssertTrue(context.customCategories.isEmpty)
        XCTAssertNil(context.taskContext)
    }

    func testAIContext_ToPromptString_IncludesTimeContext() {
        let context = AIContext(
            recentTasks: [],
            userPatterns: UserPatterns(),
            correctionsSummary: "",
            customCategories: [],
            timeContext: AIContext.TimeContext(),
            taskContext: nil
        )

        let prompt = context.toPromptString()

        XCTAssertTrue(prompt.contains("Current time:"))
    }

    func testAIContext_ToPromptString_IncludesRecentTasks() {
        let recentTask = AIContext.RecentTaskContext(
            title: "Test task",
            category: "Work",
            priority: "High",
            duration: 30,
            completedAt: Date()
        )

        let context = AIContext(
            recentTasks: [recentTask],
            userPatterns: UserPatterns(),
            correctionsSummary: "",
            customCategories: [],
            timeContext: AIContext.TimeContext(),
            taskContext: nil
        )

        let prompt = context.toPromptString()

        XCTAssertTrue(prompt.contains("Recent tasks"))
        XCTAssertTrue(prompt.contains("Test task"))
    }

    func testAIContext_ToPromptString_IncludesCustomCategories() {
        let context = AIContext(
            recentTasks: [],
            userPatterns: UserPatterns(),
            correctionsSummary: "",
            customCategories: ["Research", "Meetings"],
            timeContext: AIContext.TimeContext(),
            taskContext: nil
        )

        let prompt = context.toPromptString()

        XCTAssertTrue(prompt.contains("custom categories"))
        XCTAssertTrue(prompt.contains("Research"))
        XCTAssertTrue(prompt.contains("Meetings"))
    }

    // MARK: - AIContextService Tests

    func testAIContextService_BuildContext_NotNil() {
        let context = AIContextService.shared.buildContext()

        XCTAssertNotNil(context)
        XCTAssertNotNil(context.timeContext)
    }

    func testAIContextService_BuildContextString_NotEmpty() {
        let contextString = AIContextService.shared.buildContextString()

        XCTAssertFalse(contextString.isEmpty)
        XCTAssertTrue(contextString.contains("Current time"))
    }

    func testAIContextService_ContextQuality_InRange() {
        let quality = AIContextService.shared.contextQuality

        XCTAssertGreaterThanOrEqual(quality, 0.0)
        XCTAssertLessThanOrEqual(quality, 1.0)
    }
}
