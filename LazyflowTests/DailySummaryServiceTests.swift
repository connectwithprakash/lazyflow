import XCTest
@testable import Lazyflow

@MainActor
final class DailySummaryServiceTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var dailySummaryService: DailySummaryService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        dailySummaryService = DailySummaryService(taskService: taskService, llmService: .shared)

        // Clear any existing UserDefaults data
        UserDefaults.standard.removeObject(forKey: "daily_summary_history")
        UserDefaults.standard.removeObject(forKey: "last_summary_date")
        UserDefaults.standard.removeObject(forKey: "streak_data")
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskService = nil
        dailySummaryService = nil

        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "daily_summary_history")
        UserDefaults.standard.removeObject(forKey: "last_summary_date")
        UserDefaults.standard.removeObject(forKey: "streak_data")
    }

    // MARK: - Productivity Score Tests

    func testProductivityScore_ZeroCompleted_ReturnsZero() {
        let score = dailySummaryService.calculateProductivityScore(completed: 0, planned: 5)
        XCTAssertEqual(score, 0)
    }

    func testProductivityScore_HalfCompleted_Returns50() {
        let score = dailySummaryService.calculateProductivityScore(completed: 5, planned: 10)
        XCTAssertEqual(score, 50)
    }

    func testProductivityScore_AllCompleted_Returns100() {
        let score = dailySummaryService.calculateProductivityScore(completed: 10, planned: 10)
        XCTAssertEqual(score, 100)
    }

    func testProductivityScore_OverCompleted_CapsAt100() {
        let score = dailySummaryService.calculateProductivityScore(completed: 15, planned: 10)
        XCTAssertEqual(score, 100)
    }

    func testProductivityScore_NoPlanned_CalculatesBonus() {
        let score = dailySummaryService.calculateProductivityScore(completed: 3, planned: 0)
        // 3 * 20 = 60
        XCTAssertEqual(score, 60)
    }

    func testProductivityScore_ManyUnplanned_CapsAt100() {
        let score = dailySummaryService.calculateProductivityScore(completed: 10, planned: 0)
        // 10 * 20 = 200, capped at 100
        XCTAssertEqual(score, 100)
    }

    // MARK: - Default Encouragement Tests

    func testDefaultEncouragement_30DayStreak() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 30, score: 50)
        XCTAssertTrue(message.contains("30 days"))
        XCTAssertTrue(message.contains("unstoppable"))
    }

    func testDefaultEncouragement_14DayStreak() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 14, score: 50)
        XCTAssertTrue(message.contains("Two weeks"))
    }

    func testDefaultEncouragement_7DayStreak() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 7, score: 50)
        XCTAssertTrue(message.contains("week"))
    }

    func testDefaultEncouragement_3DayStreak() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 3, score: 50)
        XCTAssertTrue(message.contains("3 days"))
    }

    func testDefaultEncouragement_FirstDay() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 1, score: 50)
        XCTAssertTrue(message.contains("Great start"))
    }

    func testDefaultEncouragement_HighScore() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 0, score: 85)
        XCTAssertTrue(message.contains("Excellent"))
    }

    func testDefaultEncouragement_MediumScore() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 0, score: 50)
        XCTAssertTrue(message.contains("Solid progress"))
    }

    func testDefaultEncouragement_LowScore() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 0, score: 25)
        XCTAssertTrue(message.contains("Tomorrow"))
    }

    func testDefaultEncouragement_ZeroScore() {
        let message = dailySummaryService.getDefaultEncouragement(streak: 0, score: 0)
        XCTAssertTrue(message.contains("Ready to tackle"))
    }

    // MARK: - Summary Generation Tests

    func testGenerateSummary_WithNoTasks() async throws {
        let summary = await dailySummaryService.generateSummary()

        XCTAssertEqual(summary.tasksCompleted, 0)
        XCTAssertEqual(summary.totalTasksPlanned, 0)
        XCTAssertEqual(summary.productivityScore, 0)
        XCTAssertTrue(summary.completedTasks.isEmpty)
    }

    func testGenerateSummary_WithCompletedTasks() async throws {
        // Create and complete tasks for today
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        let task2 = taskService.createTask(title: "Task 2", dueDate: Date())
        taskService.createTask(title: "Task 3", dueDate: Date())

        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)

        let summary = await dailySummaryService.generateSummary()

        XCTAssertEqual(summary.tasksCompleted, 2)
        XCTAssertEqual(summary.totalTasksPlanned, 3)
        XCTAssertEqual(summary.completedTasks.count, 2)
    }

    func testGenerateSummary_SetsEncouragement() async throws {
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        let summary = await dailySummaryService.generateSummary()

        XCTAssertNotNil(summary.encouragement)
        XCTAssertFalse(summary.encouragement?.isEmpty ?? true)
    }

    // MARK: - Morning Briefing Tests

    func testGenerateMorningBriefing_WithNoTasks() async throws {
        let briefing = await dailySummaryService.generateMorningBriefing()

        XCTAssertEqual(briefing.yesterdayCompleted, 0)
        XCTAssertEqual(briefing.todayTasks.count, 0)
        XCTAssertNotNil(briefing.weeklyStats)
    }

    func testGenerateMorningBriefing_WithTodayTasks() async throws {
        // Create tasks for today
        taskService.createTask(title: "Today Task 1", dueDate: Date())
        taskService.createTask(title: "Today Task 2", dueDate: Date(), priority: .high)
        taskService.createTask(title: "Today Task 3", dueDate: Date(), priority: .urgent)

        let briefing = await dailySummaryService.generateMorningBriefing()

        XCTAssertEqual(briefing.todayTasks.count, 3)
        XCTAssertEqual(briefing.todayHighPriority, 2) // high + urgent
    }

    func testGenerateMorningBriefing_SetsMotivationalMessage() async throws {
        let briefing = await dailySummaryService.generateMorningBriefing()

        XCTAssertNotNil(briefing.motivationalMessage)
        XCTAssertFalse(briefing.motivationalMessage?.isEmpty ?? true)
    }

    // MARK: - Weekly Stats Tests

    func testCalculateWeeklyStats_NoHistory() {
        let stats = dailySummaryService.calculateWeeklyStats()

        XCTAssertEqual(stats.tasksCompletedThisWeek, 0)
        XCTAssertEqual(stats.totalTasksPlannedThisWeek, 0)
        XCTAssertEqual(stats.averageCompletionRate, 0)
    }

    func testWeeklyStats_HasStreak() {
        let stats = WeeklyStats(currentStreak: 5)
        XCTAssertTrue(stats.hasStreak)

        let noStreakStats = WeeklyStats(currentStreak: 0)
        XCTAssertFalse(noStreakStats.hasStreak)
    }

    func testWeeklyStats_FormattedCompletionRate() {
        let stats = WeeklyStats(averageCompletionRate: 75.5)
        XCTAssertEqual(stats.formattedCompletionRate, "75%")
    }

    func testWeeklyStats_WeeklyInsight_Excellent() {
        let stats = WeeklyStats(averageCompletionRate: 85)
        XCTAssertEqual(stats.weeklyInsight, "Excellent week so far!")
    }

    func testWeeklyStats_WeeklyInsight_Good() {
        let stats = WeeklyStats(averageCompletionRate: 65)
        XCTAssertEqual(stats.weeklyInsight, "Good progress this week!")
    }

    func testWeeklyStats_WeeklyInsight_KeepPushing() {
        let stats = WeeklyStats(averageCompletionRate: 45)
        XCTAssertEqual(stats.weeklyInsight, "Keep pushing forward!")
    }

    func testWeeklyStats_WeeklyInsight_SomeTasks() {
        let stats = WeeklyStats(tasksCompletedThisWeek: 1, averageCompletionRate: 20)
        XCTAssertEqual(stats.weeklyInsight, "Every task counts!")
    }

    func testWeeklyStats_WeeklyInsight_NoTasks() {
        let stats = WeeklyStats(tasksCompletedThisWeek: 0, averageCompletionRate: 0)
        XCTAssertEqual(stats.weeklyInsight, "Let's make this week count!")
    }

    // MARK: - Streak Data Tests

    func testStreakData_InitialState() {
        let streak = StreakData()

        XCTAssertEqual(streak.currentStreak, 0)
        XCTAssertEqual(streak.longestStreak, 0)
        XCTAssertNil(streak.lastProductiveDate)
        XCTAssertEqual(streak.totalProductiveDays, 0)
    }

    func testStreakData_RecordFirstProductiveDay() {
        var streak = StreakData()
        streak.recordDay(date: Date(), wasProductive: true)

        XCTAssertEqual(streak.currentStreak, 1)
        XCTAssertEqual(streak.totalProductiveDays, 1)
    }

    func testStreakData_ConsecutiveDays() {
        var streak = StreakData()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        streak.recordDay(date: yesterday, wasProductive: true)
        streak.recordDay(date: today, wasProductive: true)

        XCTAssertEqual(streak.currentStreak, 2)
        XCTAssertEqual(streak.totalProductiveDays, 2)
    }

    func testStreakData_NonConsecutiveDays_ResetsStreak() {
        var streak = StreakData()
        let today = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        streak.recordDay(date: twoDaysAgo, wasProductive: true)
        streak.recordDay(date: today, wasProductive: true)

        XCTAssertEqual(streak.currentStreak, 1) // Reset to 1
        XCTAssertEqual(streak.totalProductiveDays, 2)
    }

    func testStreakData_NonProductiveDay_ResetsStreak() {
        var streak = StreakData()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        streak.recordDay(date: yesterday, wasProductive: true)
        streak.recordDay(date: today, wasProductive: false)

        XCTAssertEqual(streak.currentStreak, 0)
        XCTAssertEqual(streak.totalProductiveDays, 1)
    }

    func testStreakData_LongestStreakTracked() {
        var streak = StreakData()
        let today = Date()

        // Build a 3-day streak
        for i in (0..<3).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            streak.recordDay(date: date, wasProductive: true)
        }

        XCTAssertEqual(streak.currentStreak, 3)
        XCTAssertEqual(streak.longestStreak, 3)
    }

    func testStreakData_Milestones() {
        var streak = StreakData(currentStreak: 7)
        XCTAssertTrue(streak.isAtMilestone)

        streak = StreakData(currentStreak: 8)
        XCTAssertFalse(streak.isAtMilestone)

        streak = StreakData(currentStreak: 14)
        XCTAssertTrue(streak.isAtMilestone)

        streak = StreakData(currentStreak: 30)
        XCTAssertTrue(streak.isAtMilestone)
    }

    func testStreakData_NextMilestone() {
        var streak = StreakData(currentStreak: 5)
        XCTAssertEqual(streak.nextMilestone, 7)

        streak = StreakData(currentStreak: 7)
        XCTAssertEqual(streak.nextMilestone, 14)

        streak = StreakData(currentStreak: 100)
        XCTAssertEqual(streak.nextMilestone, 365)
    }

    func testStreakData_DaysToNextMilestone() {
        let streak = StreakData(currentStreak: 5)
        XCTAssertEqual(streak.daysToNextMilestone, 2)
    }

    // MARK: - DailySummaryData Tests

    func testDailySummaryData_CompletionPercentage() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 3,
            totalTasksPlanned: 10,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 0,
            productivityScore: 30
        )

        XCTAssertEqual(summary.completionPercentage, 30)
    }

    func testDailySummaryData_CompletionPercentage_NoPlanned() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 3,
            totalTasksPlanned: 0,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 0,
            productivityScore: 100
        )

        XCTAssertEqual(summary.completionPercentage, 100)
    }

    func testDailySummaryData_CompletionPercentage_NoTasks() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 0,
            totalTasksPlanned: 0,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 0,
            productivityScore: 0
        )

        XCTAssertEqual(summary.completionPercentage, 0)
    }

    func testDailySummaryData_FormattedTimeWorked_MinutesOnly() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 0,
            totalTasksPlanned: 0,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 45,
            productivityScore: 0
        )

        XCTAssertEqual(summary.formattedTimeWorked, "45m")
    }

    func testDailySummaryData_FormattedTimeWorked_HoursAndMinutes() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 0,
            totalTasksPlanned: 0,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 90,
            productivityScore: 0
        )

        XCTAssertEqual(summary.formattedTimeWorked, "1h 30m")
    }

    func testDailySummaryData_FormattedTimeWorked_ExactHours() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 0,
            totalTasksPlanned: 0,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 120,
            productivityScore: 0
        )

        XCTAssertEqual(summary.formattedTimeWorked, "2h")
    }

    func testDailySummaryData_WasProductiveDay_True() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 5,
            totalTasksPlanned: 10,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 0,
            productivityScore: 50
        )

        XCTAssertTrue(summary.wasProductiveDay)
    }

    func testDailySummaryData_WasProductiveDay_False() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 2,
            totalTasksPlanned: 10,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 0,
            productivityScore: 20
        )

        XCTAssertFalse(summary.wasProductiveDay)
    }

    func testDailySummaryData_WasProductiveDay_NoPlanned() {
        let summary = DailySummaryData(
            date: Date(),
            tasksCompleted: 1,
            totalTasksPlanned: 0,
            completedTasks: [],
            topCategory: nil,
            totalMinutesWorked: 0,
            productivityScore: 100
        )

        XCTAssertTrue(summary.wasProductiveDay)
    }

    // MARK: - MorningBriefingData Tests

    func testMorningBriefingData_FormattedTodayTime() {
        var briefing = MorningBriefingData(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 45,
            weeklyStats: WeeklyStats()
        )

        XCTAssertEqual(briefing.formattedTodayTime, "45m")

        briefing = MorningBriefingData(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 90,
            weeklyStats: WeeklyStats()
        )

        XCTAssertEqual(briefing.formattedTodayTime, "1h 30m")
    }

    func testMorningBriefingData_YesterdayCompletionPercentage() {
        let briefing = MorningBriefingData(
            yesterdayCompleted: 7,
            yesterdayPlanned: 10,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 0,
            weeklyStats: WeeklyStats()
        )

        XCTAssertEqual(briefing.yesterdayCompletionPercentage, 70)
    }

    func testMorningBriefingData_HasTodayTasks() {
        var briefing = MorningBriefingData(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 0,
            weeklyStats: WeeklyStats()
        )

        XCTAssertFalse(briefing.hasTodayTasks)

        let taskSummary = TaskBriefingSummary(
            id: UUID(),
            title: "Test",
            priority: .medium,
            category: .work,
            dueTime: nil,
            estimatedDuration: nil
        )

        briefing = MorningBriefingData(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTasks: [taskSummary],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 0,
            weeklyStats: WeeklyStats()
        )

        XCTAssertTrue(briefing.hasTodayTasks)
    }

    func testMorningBriefingData_WasYesterdayProductive() {
        var briefing = MorningBriefingData(
            yesterdayCompleted: 5,
            yesterdayPlanned: 10,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 0,
            weeklyStats: WeeklyStats()
        )

        XCTAssertTrue(briefing.wasYesterdayProductive)

        briefing = MorningBriefingData(
            yesterdayCompleted: 2,
            yesterdayPlanned: 10,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 0,
            weeklyStats: WeeklyStats()
        )

        XCTAssertFalse(briefing.wasYesterdayProductive)
    }

    // MARK: - TaskBriefingSummary Tests

    func testTaskBriefingSummary_FormattedDueTime() {
        let dueTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let summary = TaskBriefingSummary(
            id: UUID(),
            title: "Test",
            priority: .medium,
            category: .work,
            dueTime: dueTime,
            estimatedDuration: nil
        )

        XCTAssertNotNil(summary.formattedDueTime)
    }

    func testTaskBriefingSummary_FormattedDuration() {
        var summary = TaskBriefingSummary(
            id: UUID(),
            title: "Test",
            priority: .medium,
            category: .work,
            dueTime: nil,
            estimatedDuration: 1800 // 30 minutes
        )

        XCTAssertEqual(summary.formattedDuration, "30m")

        summary = TaskBriefingSummary(
            id: UUID(),
            title: "Test",
            priority: .medium,
            category: .work,
            dueTime: nil,
            estimatedDuration: 5400 // 90 minutes
        )

        XCTAssertEqual(summary.formattedDuration, "1h 30m")

        summary = TaskBriefingSummary(
            id: UUID(),
            title: "Test",
            priority: .medium,
            category: .work,
            dueTime: nil,
            estimatedDuration: nil
        )

        XCTAssertNil(summary.formattedDuration)
    }

    // MARK: - CompletedTaskSummary Tests

    func testCompletedTaskSummary_InitFromValues() {
        let summary = CompletedTaskSummary(
            id: UUID(),
            title: "Completed Task",
            category: .work,
            priority: .high,
            estimatedDuration: 3600,
            completedAt: Date()
        )

        XCTAssertEqual(summary.title, "Completed Task")
        XCTAssertEqual(summary.category, .work)
        XCTAssertEqual(summary.priority, .high)
        XCTAssertEqual(summary.estimatedDuration, 3600)
    }

    // MARK: - Preview Mode Tests (Issue #165)

    func testGenerateSummary_WithPersistTrue_SetsHasTodaySummary() async throws {
        // Create a task to generate summary for
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Verify hasTodaySummary is false before generation
        XCTAssertFalse(dailySummaryService.hasTodaySummary)

        // Generate with persist: true (default)
        _ = await dailySummaryService.generateSummary(for: Date(), persist: true)

        // Verify hasTodaySummary is now true
        XCTAssertTrue(dailySummaryService.hasTodaySummary)
    }

    func testGenerateSummary_WithPersistFalse_DoesNotSetHasTodaySummary() async throws {
        // Create a task to generate summary for
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Verify hasTodaySummary is false before generation
        XCTAssertFalse(dailySummaryService.hasTodaySummary)

        // Generate with persist: false (preview mode)
        _ = await dailySummaryService.generateSummary(for: Date(), persist: false)

        // Verify hasTodaySummary is still false
        XCTAssertFalse(dailySummaryService.hasTodaySummary)
    }

    func testGenerateSummary_WithPersistFalse_DoesNotUpdateStreak() async throws {
        // Create and complete a task
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Record initial streak state
        let initialStreak = dailySummaryService.streakData.currentStreak

        // Generate with persist: false
        _ = await dailySummaryService.generateSummary(for: Date(), persist: false)

        // Streak should not have changed
        XCTAssertEqual(dailySummaryService.streakData.currentStreak, initialStreak)
    }

    func testGenerateSummary_WithPersistFalse_DoesNotSaveToHistory() async throws {
        // Create and complete a task
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Record initial history count
        let initialHistoryCount = dailySummaryService.summaryHistory.count

        // Generate with persist: false
        _ = await dailySummaryService.generateSummary(for: Date(), persist: false)

        // History count should not have changed
        XCTAssertEqual(dailySummaryService.summaryHistory.count, initialHistoryCount)
    }

    func testGenerateSummary_WithPersistFalse_StillReturnsSummaryData() async throws {
        // Create and complete tasks
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        let task2 = taskService.createTask(title: "Task 2", dueDate: Date())
        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)

        // Generate with persist: false
        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)

        // Summary should still contain valid data
        XCTAssertEqual(summary.tasksCompleted, 2)
        XCTAssertEqual(summary.completedTasks.count, 2)
        XCTAssertNotNil(summary.encouragement)
    }

    func testPreloadInsightsData_DoesNotSetHasTodaySummary() async throws {
        // Create and complete a task
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Verify hasTodaySummary is false before preload
        XCTAssertFalse(dailySummaryService.hasTodaySummary)

        // Call preload
        dailySummaryService.preloadInsightsData()

        // Wait for preload to complete by checking todaySummary (deterministic condition)
        let expectation = expectation(description: "Preload completes")
        _Concurrency.Task {
            while dailySummaryService.todaySummary == nil {
                try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify hasTodaySummary is still false after preload
        XCTAssertFalse(dailySummaryService.hasTodaySummary)
    }

    func testPreloadInsightsData_StillPopulatesTodaySummary() async throws {
        // Create and complete a task
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Verify todaySummary is nil before preload
        XCTAssertNil(dailySummaryService.todaySummary)

        // Call preload
        dailySummaryService.preloadInsightsData()

        // Wait for preload to complete by checking todaySummary (deterministic condition)
        let expectation = expectation(description: "Preload completes")
        _Concurrency.Task {
            while dailySummaryService.todaySummary == nil {
                try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify todaySummary is populated (for fast UI display)
        XCTAssertNotNil(dailySummaryService.todaySummary)
    }

    func testGenerateSummary_DefaultPersistIsTrue() async throws {
        // Create a task
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Verify hasTodaySummary is false before
        XCTAssertFalse(dailySummaryService.hasTodaySummary)

        // Generate without specifying persist (should default to true)
        _ = await dailySummaryService.generateSummary(for: Date())

        // Verify hasTodaySummary is true (default persist behavior)
        XCTAssertTrue(dailySummaryService.hasTodaySummary)
    }

    // MARK: - CalendarEventSummary Tests (Issue #166)

    func testCalendarEventSummary_DurationMinutes() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .minute, value: 90, to: start)!

        let event = CalendarEventSummary(
            id: "test-event",
            title: "Team Meeting",
            startDate: start,
            endDate: end,
            isAllDay: false,
            location: "Conference Room"
        )

        XCTAssertEqual(event.durationMinutes, 90)
    }

    func testCalendarEventSummary_FormattedTimeRange_AllDay() {
        let event = CalendarEventSummary(
            id: "test-event",
            title: "Conference",
            startDate: Date(),
            endDate: Date(),
            isAllDay: true,
            location: nil
        )

        XCTAssertEqual(event.formattedTimeRange, "All day")
    }

    func testCalendarEventSummary_FormattedStartTime_AllDay() {
        let event = CalendarEventSummary(
            id: "test-event",
            title: "Conference",
            startDate: Date(),
            endDate: Date(),
            isAllDay: true,
            location: nil
        )

        XCTAssertEqual(event.formattedStartTime, "All day")
    }

    func testCalendarEventSummary_FormattedStartTime_NotAllDay() {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let end = calendar.date(byAdding: .hour, value: 1, to: start)!

        let event = CalendarEventSummary(
            id: "test-event",
            title: "Meeting",
            startDate: start,
            endDate: end,
            isAllDay: false,
            location: nil
        )

        XCTAssertNotNil(event.formattedStartTime)
        XCTAssertNotEqual(event.formattedStartTime, "All day")
    }

    // MARK: - ScheduleSummary Tests (Issue #166)

    func testScheduleSummary_FormattedMeetingTime_MinutesOnly() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 45,
            meetingCount: 1,
            nextEvent: nil,
            largestFreeBlockMinutes: 120,
            allDayEvents: []
        )

        XCTAssertEqual(summary.formattedMeetingTime, "45m")
    }

    func testScheduleSummary_FormattedMeetingTime_HoursAndMinutes() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 150,
            meetingCount: 3,
            nextEvent: nil,
            largestFreeBlockMinutes: 60,
            allDayEvents: []
        )

        XCTAssertEqual(summary.formattedMeetingTime, "2h 30m")
    }

    func testScheduleSummary_FormattedMeetingTime_ExactHours() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 120,
            meetingCount: 2,
            nextEvent: nil,
            largestFreeBlockMinutes: 60,
            allDayEvents: []
        )

        XCTAssertEqual(summary.formattedMeetingTime, "2h")
    }

    func testScheduleSummary_FormattedFreeBlock_MinutesOnly() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 60,
            meetingCount: 1,
            nextEvent: nil,
            largestFreeBlockMinutes: 45,
            allDayEvents: []
        )

        XCTAssertEqual(summary.formattedFreeBlock, "45m")
    }

    func testScheduleSummary_FormattedFreeBlock_HoursAndMinutes() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 60,
            meetingCount: 1,
            nextEvent: nil,
            largestFreeBlockMinutes: 150,
            allDayEvents: []
        )

        XCTAssertEqual(summary.formattedFreeBlock, "2h 30m")
    }

    func testScheduleSummary_HasMeetings_True() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 60,
            meetingCount: 2,
            nextEvent: nil,
            largestFreeBlockMinutes: 120,
            allDayEvents: []
        )

        XCTAssertTrue(summary.hasMeetings)
    }

    func testScheduleSummary_HasMeetings_False() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 0,
            meetingCount: 0,
            nextEvent: nil,
            largestFreeBlockMinutes: 480,
            allDayEvents: []
        )

        XCTAssertFalse(summary.hasMeetings)
    }

    func testScheduleSummary_HasSignificantFreeBlock_True() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 60,
            meetingCount: 1,
            nextEvent: nil,
            largestFreeBlockMinutes: 60,
            allDayEvents: []
        )

        XCTAssertTrue(summary.hasSignificantFreeBlock)
    }

    func testScheduleSummary_HasSignificantFreeBlock_False() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 420,
            meetingCount: 10,
            nextEvent: nil,
            largestFreeBlockMinutes: 15,
            allDayEvents: []
        )

        XCTAssertFalse(summary.hasSignificantFreeBlock)
    }

    func testScheduleSummary_HasSignificantFreeBlock_ExactThreshold() {
        let summary = ScheduleSummary(
            totalMeetingMinutes: 60,
            meetingCount: 1,
            nextEvent: nil,
            largestFreeBlockMinutes: 30,
            allDayEvents: []
        )

        XCTAssertTrue(summary.hasSignificantFreeBlock)
    }

    // MARK: - MorningBriefingData Calendar Tests (Issue #166)

    func testMorningBriefingData_HasCalendarData_True() {
        let schedule = ScheduleSummary(
            totalMeetingMinutes: 60,
            meetingCount: 1,
            nextEvent: nil,
            largestFreeBlockMinutes: 120,
            allDayEvents: []
        )

        let briefing = MorningBriefingData(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 0,
            weeklyStats: WeeklyStats(),
            scheduleSummary: schedule
        )

        XCTAssertTrue(briefing.hasCalendarData)
    }

    func testMorningBriefingData_HasCalendarData_False() {
        let briefing = MorningBriefingData(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTasks: [],
            todayHighPriority: 0,
            todayOverdue: 0,
            todayEstimatedMinutes: 0,
            weeklyStats: WeeklyStats(),
            scheduleSummary: nil
        )

        XCTAssertFalse(briefing.hasCalendarData)
    }

    func testScheduleSummary_WithAllDayEvents() {
        let allDayEvent = CalendarEventSummary(
            id: "all-day-1",
            title: "Company Holiday",
            startDate: Date(),
            endDate: Date(),
            isAllDay: true,
            location: nil
        )

        let summary = ScheduleSummary(
            totalMeetingMinutes: 0,
            meetingCount: 0,
            nextEvent: nil,
            largestFreeBlockMinutes: 480,
            allDayEvents: [allDayEvent]
        )

        XCTAssertEqual(summary.allDayEvents.count, 1)
        XCTAssertTrue(summary.allDayEvents.first?.isAllDay ?? false)
    }

    func testScheduleSummary_WithNextEvent() {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let end = calendar.date(byAdding: .hour, value: 1, to: start)!

        let nextEvent = CalendarEventSummary(
            id: "next-1",
            title: "Team Standup",
            startDate: start,
            endDate: end,
            isAllDay: false,
            location: "Zoom"
        )

        let summary = ScheduleSummary(
            totalMeetingMinutes: 60,
            meetingCount: 1,
            nextEvent: nextEvent,
            largestFreeBlockMinutes: 120,
            allDayEvents: []
        )

        XCTAssertNotNil(summary.nextEvent)
        XCTAssertEqual(summary.nextEvent?.title, "Team Standup")
        XCTAssertEqual(summary.nextEvent?.location, "Zoom")
    }

    // MARK: - Schedule Calculation Edge Case Tests (Issue #166 - PR Review)

    func testCalculateLargestFreeBlock_NoEvents_ReturnsFullWorkday() {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        // Workday: 8 AM - 6 PM = 10 hours = 600 minutes
        let workdayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay)!
        let workdayEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay)!

        let result = dailySummaryService.calculateLargestFreeBlockFromIntervals(
            [],
            workdayStart: workdayStart,
            workdayEnd: workdayEnd
        )
        XCTAssertEqual(result, 600, "Empty events should return full workday (600 minutes)")
    }

    func testCalculateLargestFreeBlock_AllEventsOutsideWorkday_ReturnsFullWorkday() {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        // Workday: 8 AM - 6 PM
        let workdayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay)!
        let workdayEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay)!

        // Events all in evening (7 PM - 9 PM) - outside workday
        let eveningEventStart = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: startOfDay)!
        let eveningEventEnd = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: startOfDay)!

        let result = dailySummaryService.calculateLargestFreeBlockFromIntervals(
            [(start: eveningEventStart, end: eveningEventEnd)],
            workdayStart: workdayStart,
            workdayEnd: workdayEnd
        )

        XCTAssertEqual(result, 600, "Events outside workday should return full workday (600 minutes)")
    }

    func testCalculateLargestFreeBlock_EventsBeforeWorkday_ReturnsFullWorkday() {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        let workdayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay)!
        let workdayEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay)!

        // Early morning event (6 AM - 7 AM) - before workday
        let earlyEventStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: startOfDay)!
        let earlyEventEnd = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay)!

        let result = dailySummaryService.calculateLargestFreeBlockFromIntervals(
            [(start: earlyEventStart, end: earlyEventEnd)],
            workdayStart: workdayStart,
            workdayEnd: workdayEnd
        )

        XCTAssertEqual(result, 600, "Events before workday should return full workday (600 minutes)")
    }

    func testCalculateLargestFreeBlock_MidDayEvent_ReturnsCorrectGap() {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        let workdayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay)!
        let workdayEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay)!

        // Meeting from 12 PM - 1 PM (1 hour)
        let meetingStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
        let meetingEnd = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: startOfDay)!

        let result = dailySummaryService.calculateLargestFreeBlockFromIntervals(
            [(start: meetingStart, end: meetingEnd)],
            workdayStart: workdayStart,
            workdayEnd: workdayEnd
        )

        // Gap after meeting: 1 PM - 6 PM = 5 hours = 300 minutes
        // Gap before meeting: 8 AM - 12 PM = 4 hours = 240 minutes
        XCTAssertEqual(result, 300, "Largest gap should be 300 minutes (1 PM - 6 PM)")
    }

    func testFindNextEvent_AllEventsPassed_ReturnsNil() {
        let calendar = Calendar.current
        let now = Date()

        // Events all in the past
        let pastEvent1 = CalendarEventSummary(
            id: "past-1",
            title: "Morning Meeting",
            startDate: calendar.date(byAdding: .hour, value: -3, to: now)!,
            endDate: calendar.date(byAdding: .hour, value: -2, to: now)!,
            isAllDay: false,
            location: nil
        )
        let pastEvent2 = CalendarEventSummary(
            id: "past-2",
            title: "Lunch",
            startDate: calendar.date(byAdding: .hour, value: -2, to: now)!,
            endDate: calendar.date(byAdding: .hour, value: -1, to: now)!,
            isAllDay: false,
            location: nil
        )

        let result = dailySummaryService.findNextEvent(from: [pastEvent1, pastEvent2], now: now)

        XCTAssertNil(result, "Should return nil when all events have passed")
    }

    func testFindNextEvent_HasUpcomingEvent_ReturnsFirst() {
        let calendar = Calendar.current
        let now = Date()

        let pastEvent = CalendarEventSummary(
            id: "past-1",
            title: "Morning Meeting",
            startDate: calendar.date(byAdding: .hour, value: -1, to: now)!,
            endDate: now,
            isAllDay: false,
            location: nil
        )
        let futureEvent = CalendarEventSummary(
            id: "future-1",
            title: "Afternoon Call",
            startDate: calendar.date(byAdding: .hour, value: 1, to: now)!,
            endDate: calendar.date(byAdding: .hour, value: 2, to: now)!,
            isAllDay: false,
            location: nil
        )

        let result = dailySummaryService.findNextEvent(from: [pastEvent, futureEvent], now: now)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, "future-1")
        XCTAssertEqual(result?.title, "Afternoon Call")
    }

    // MARK: - AI Context Injection Tests (Issue #162)

    func testBuildEnrichedAIContext_ReturnsEmptyWhenNoLearningData() {
        // Clear any existing learning data
        AILearningService.shared.clearAllCorrections()
        AIContextService.shared.resetPatterns()

        // Build context
        let context = dailySummaryService.buildEnrichedAIContext(for: .dailySummary)

        // Should be empty or minimal when no learning data exists
        // The context might have minimal time info, but no user preferences
        XCTAssertFalse(context.contains("User often changes"))
        XCTAssertFalse(context.contains("Duration accuracy patterns"))
    }

    func testBuildEnrichedAIContext_IncludesCorrectionPatterns() {
        // Clear existing data
        AILearningService.shared.clearAllCorrections()

        // Record enough corrections to exceed quality threshold (need 10+ for 0.3 score)
        for i in 0..<12 {
            AILearningService.shared.recordCorrection(
                field: .priority,
                originalSuggestion: "Low",
                userChoice: "High",
                taskTitle: "Important meeting task \(i)"
            )
        }

        // Build context
        let context = dailySummaryService.buildEnrichedAIContext(for: .dailySummary)

        // Should include correction pattern
        XCTAssertTrue(context.contains("User often changes") || context.contains("user prefers"),
                      "Expected correction patterns in context: \(context)")
    }

    func testBuildEnrichedAIContext_IncludesDurationAccuracy() {
        // Clear existing data
        AILearningService.shared.clearAllCorrections()

        // Record enough corrections to exceed quality threshold
        for i in 0..<12 {
            AILearningService.shared.recordCorrection(
                field: .category,
                originalSuggestion: "Personal",
                userChoice: "Work",
                taskTitle: "Task \(i)"
            )
        }

        // Record duration accuracy data
        AILearningService.shared.recordDurationAccuracy(
            category: "work",
            estimatedMinutes: 30,
            actualMinutes: 45
        )
        AILearningService.shared.recordDurationAccuracy(
            category: "work",
            estimatedMinutes: 60,
            actualMinutes: 90
        )

        // Build context
        let context = dailySummaryService.buildEnrichedAIContext(for: .dailySummary)

        // Should include duration accuracy pattern (requires 2+ records)
        XCTAssertTrue(context.contains("Duration accuracy") || context.contains("takes"),
                      "Expected duration patterns in context: \(context)")
    }

    func testBuildEnrichedAIContext_RespectsMaxLength() {
        // Clear existing data
        AILearningService.shared.clearAllCorrections()

        // Add many corrections to potentially exceed limit
        for i in 0..<50 {
            AILearningService.shared.recordCorrection(
                field: .category,
                originalSuggestion: "Work",
                userChoice: "Personal",
                taskTitle: "Task number \(i) with some additional keywords"
            )
        }

        // Build context
        let context = dailySummaryService.buildEnrichedAIContext(for: .dailySummary)

        // Should be within token budget (1500 chars)
        XCTAssertLessThanOrEqual(context.count, 1500)
    }

    func testBuildEnrichedAIContext_DifferentForSummaryAndBriefing() {
        // Clear existing data
        AILearningService.shared.clearAllCorrections()
        AIContextService.shared.resetPatterns()

        // Record enough corrections to exceed quality threshold
        for i in 0..<12 {
            AILearningService.shared.recordCorrection(
                field: .priority,
                originalSuggestion: "Medium",
                userChoice: "High",
                taskTitle: "Important work task \(i)"
            )
        }

        // Build both contexts
        let summaryContext = dailySummaryService.buildEnrichedAIContext(for: .dailySummary)
        let briefingContext = dailySummaryService.buildEnrichedAIContext(for: .morningBriefing)

        // Both should include user preferences when available
        XCTAssertFalse(summaryContext.isEmpty, "Summary context should not be empty")
        XCTAssertFalse(briefingContext.isEmpty, "Briefing context should not be empty")
    }
}
