import XCTest
import CoreData
@testable import Lazyflow

@MainActor
final class TaskListServiceTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskListService: TaskListService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskListService = TaskListService(persistenceController: persistenceController)
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskListService = nil
    }

    // MARK: - Create Tests

    func testCreateList() throws {
        let list = taskListService.createList(name: "Work")

        XCTAssertEqual(list.name, "Work")
        XCTAssertEqual(list.colorHex, "#218A8D")
        XCTAssertFalse(list.isDefault)
    }

    func testCreateListWithCustomization() throws {
        let list = taskListService.createList(
            name: "Personal",
            colorHex: "#22C876",
            iconName: "person"
        )

        XCTAssertEqual(list.name, "Personal")
        XCTAssertEqual(list.colorHex, "#22C876")
        XCTAssertEqual(list.iconName, "person")
    }

    func testDefaultListCreation() throws {
        // Default lists should be created on init
        let inbox = taskListService.getInboxList()

        XCTAssertNotNil(inbox)
        XCTAssertEqual(inbox?.name, "Inbox")
        XCTAssertTrue(inbox?.isDefault ?? false)
    }

    // MARK: - Read Tests

    func testFetchAllLists() throws {
        taskListService.createList(name: "List 1")
        taskListService.createList(name: "List 2")

        taskListService.fetchAllLists()

        // Should include default Inbox plus the two created lists
        XCTAssertGreaterThanOrEqual(taskListService.lists.count, 2)
    }

    func testGetListByID() throws {
        let createdList = taskListService.createList(name: "Test List")

        let fetchedList = taskListService.getList(byID: createdList.id)

        XCTAssertNotNil(fetchedList)
        XCTAssertEqual(fetchedList?.name, "Test List")
    }

    func testGetTaskCount() throws {
        let list = taskListService.createList(name: "Test List")
        let taskService = TaskService(persistenceController: persistenceController)

        // Create tasks in the list
        taskService.createTask(title: "Task 1", listID: list.id)
        taskService.createTask(title: "Task 2", listID: list.id)
        taskService.createTask(title: "Task 3", listID: list.id)

        let count = taskListService.getTaskCount(forListID: list.id)

        XCTAssertEqual(count, 3)
    }

    // MARK: - Update Tests

    func testUpdateList() throws {
        let list = taskListService.createList(name: "Original Name")

        var updatedList = list
        updatedList = TaskList(
            id: list.id,
            name: "Updated Name",
            colorHex: "#FF5459",
            iconName: "star",
            order: list.order,
            isDefault: list.isDefault,
            createdAt: list.createdAt
        )

        taskListService.updateList(updatedList)

        let fetchedList = taskListService.getList(byID: list.id)
        XCTAssertEqual(fetchedList?.name, "Updated Name")
        XCTAssertEqual(fetchedList?.colorHex, "#FF5459")
    }

    func testReorderLists() throws {
        let list1 = taskListService.createList(name: "List 1")
        let list2 = taskListService.createList(name: "List 2")
        let list3 = taskListService.createList(name: "List 3")

        // Reorder: List 3, List 1, List 2
        taskListService.reorderLists([list3, list1, list2])

        taskListService.fetchAllLists()

        // Find the custom lists (excluding default inbox)
        let customLists = taskListService.lists.filter { !$0.isDefault }

        // Verify order
        XCTAssertEqual(customLists.first?.name, "List 3")
    }

    // MARK: - Delete Tests

    func testDeleteList() throws {
        let list = taskListService.createList(name: "List to Delete")
        let initialCount = taskListService.lists.count

        taskListService.deleteList(list)

        XCTAssertLessThan(taskListService.lists.count, initialCount)
    }

    func testCannotDeleteDefaultList() throws {
        guard let inbox = taskListService.getInboxList() else {
            XCTFail("Inbox not found")
            return
        }

        let initialCount = taskListService.lists.count

        taskListService.deleteList(inbox)

        // Count should remain the same
        XCTAssertEqual(taskListService.lists.count, initialCount)
    }

    func testDeleteListMovesTasksToInbox() throws {
        let list = taskListService.createList(name: "Work")
        let taskService = TaskService(persistenceController: persistenceController)

        // Create tasks in the list
        let task1 = taskService.createTask(title: "Task 1", listID: list.id)
        let task2 = taskService.createTask(title: "Task 2", listID: list.id)

        taskListService.deleteList(list)

        // Tasks should now be in inbox
        taskService.fetchAllTasks()
        let inbox = taskListService.getInboxList()

        let movedTask1 = taskService.tasks.first { $0.id == task1.id }
        let movedTask2 = taskService.tasks.first { $0.id == task2.id }

        XCTAssertEqual(movedTask1?.listID, inbox?.id)
        XCTAssertEqual(movedTask2?.listID, inbox?.id)
    }

    // MARK: - Order Tests

    func testListOrderIncrementsAutomatically() throws {
        let list1 = taskListService.createList(name: "List 1")
        let list2 = taskListService.createList(name: "List 2")
        let list3 = taskListService.createList(name: "List 3")

        XCTAssertLessThan(list1.order, list2.order)
        XCTAssertLessThan(list2.order, list3.order)
    }

    // MARK: - Duplicate Inbox Prevention Tests

    func testOnlyOneInboxInLists() throws {
        // Verify only one Inbox exists in the lists
        taskListService.fetchAllLists()

        let inboxLists = taskListService.lists.filter { $0.name == "Inbox" || $0.isDefault }

        XCTAssertEqual(inboxLists.count, 1, "Should have exactly one Inbox list")
    }

    func testDuplicateInboxCleanup() throws {
        // Manually create a duplicate Inbox to simulate race condition
        let context = persistenceController.viewContext

        let duplicateInbox = TaskListEntity(context: context)
        duplicateInbox.id = UUID() // Different ID than canonical
        duplicateInbox.name = "Inbox"
        duplicateInbox.colorHex = "#5A6C71"
        duplicateInbox.iconName = "tray"
        duplicateInbox.order = 99
        duplicateInbox.isDefault = true
        duplicateInbox.createdAt = Date()

        persistenceController.save()

        // Now create a new TaskListService which should clean up duplicates
        let newService = TaskListService(persistenceController: persistenceController)

        // Should only have one Inbox after cleanup
        let inboxLists = newService.lists.filter { $0.name == "Inbox" || $0.isDefault }

        XCTAssertEqual(inboxLists.count, 1, "Duplicate Inbox should be cleaned up")

        // The remaining Inbox should be the canonical one
        let canonicalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(inboxLists.first?.id, canonicalID, "Should keep the canonical Inbox")
    }

    func testDuplicateInboxCleanup_MovesTasksToCanonicalInbox() throws {
        let taskService = TaskService(persistenceController: persistenceController)
        let context = persistenceController.viewContext

        // Create a duplicate Inbox
        let duplicateInbox = TaskListEntity(context: context)
        let duplicateID = UUID()
        duplicateInbox.id = duplicateID
        duplicateInbox.name = "Inbox"
        duplicateInbox.colorHex = "#5A6C71"
        duplicateInbox.iconName = "tray"
        duplicateInbox.order = 99
        duplicateInbox.isDefault = true
        duplicateInbox.createdAt = Date()

        persistenceController.save()

        // Create a task in the duplicate Inbox
        let task = taskService.createTask(title: "Task in Duplicate", listID: duplicateID)

        // Create a new TaskListService which triggers cleanup
        let _ = TaskListService(persistenceController: persistenceController)

        // Fetch the task again
        taskService.fetchAllTasks()
        let updatedTask = taskService.tasks.first { $0.id == task.id }

        // Task should now be in the canonical Inbox
        let canonicalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(updatedTask?.listID, canonicalID, "Task should be moved to canonical Inbox")
    }

    // MARK: - Performance Tests

    func testFetchPerformance() throws {
        // Create 50 lists
        for i in 0..<50 {
            taskListService.createList(name: "List \(i)")
        }

        measure {
            taskListService.fetchAllLists()
        }
    }
}
