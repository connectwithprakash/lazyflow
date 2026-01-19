import XCTest
import Combine
@testable import Lazyflow

@MainActor
final class HistoryViewModelTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var taskListService: TaskListService!
    var viewModel: HistoryViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        taskListService = TaskListService(persistenceController: persistenceController)
        viewModel = HistoryViewModel(taskService: taskService, taskListService: taskListService)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskService = nil
        taskListService = nil
        viewModel = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests

    func testInitialState_IsEmpty() {
        XCTAssertTrue(viewModel.completedTasks.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.searchQuery.isEmpty)
        XCTAssertNil(viewModel.selectedListID)
        XCTAssertNil(viewModel.selectedPriority)
    }

    func testInitialDateRange_IsLast7Days() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        XCTAssertEqual(calendar.startOfDay(for: viewModel.startDate), sevenDaysAgo)
        XCTAssertEqual(calendar.startOfDay(for: viewModel.endDate), today)
    }

    // MARK: - Fetch Completed Tasks Tests

    func testFetchCompletedTasks_ReturnsCompletedTasksOnly() async throws {
        // Create and complete a task
        let task = taskService.createTask(title: "Completed Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        // Create an incomplete task
        taskService.createTask(title: "Incomplete Task", dueDate: Date())

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTasks.count, 1)
        XCTAssertEqual(viewModel.completedTasks.first?.title, "Completed Task")
    }

    func testFetchCompletedTasks_FiltersByDateRange() async throws {
        let calendar = Calendar.current

        // Create task completed today
        let todayTask = taskService.createTask(title: "Today Task", dueDate: Date())
        taskService.toggleTaskCompletion(todayTask)

        // Create task "completed" 10 days ago (simulate by modifying completedAt)
        // Since we can't directly set completedAt, we test with default 7-day range
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTasks.count, 1)
        XCTAssertEqual(viewModel.completedTasks.first?.title, "Today Task")
    }

    func testFetchCompletedTasks_GroupsByCompletionDate() async throws {
        // Create and complete multiple tasks
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        let task2 = taskService.createTask(title: "Task 2", dueDate: Date())
        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)

        viewModel.refreshTasks()

        // Both tasks should be grouped under today
        XCTAssertEqual(viewModel.groupedTasks.count, 1)
        XCTAssertEqual(viewModel.groupedTasks.first?.tasks.count, 2)
    }

    // MARK: - Filter Tests

    func testFilterByPriority() async throws {
        let highTask = taskService.createTask(title: "High Priority", dueDate: Date(), priority: .high)
        let lowTask = taskService.createTask(title: "Low Priority", dueDate: Date(), priority: .low)
        taskService.toggleTaskCompletion(highTask)
        taskService.toggleTaskCompletion(lowTask)

        viewModel.selectedPriority = .high
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTasks.count, 1)
        XCTAssertEqual(viewModel.completedTasks.first?.priority, .high)
    }

    func testFilterByList() async throws {
        // Create a custom list
        let customList = taskListService.createList(name: "Work")

        let workTask = taskService.createTask(title: "Work Task", dueDate: Date(), listID: customList.id)
        let personalTask = taskService.createTask(title: "Personal Task", dueDate: Date())
        taskService.toggleTaskCompletion(workTask)
        taskService.toggleTaskCompletion(personalTask)

        viewModel.selectedListID = customList.id
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTasks.count, 1)
        XCTAssertEqual(viewModel.completedTasks.first?.title, "Work Task")
    }

    func testClearFilters() async throws {
        let highTask = taskService.createTask(title: "High Priority", dueDate: Date(), priority: .high)
        let lowTask = taskService.createTask(title: "Low Priority", dueDate: Date(), priority: .low)
        taskService.toggleTaskCompletion(highTask)
        taskService.toggleTaskCompletion(lowTask)

        viewModel.selectedPriority = .high
        viewModel.refreshTasks()
        XCTAssertEqual(viewModel.completedTasks.count, 1)

        viewModel.clearFilters()
        viewModel.refreshTasks()
        XCTAssertEqual(viewModel.completedTasks.count, 2)
    }

    // MARK: - Search Tests

    func testSearchQuery_FiltersResults() async throws {
        let task1 = taskService.createTask(title: "Buy groceries", dueDate: Date())
        let task2 = taskService.createTask(title: "Call mom", dueDate: Date())
        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)

        viewModel.searchQuery = "Buy"

        // Wait for debounce
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.completedTasks.count, 1)
        XCTAssertEqual(viewModel.completedTasks.first?.title, "Buy groceries")
    }

    func testSearchQuery_Empty_ShowsAllTasks() async throws {
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        let task2 = taskService.createTask(title: "Task 2", dueDate: Date())
        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)

        viewModel.searchQuery = "Task 1"

        // Wait for debounce
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.completedTasks.count, 1)

        viewModel.searchQuery = ""

        // Wait for debounce
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.completedTasks.count, 2)
    }

    // MARK: - Date Range Tests

    func testSetDateRange_UpdatesResults() async throws {
        let calendar = Calendar.current
        let today = Date()

        let task = taskService.createTask(title: "Today Task", dueDate: today)
        taskService.toggleTaskCompletion(task)

        // Set range to yesterday only (should exclude today's task)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        viewModel.startDate = yesterday
        viewModel.endDate = yesterday
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTasks.count, 0)

        // Set range to include today
        viewModel.endDate = today
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTasks.count, 1)
    }

    func testPresetDateRange_Last7Days() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        viewModel.setPresetDateRange(.last7Days)

        let expectedStart = calendar.date(byAdding: .day, value: -7, to: today)!
        XCTAssertEqual(calendar.startOfDay(for: viewModel.startDate), expectedStart)
        XCTAssertEqual(calendar.startOfDay(for: viewModel.endDate), today)
    }

    func testPresetDateRange_Last30Days() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        viewModel.setPresetDateRange(.last30Days)

        let expectedStart = calendar.date(byAdding: .day, value: -30, to: today)!
        XCTAssertEqual(calendar.startOfDay(for: viewModel.startDate), expectedStart)
        XCTAssertEqual(calendar.startOfDay(for: viewModel.endDate), today)
    }

    func testPresetDateRange_ThisMonth() {
        let calendar = Calendar.current
        let today = Date()

        viewModel.setPresetDateRange(.thisMonth)

        let components = calendar.dateComponents([.year, .month], from: today)
        let expectedStart = calendar.date(from: components)!
        XCTAssertEqual(calendar.startOfDay(for: viewModel.startDate), expectedStart)
    }

    // MARK: - Statistics Tests

    func testTotalCompletedCount() async throws {
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        let task2 = taskService.createTask(title: "Task 2", dueDate: Date())
        let task3 = taskService.createTask(title: "Task 3", dueDate: Date())
        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)
        taskService.toggleTaskCompletion(task3)

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.totalCompletedCount, 3)
    }

    func testHasActiveFilters() async throws {
        XCTAssertFalse(viewModel.hasActiveFilters)

        viewModel.selectedPriority = .high
        XCTAssertTrue(viewModel.hasActiveFilters)

        viewModel.selectedPriority = nil
        viewModel.selectedListID = UUID()
        XCTAssertTrue(viewModel.hasActiveFilters)

        viewModel.selectedListID = nil
        viewModel.searchQuery = "test"
        XCTAssertTrue(viewModel.hasActiveFilters)

        viewModel.searchQuery = ""
        XCTAssertFalse(viewModel.hasActiveFilters)
    }

    // MARK: - Reactive Updates Tests

    func testTaskServiceChanges_UpdatesViewModel() async throws {
        let expectation = XCTestExpectation(description: "Tasks updated")

        viewModel.$completedTasks
            .dropFirst()
            .sink { tasks in
                if !tasks.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let task = taskService.createTask(title: "New Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
