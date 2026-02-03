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

        // Wait for preload to complete by polling isPreloading
        let expectation = expectation(description: "Preload completes")
        _Concurrency.Task {
            // Wait until preloading starts
            while !dailySummaryService.isPreloading {
                try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            // Wait until preloading finishes
            while dailySummaryService.isPreloading {
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

        // Wait for preload to complete by polling isPreloading
        let expectation = expectation(description: "Preload completes")
        _Concurrency.Task {
            // Wait until preloading starts
            while !dailySummaryService.isPreloading {
                try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            // Wait until preloading finishes
            while dailySummaryService.isPreloading {
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
}
