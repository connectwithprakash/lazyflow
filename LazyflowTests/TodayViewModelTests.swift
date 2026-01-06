import XCTest
import Combine
@testable import Lazyflow

@MainActor
final class TodayViewModelTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var viewModel: TodayViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        viewModel = TodayViewModel(taskService: taskService)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllData()
        persistenceController = nil
        taskService = nil
        viewModel = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests

    func testInitialState_IsEmpty() {
        XCTAssertTrue(viewModel.overdueTasks.isEmpty)
        XCTAssertTrue(viewModel.todayTasks.isEmpty)
        XCTAssertTrue(viewModel.completedTodayTasks.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showAddTask)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertTrue(viewModel.searchQuery.isEmpty)
    }

    // MARK: - Refresh Tasks Tests

    func testRefreshTasks_WithTodayTasks() async throws {
        taskService.createTask(title: "Today Task 1", dueDate: Date())
        taskService.createTask(title: "Today Task 2", dueDate: Date())

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.todayTasks.count, 2)
        XCTAssertEqual(viewModel.overdueTasks.count, 0)
    }

    func testRefreshTasks_WithOverdueTasks() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        taskService.createTask(title: "Overdue Task", dueDate: yesterday)

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.overdueTasks.count, 1)
        XCTAssertEqual(viewModel.overdueTasks.first?.title, "Overdue Task")
    }

    func testRefreshTasks_WithCompletedTasks() async throws {
        let task = taskService.createTask(title: "Completed Task", dueDate: Date())
        taskService.toggleTaskCompletion(task)

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTodayTasks.count, 1)
        XCTAssertTrue(viewModel.todayTasks.isEmpty)
    }

    func testRefreshTasks_MixedTasks() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        taskService.createTask(title: "Overdue Task", dueDate: yesterday)
        taskService.createTask(title: "Today Task", dueDate: Date())
        let completedTask = taskService.createTask(title: "Completed Task", dueDate: Date())
        taskService.toggleTaskCompletion(completedTask)
        taskService.createTask(title: "Tomorrow Task", dueDate: tomorrow)

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.overdueTasks.count, 1)
        XCTAssertEqual(viewModel.todayTasks.count, 1)
        XCTAssertEqual(viewModel.completedTodayTasks.count, 1)
    }

    // MARK: - Task Counts Tests

    func testTotalTaskCount() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        taskService.createTask(title: "Overdue Task", dueDate: yesterday)
        taskService.createTask(title: "Today Task 1", dueDate: Date())
        taskService.createTask(title: "Today Task 2", dueDate: Date())

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.totalTaskCount, 3)
    }

    func testCompletedTaskCount() async throws {
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        let task2 = taskService.createTask(title: "Task 2", dueDate: Date())
        taskService.createTask(title: "Task 3", dueDate: Date())

        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.completedTaskCount, 2)
    }

    // MARK: - Progress Tests

    func testProgressPercentage_NoTasks() {
        viewModel.refreshTasks()
        XCTAssertEqual(viewModel.progressPercentage, 0)
    }

    func testProgressPercentage_AllCompleted() async throws {
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        let task2 = taskService.createTask(title: "Task 2", dueDate: Date())

        taskService.toggleTaskCompletion(task1)
        taskService.toggleTaskCompletion(task2)

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.progressPercentage, 1.0)
    }

    func testProgressPercentage_HalfCompleted() async throws {
        let task1 = taskService.createTask(title: "Task 1", dueDate: Date())
        taskService.createTask(title: "Task 2", dueDate: Date())

        taskService.toggleTaskCompletion(task1)

        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.progressPercentage, 0.5)
    }

    // MARK: - Actions Tests

    func testToggleTaskCompletion() async throws {
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.todayTasks.count, 1)
        XCTAssertEqual(viewModel.completedTodayTasks.count, 0)

        viewModel.toggleTaskCompletion(task)
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.todayTasks.count, 0)
        XCTAssertEqual(viewModel.completedTodayTasks.count, 1)
    }

    func testDeleteTask() async throws {
        let task = taskService.createTask(title: "Task to Delete", dueDate: Date())
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.todayTasks.count, 1)

        viewModel.deleteTask(task)
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.todayTasks.count, 0)
    }

    func testUpdateTaskPriority() async throws {
        let task = taskService.createTask(title: "Test Task", dueDate: Date(), priority: .low)
        viewModel.refreshTasks()

        viewModel.updateTaskPriority(task, priority: .high)
        viewModel.refreshTasks()

        let updatedTask = viewModel.todayTasks.first { $0.id == task.id }
        XCTAssertEqual(updatedTask?.priority, .high)
    }

    func testUpdateTaskDueDate() async throws {
        let task = taskService.createTask(title: "Test Task", dueDate: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        viewModel.refreshTasks()
        XCTAssertEqual(viewModel.todayTasks.count, 1)

        viewModel.updateTaskDueDate(task, dueDate: tomorrow)
        viewModel.refreshTasks()

        // Task should no longer be in today's tasks
        XCTAssertEqual(viewModel.todayTasks.count, 0)
    }

    func testCreateTask() async throws {
        viewModel.createTask(title: "New Task", priority: .high)
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.todayTasks.count, 1)
        XCTAssertEqual(viewModel.todayTasks.first?.title, "New Task")
        XCTAssertEqual(viewModel.todayTasks.first?.priority, .high)
    }

    // MARK: - Search Tests

    func testSearchQuery_FiltersResults() async throws {
        taskService.createTask(title: "Buy groceries", dueDate: Date())
        taskService.createTask(title: "Call mom", dueDate: Date())
        taskService.createTask(title: "Buy present", dueDate: Date())

        viewModel.refreshTasks()
        XCTAssertEqual(viewModel.todayTasks.count, 3)

        viewModel.searchQuery = "Buy"

        // Wait for debounce
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.todayTasks.count, 2)
    }

    func testSearchQuery_Empty_ShowsAllTasks() async throws {
        taskService.createTask(title: "Task 1", dueDate: Date())
        taskService.createTask(title: "Task 2", dueDate: Date())

        viewModel.searchQuery = "Task"

        // Wait for debounce
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        viewModel.searchQuery = ""

        // Wait for debounce
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.todayTasks.count, 2)
    }

    // MARK: - Reactive Updates Tests

    func testTaskServiceChanges_UpdatesViewModel() async throws {
        let expectation = XCTestExpectation(description: "Tasks updated")

        viewModel.$todayTasks
            .dropFirst()
            .sink { tasks in
                if !tasks.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        taskService.createTask(title: "New Task", dueDate: Date())

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
