import XCTest
import Combine
@testable import Lazyflow

@MainActor
final class ListsViewModelTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var taskListService: TaskListService!
    var viewModel: ListsViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        taskListService = TaskListService(persistenceController: persistenceController)
        viewModel = ListsViewModel(taskListService: taskListService, taskService: taskService)
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

    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showAddList)
        XCTAssertNil(viewModel.selectedList)
        XCTAssertNil(viewModel.editingList)
        XCTAssertEqual(viewModel.newListName, "")
        XCTAssertEqual(viewModel.newListIcon, "list.bullet")
    }

    // MARK: - Create List Tests

    func testCanCreateList_EmptyName_ReturnsFalse() {
        viewModel.newListName = ""
        XCTAssertFalse(viewModel.canCreateList)
    }

    func testCanCreateList_WhitespaceOnly_ReturnsFalse() {
        viewModel.newListName = "   "
        XCTAssertFalse(viewModel.canCreateList)
    }

    func testCanCreateList_ValidName_ReturnsTrue() {
        viewModel.newListName = "Work"
        XCTAssertTrue(viewModel.canCreateList)
    }

    func testCreateList_ValidName_CreatesListAndResetsForm() async throws {
        viewModel.newListName = "Work List"
        viewModel.newListColor = "#FF5459"
        viewModel.newListIcon = "briefcase"

        viewModel.createList()

        // Wait for async updates
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Form should be reset
        XCTAssertEqual(viewModel.newListName, "")
        XCTAssertEqual(viewModel.newListIcon, "list.bullet")
        XCTAssertFalse(viewModel.showAddList)

        // List should be created
        let workList = viewModel.lists.first { $0.name == "Work List" }
        XCTAssertNotNil(workList)
    }

    func testCreateList_EmptyName_DoesNotCreate() async throws {
        viewModel.newListName = "   "
        let initialCount = viewModel.customLists.count

        viewModel.createList()

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.customLists.count, initialCount)
    }

    // MARK: - Delete List Tests

    func testDeleteList_RemovesList() async throws {
        // Create a list first
        let list = taskListService.createList(name: "To Delete")

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let initialCount = viewModel.lists.count

        viewModel.deleteList(list)

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        XCTAssertLessThan(viewModel.lists.count, initialCount)
    }

    // MARK: - Task Count Tests

    func testGetTaskCount_EmptyList_ReturnsZero() async throws {
        let list = taskListService.createList(name: "Empty List")

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let count = viewModel.getTaskCount(for: list)
        XCTAssertEqual(count, 0)
    }

    func testGetTaskCount_WithTasks() async throws {
        let list = taskListService.createList(name: "Test List")
        taskService.createTask(title: "Task 1", listID: list.id)
        taskService.createTask(title: "Task 2", listID: list.id)
        taskService.createTask(title: "Task 3", listID: list.id)

        try await _Concurrency.Task.sleep(nanoseconds: 200_000_000)

        let count = viewModel.getTaskCount(for: list)
        XCTAssertEqual(count, 3)
    }

    // MARK: - Smart List Tests

    func testInboxList_ReturnsDefaultInbox() {
        let inbox = viewModel.inboxList
        XCTAssertNotNil(inbox)
        XCTAssertTrue(inbox?.isDefault ?? false)
    }

    func testTodayTaskCount_OnlyCountsIncomplete() async throws {
        // Create tasks due today
        let task1 = taskService.createTask(title: "Today 1", dueDate: Date())
        taskService.createTask(title: "Today 2", dueDate: Date())

        // Complete one
        taskService.toggleTaskCompletion(task1)

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Should only count incomplete
        XCTAssertEqual(viewModel.todayTaskCount, 1)
    }

    func testCustomLists_ExcludesDefaultLists() async throws {
        // Create custom lists
        taskListService.createList(name: "Custom 1")
        taskListService.createList(name: "Custom 2")

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // All custom lists should not be default
        for list in viewModel.customLists {
            XCTAssertFalse(list.isDefault)
        }
    }

    // MARK: - Move List Tests

    func testMoveList_CallsReorderOnService() async throws {
        // Create multiple lists
        _ = taskListService.createList(name: "List A")
        _ = taskListService.createList(name: "List B")
        _ = taskListService.createList(name: "List C")

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Verify lists were created
        XCTAssertEqual(viewModel.customLists.count, 3)

        // Move should not crash
        viewModel.moveList(from: IndexSet(integer: 0), to: 2)

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        // Lists should still exist after move
        XCTAssertEqual(viewModel.customLists.count, 3)
    }

    // MARK: - Get Tasks Tests

    func testGetTasks_ReturnsTasksForList() async throws {
        let list = taskListService.createList(name: "Work")
        taskService.createTask(title: "Work Task 1", listID: list.id)
        taskService.createTask(title: "Work Task 2", listID: list.id)
        taskService.createTask(title: "Other Task") // Different list

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let tasks = viewModel.getTasks(for: list)

        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.allSatisfy { $0.listID == list.id })
    }
}
