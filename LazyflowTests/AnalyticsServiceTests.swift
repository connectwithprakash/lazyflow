import XCTest
@testable import Lazyflow

@MainActor
final class AnalyticsServiceTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var taskListService: TaskListService!
    var categoryService: CategoryService!
    var analyticsService: AnalyticsService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        taskListService = TaskListService(persistenceController: persistenceController)
        categoryService = CategoryService(persistenceController: persistenceController)
        analyticsService = AnalyticsService(
            taskService: taskService,
            taskListService: taskListService,
            categoryService: categoryService
        )
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskService = nil
        taskListService = nil
        categoryService = nil
        analyticsService = nil
    }

    // MARK: - Category Completion Rate Tests

    func testCategoryCompletionRate_NoTasks_ReturnsZero() {
        let rate = analyticsService.calculateCompletionRate(for: .work, in: .thisWeek)
        XCTAssertEqual(rate, 0)
    }

    func testCategoryCompletionRate_AllCompleted_Returns100() {
        // Create 5 completed work tasks
        for i in 0..<5 {
            let task = taskService.createTask(title: "Work task \(i)", category: .work)
            taskService.toggleTaskCompletion(task)
        }

        let rate = analyticsService.calculateCompletionRate(for: .work, in: .thisWeek)
        XCTAssertEqual(rate, 100, accuracy: 0.1)
    }

    func testCategoryCompletionRate_HalfCompleted_Returns50() {
        // Create 4 work tasks, complete 2
        for i in 0..<4 {
            let task = taskService.createTask(title: "Work task \(i)", category: .work)
            if i < 2 {
                taskService.toggleTaskCompletion(task)
            }
        }

        let rate = analyticsService.calculateCompletionRate(for: .work, in: .thisWeek)
        XCTAssertEqual(rate, 50, accuracy: 0.1)
    }

    func testCategoryCompletionRate_OnlyCountsSpecifiedCategory() {
        // Create work tasks (2 completed)
        let workTask1 = taskService.createTask(title: "Work 1", category: .work)
        taskService.toggleTaskCompletion(workTask1)
        let workTask2 = taskService.createTask(title: "Work 2", category: .work)
        taskService.toggleTaskCompletion(workTask2)

        // Create personal tasks (0 completed)
        _ = taskService.createTask(title: "Personal 1", category: .personal)
        _ = taskService.createTask(title: "Personal 2", category: .personal)

        let workRate = analyticsService.calculateCompletionRate(for: .work, in: .thisWeek)
        let personalRate = analyticsService.calculateCompletionRate(for: .personal, in: .thisWeek)

        XCTAssertEqual(workRate, 100, accuracy: 0.1)
        XCTAssertEqual(personalRate, 0, accuracy: 0.1)
    }

    // MARK: - Category Stats Tests

    func testGetCategoryStats_ReturnsAllCategories() {
        // Create tasks in different categories
        _ = taskService.createTask(title: "Work", category: .work)
        _ = taskService.createTask(title: "Personal", category: .personal)
        _ = taskService.createTask(title: "Health", category: .health)

        let stats = analyticsService.getCategoryStats(for: .thisWeek)

        // Should have stats for categories with tasks
        XCTAssertTrue(stats.contains { $0.category == .work })
        XCTAssertTrue(stats.contains { $0.category == .personal })
        XCTAssertTrue(stats.contains { $0.category == .health })
    }

    func testGetCategoryStats_CorrectCounts() {
        // Create 3 work tasks, complete 2
        for i in 0..<3 {
            let task = taskService.createTask(title: "Work \(i)", category: .work)
            if i < 2 {
                taskService.toggleTaskCompletion(task)
            }
        }

        let stats = analyticsService.getCategoryStats(for: .thisWeek)
        let workStats = stats.first { $0.category == .work }

        XCTAssertNotNil(workStats)
        XCTAssertEqual(workStats?.totalCount, 3)
        XCTAssertEqual(workStats?.completedCount, 2)
    }

    // MARK: - Work-Life Balance Tests

    func testWorkLifeBalance_NoTasks_Returns50_50() {
        let balance = analyticsService.calculateWorkLifeBalance(for: .thisWeek)

        XCTAssertEqual(balance.workPercentage, 50, accuracy: 0.1)
        XCTAssertEqual(balance.lifePercentage, 50, accuracy: 0.1)
    }

    func testWorkLifeBalance_OnlyWorkTasks_Returns100_0() {
        // Create only work tasks
        _ = taskService.createTask(title: "Work 1", category: .work)
        _ = taskService.createTask(title: "Work 2", category: .work)
        _ = taskService.createTask(title: "Finance 1", category: .finance)

        let balance = analyticsService.calculateWorkLifeBalance(for: .thisWeek)

        XCTAssertEqual(balance.workPercentage, 100, accuracy: 0.1)
        XCTAssertEqual(balance.lifePercentage, 0, accuracy: 0.1)
    }

    func testWorkLifeBalance_MixedTasks_CorrectRatio() {
        // Work categories: work, finance, learning (3 tasks)
        _ = taskService.createTask(title: "Work", category: .work)
        _ = taskService.createTask(title: "Finance", category: .finance)
        _ = taskService.createTask(title: "Learning", category: .learning)

        // Life categories: personal, health (2 tasks)
        _ = taskService.createTask(title: "Personal", category: .personal)
        _ = taskService.createTask(title: "Health", category: .health)

        let balance = analyticsService.calculateWorkLifeBalance(for: .thisWeek)

        // 3 work / 5 total = 60%
        XCTAssertEqual(balance.workPercentage, 60, accuracy: 0.1)
        XCTAssertEqual(balance.lifePercentage, 40, accuracy: 0.1)
    }

    func testWorkLifeBalanceScore_PerfectBalance_Returns100() {
        // Create equal work and life tasks matching target 60/40
        for _ in 0..<6 {
            _ = taskService.createTask(title: "Work", category: .work)
        }
        for _ in 0..<4 {
            _ = taskService.createTask(title: "Personal", category: .personal)
        }

        let balance = analyticsService.calculateWorkLifeBalance(for: .thisWeek)

        // 60/40 matches default target of 60/40
        XCTAssertEqual(balance.score, 100, accuracy: 1)
    }

    // MARK: - List Health Tests

    func testListHealth_NoTasks_ReturnsNeutralScore() {
        let list = taskListService.createList(name: "Test List")

        let health = analyticsService.calculateListHealth(for: list.id, in: .thisWeek)

        XCTAssertNotNil(health)
        XCTAssertEqual(health?.healthScore ?? 0, 50.0, accuracy: 5.0) // Neutral score for empty list
        XCTAssertEqual(health?.totalTasksInPeriod, 0)
    }

    func testListHealth_AllCompleted_ReturnsHighScore() {
        let list = taskListService.createList(name: "Test List")

        // Create and complete tasks in this list
        for i in 0..<5 {
            let task = taskService.createTask(title: "Task \(i)", category: .work, listID: list.id)
            taskService.toggleTaskCompletion(task)
        }

        let health = analyticsService.calculateListHealth(for: list.id, in: .thisWeek)

        XCTAssertNotNil(health)
        XCTAssertGreaterThan(health?.healthScore ?? 0, 70)
        XCTAssertEqual(health?.totalTasksInPeriod, 5)
    }

    func testListHealth_ManyOverdue_ReturnsLowScore() {
        let list = taskListService.createList(name: "Test List")

        // Create overdue tasks
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        for i in 0..<5 {
            _ = taskService.createTask(title: "Overdue \(i)", dueDate: yesterday, category: .work, listID: list.id)
        }

        let health = analyticsService.calculateListHealth(for: list.id, in: .thisWeek)

        XCTAssertNotNil(health)
        XCTAssertLessThan(health?.healthScore ?? 100, 50)
    }

    func testListHealth_PeriodFiltering() {
        let list = taskListService.createList(name: "Test List")

        // Create a task today (should be in thisWeek)
        _ = taskService.createTask(title: "Today task", category: .work, listID: list.id)

        let weekHealth = analyticsService.calculateListHealth(for: list.id, in: .thisWeek)
        let todayHealth = analyticsService.calculateListHealth(for: list.id, in: .today)

        XCTAssertEqual(weekHealth?.totalTasksInPeriod, 1)
        XCTAssertEqual(todayHealth?.totalTasksInPeriod, 1)
    }

    func testGetAllListHealth_ReturnsOnlyListsWithTasksInPeriod() {
        let listWithTasks = taskListService.createList(name: "Active List")
        _ = taskListService.createList(name: "Empty List")

        _ = taskService.createTask(title: "Task", category: .work, listID: listWithTasks.id)

        let allHealth = analyticsService.getAllListHealth(for: .thisWeek)

        // Should only include the list with tasks in period
        XCTAssertEqual(allHealth.count, 1)
        XCTAssertEqual(allHealth.first?.list.id, listWithTasks.id)
    }

    // MARK: - Stale List Detection Tests

    func testStaleLists_ActiveList_NotStale() {
        let list = taskListService.createList(name: "Active List")

        // Create a task today (recent activity)
        _ = taskService.createTask(title: "Recent task", category: .work, listID: list.id)

        // List with recent activity should not be stale
        let staleLists = analyticsService.getStaleLists()

        XCTAssertFalse(staleLists.contains { $0.id == list.id })
    }

    func testStaleLists_UsesFixedThreshold() {
        let list = taskListService.createList(name: "Test List")

        // Create incomplete task today (makes list have incomplete tasks but recent activity)
        _ = taskService.createTask(title: "Incomplete", category: .work, listID: list.id)

        // List has recent activity, so shouldn't be stale (uses 7-day threshold, not period)
        let staleLists = analyticsService.getStaleLists()
        XCTAssertFalse(staleLists.contains { $0.id == list.id })

        // Verify threshold constant is defined
        XCTAssertEqual(AnalyticsService.staleThresholdDays, 7)
    }

    // MARK: - Unified Category Stats Tests

    func testUnifiedCategoryStats_SystemCategoriesOnly() {
        // Create tasks with system categories only
        _ = taskService.createTask(title: "Work", category: .work)
        _ = taskService.createTask(title: "Personal", category: .personal)

        let stats = analyticsService.getUnifiedCategoryStats(for: .thisWeek)

        XCTAssertEqual(stats.count, 2)
        XCTAssertTrue(stats.allSatisfy { !$0.isCustom })
    }

    func testUnifiedCategoryStats_CustomCategoryTakesPrecedence() {
        // Create a custom category
        let customCategory = categoryService.createCategory(name: "My Category", colorHex: "#FF0000", iconName: "star.fill")

        // Create task with custom category (customCategoryID should override system category)
        _ = taskService.createTask(title: "Custom Task", category: .work, customCategoryID: customCategory.id)

        let stats = analyticsService.getUnifiedCategoryStats(for: .thisWeek)

        // Should have one entry for the custom category
        XCTAssertEqual(stats.count, 1)
        XCTAssertTrue(stats.first?.isCustom ?? false)
        XCTAssertEqual(stats.first?.displayName, "My Category")
    }

    func testWorkLifeBalance_CustomCategoriesAsLife() {
        // Create a custom category
        let customCategory = categoryService.createCategory(name: "Hobby", colorHex: "#00FF00", iconName: "paintbrush.fill")

        // Create work tasks (system)
        for _ in 0..<3 {
            _ = taskService.createTask(title: "Work", category: .work)
        }

        // Create custom category tasks (should count as life)
        for _ in 0..<2 {
            _ = taskService.createTask(title: "Hobby", category: .uncategorized, customCategoryID: customCategory.id)
        }

        let balance = analyticsService.calculateWorkLifeBalance(for: .thisWeek)

        // 3 work / 5 total = 60% work, 2 custom / 5 total = 40% life
        XCTAssertEqual(balance.workPercentage, 60, accuracy: 0.1)
        XCTAssertEqual(balance.lifePercentage, 40, accuracy: 0.1)
    }

    // MARK: - Time Period Tests

    func testTimePeriod_ThisWeek_CorrectDateRange() {
        let period = AnalyticsPeriod.thisWeek

        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        XCTAssertEqual(calendar.isDate(period.startDate, inSameDayAs: weekStart), true)
    }

    func testTimePeriod_ThisMonth_CorrectDateRange() {
        let period = AnalyticsPeriod.thisMonth

        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

        XCTAssertEqual(calendar.isDate(period.startDate, inSameDayAs: monthStart), true)
    }

    // MARK: - Overview Stats Tests

    func testOverviewStats_CorrectTotals() {
        // Create 10 tasks, complete 7
        for i in 0..<10 {
            let task = taskService.createTask(title: "Task \(i)", category: .work)
            if i < 7 {
                taskService.toggleTaskCompletion(task)
            }
        }

        let overview = analyticsService.getOverviewStats(for: .thisWeek)

        XCTAssertEqual(overview.totalTasks, 10)
        XCTAssertEqual(overview.completedTasks, 7)
        XCTAssertEqual(overview.completionRate, 70, accuracy: 0.1)
    }
}
