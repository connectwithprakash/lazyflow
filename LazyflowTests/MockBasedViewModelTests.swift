import XCTest
@testable import Lazyflow

/// Tests demonstrating the mock-based DI pattern.
/// These tests use MockTaskService (pure in-memory) instead of Core Data,
/// making them faster and independent of the persistence layer.
@MainActor
final class MockBasedViewModelTests: XCTestCase {

    // MARK: - TodayViewModel with MockTaskService

    func testTodayViewModel_RefreshTasks_UsesTaskServiceFetching() {
        let mockService = MockTaskService()
        mockService.createTask(title: "Today Task", dueDate: Date(), priority: .high)
        mockService.createTask(title: "Today Task 2", dueDate: Date())

        let viewModel = TodayViewModel(taskService: mockService)
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.todayTasks.count, 2)
        XCTAssertTrue(mockService.calls.contains("fetchTodayTasks"))
        XCTAssertTrue(mockService.calls.contains("fetchOverdueTasks"))
    }

    func testTodayViewModel_ToggleCompletion_DelegatesToService() {
        let mockService = MockTaskService()
        let task = mockService.createTask(title: "Test Task", dueDate: Date())

        let viewModel = TodayViewModel(taskService: mockService)
        viewModel.toggleTaskCompletion(task)

        XCTAssertTrue(mockService.calls.contains("toggleTaskCompletion"))
        XCTAssertTrue(mockService.tasks.first?.isCompleted == true)
    }

    func testTodayViewModel_DeleteTask_DelegatesToService() {
        let mockService = MockTaskService()
        let task = mockService.createTask(title: "Task to Delete", dueDate: Date())

        let viewModel = TodayViewModel(taskService: mockService)
        viewModel.deleteTask(task)

        XCTAssertTrue(mockService.calls.contains("deleteTask"))
        XCTAssertTrue(mockService.tasks.isEmpty)
    }

    func testTodayViewModel_CreateTask_DelegatesToService() {
        let mockService = MockTaskService()
        let viewModel = TodayViewModel(taskService: mockService)

        viewModel.createTask(title: "New Task", priority: .high)

        XCTAssertTrue(mockService.calls.contains("createTask"))
        XCTAssertEqual(mockService.tasks.count, 1)
        XCTAssertEqual(mockService.tasks.first?.title, "New Task")
        XCTAssertEqual(mockService.tasks.first?.priority, .high)
    }

    func testTodayViewModel_OverdueTasks_FilteredCorrectly() {
        let mockService = MockTaskService()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        mockService.createTask(title: "Overdue Task", dueDate: yesterday)
        mockService.createTask(title: "Today Task", dueDate: Date())

        let viewModel = TodayViewModel(taskService: mockService)
        viewModel.refreshTasks()

        XCTAssertEqual(viewModel.overdueTasks.count, 1)
        XCTAssertEqual(viewModel.overdueTasks.first?.title, "Overdue Task")
        XCTAssertEqual(viewModel.todayTasks.count, 1)
    }

    // MARK: - TaskViewModel with MockTaskService

    func testTaskViewModel_SaveNewTask_CreatesViaService() {
        let mockService = MockTaskService()
        let viewModel = TaskViewModel(taskService: mockService)

        viewModel.title = "New Project Task"
        viewModel.priority = .high
        viewModel.hasDueDate = true
        viewModel.dueDate = Date()

        _ = viewModel.save()

        XCTAssertTrue(mockService.calls.contains("createTask"))
        XCTAssertEqual(mockService.tasks.count, 1)
        XCTAssertEqual(mockService.tasks.first?.title, "New Project Task")
        XCTAssertEqual(mockService.tasks.first?.priority, .high)
    }

    func testTaskViewModel_DeleteTask_RemovesViaService() {
        let mockService = MockTaskService()
        let task = mockService.createTask(title: "Existing Task", dueDate: Date())
        let viewModel = TaskViewModel(taskService: mockService, task: task)

        viewModel.delete()

        XCTAssertTrue(mockService.calls.contains("deleteTask"))
    }

    // MARK: - DependencyContainer

    func testDependencyContainer_DefaultsToSharedSingletons() {
        let container = DependencyContainer.shared
        // Verify container is created without errors — properties are non-nil
        XCTAssertNotNil(container.taskService)
        XCTAssertNotNil(container.persistence)
        XCTAssertNotNil(container.categoryService)
        XCTAssertNotNil(container.notificationService)
        XCTAssertNotNil(container.llmService)
    }

    func testDependencyContainer_AcceptsMocks() {
        let mockTask = MockTaskService()
        let mockCategory = MockCategoryService()

        let container = DependencyContainer(
            taskService: mockTask,
            categoryService: mockCategory
        )

        // Verify mock injection works
        XCTAssertTrue(container.taskService is MockTaskService)
        XCTAssertTrue(container.categoryService is MockCategoryService)
    }
}
