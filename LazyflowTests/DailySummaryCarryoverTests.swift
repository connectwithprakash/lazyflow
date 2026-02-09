import XCTest
@testable import Lazyflow

@MainActor
final class DailySummaryCarryoverTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var dailySummaryService: DailySummaryService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        dailySummaryService = DailySummaryService(taskService: taskService, llmService: .shared)

        UserDefaults.standard.removeObject(forKey: "daily_summary_history")
        UserDefaults.standard.removeObject(forKey: "last_summary_date")
        UserDefaults.standard.removeObject(forKey: "streak_data")
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskService = nil
        dailySummaryService = nil

        UserDefaults.standard.removeObject(forKey: "daily_summary_history")
        UserDefaults.standard.removeObject(forKey: "last_summary_date")
        UserDefaults.standard.removeObject(forKey: "streak_data")
    }

    // MARK: - Carryover Tasks

    func testCarryover_NoUnfinishedTasks_EmptyCarryover() async throws {
        // Create and complete a task due today
        let task = taskService.createTask(title: "Done Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertTrue(summary.carryoverTasks.isEmpty)
    }

    func testCarryover_UnfinishedTodayTask_IncludedInCarryover() async throws {
        // Create an incomplete task due today
        _ = taskService.createTask(title: "Unfinished Task", dueDate: Date())

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.carryoverTasks.count, 1)
        XCTAssertEqual(summary.carryoverTasks.first?.title, "Unfinished Task")
    }

    func testCarryover_OverdueTask_IncludedInCarryover() async throws {
        // Create an incomplete task due yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        _ = taskService.createTask(title: "Overdue Task", dueDate: yesterday)

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.carryoverTasks.count, 1)
        XCTAssertEqual(summary.carryoverTasks.first?.title, "Overdue Task")
        XCTAssertTrue(summary.carryoverTasks.first?.isOverdue ?? false)
    }

    func testCarryover_CompletedTasks_NotIncluded() async throws {
        // Create two tasks: one completed, one not
        let task1 = taskService.createTask(title: "Completed Task", dueDate: Date())
        taskService.toggleTaskCompletion(task1)
        _ = taskService.createTask(title: "Still Pending", dueDate: Date())

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.carryoverTasks.count, 1)
        XCTAssertEqual(summary.carryoverTasks.first?.title, "Still Pending")
    }

    func testCarryover_MixedTodayAndOverdue() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        _ = taskService.createTask(title: "Overdue", dueDate: yesterday)
        _ = taskService.createTask(title: "Today Pending", dueDate: Date())

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.carryoverTasks.count, 2)
    }

    func testCarryover_MaxLimit_CapsAt10() async throws {
        // Create 15 incomplete tasks due today
        for i in 1...15 {
            _ = taskService.createTask(title: "Task \(i)", dueDate: Date())
        }

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.carryoverTasks.count, 10)
    }

    func testCarryover_SortedByPriority() async throws {
        _ = taskService.createTask(title: "Low Task", dueDate: Date(), priority: .low)
        _ = taskService.createTask(title: "Urgent Task", dueDate: Date(), priority: .urgent)
        _ = taskService.createTask(title: "High Task", dueDate: Date(), priority: .high)

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.carryoverTasks.count, 3)
        // Sorted by priority descending: urgent, high, low
        XCTAssertEqual(summary.carryoverTasks[0].title, "Urgent Task")
        XCTAssertEqual(summary.carryoverTasks[1].title, "High Task")
        XCTAssertEqual(summary.carryoverTasks[2].title, "Low Task")
    }

    // MARK: - Suggested Priorities

    func testSuggestedPriorities_NoCarryover_Empty() async throws {
        let task = taskService.createTask(title: "Done Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertTrue(summary.suggestedPriorities.isEmpty)
    }

    func testSuggestedPriorities_MaxThree() async throws {
        // Create 5 incomplete tasks with various priorities
        _ = taskService.createTask(title: "Urgent 1", dueDate: Date(), priority: .urgent)
        _ = taskService.createTask(title: "High 1", dueDate: Date(), priority: .high)
        _ = taskService.createTask(title: "High 2", dueDate: Date(), priority: .high)
        _ = taskService.createTask(title: "Medium 1", dueDate: Date(), priority: .medium)
        _ = taskService.createTask(title: "Low 1", dueDate: Date(), priority: .low)

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.suggestedPriorities.count, 3)
    }

    func testSuggestedPriorities_HighestPriorityFirst() async throws {
        _ = taskService.createTask(title: "Low Task", dueDate: Date(), priority: .low)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        _ = taskService.createTask(title: "Overdue High", dueDate: yesterday, priority: .high)

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertEqual(summary.suggestedPriorities.first, "Overdue High")
    }

    // MARK: - hasCarryover

    func testHasCarryover_True_WhenUnfinishedExist() async throws {
        _ = taskService.createTask(title: "Pending", dueDate: Date())

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertTrue(summary.hasCarryover)
    }

    func testHasCarryover_False_WhenAllCompleted() async throws {
        let task = taskService.createTask(title: "Done", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        let summary = await dailySummaryService.generateSummary(for: Date(), persist: false)
        XCTAssertFalse(summary.hasCarryover)
    }

    // MARK: - Codable Backward Compatibility

    func testCodable_LegacyPayload_DecodesWithEmptyCarryover() throws {
        // Simulate a pre-carryover persisted summary (no carryoverTasks/suggestedPriorities keys)
        let legacyJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "date": 0,
            "tasksCompleted": 3,
            "totalTasksPlanned": 5,
            "completedTasks": [],
            "topCategory": 1,
            "totalMinutesWorked": 120,
            "productivityScore": 60.0,
            "createdAt": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DailySummaryData.self, from: legacyJSON)
        XCTAssertTrue(decoded.carryoverTasks.isEmpty)
        XCTAssertTrue(decoded.suggestedPriorities.isEmpty)
        XCTAssertEqual(decoded.tasksCompleted, 3)
    }
}
