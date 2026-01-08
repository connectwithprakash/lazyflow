import XCTest
import CoreData
@testable import Lazyflow

@MainActor
final class TaskServiceTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskService = nil
    }

    // MARK: - Create Tests

    func testCreateTask() throws {
        let task = taskService.createTask(title: "Test Task")

        XCTAssertEqual(task.title, "Test Task")
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(taskService.tasks.count, 1)
    }

    func testCreateTaskWithAllFields() throws {
        let dueDate = Date()
        let dueTime = Date()
        let reminderDate = Date()

        let task = taskService.createTask(
            title: "Complete Task",
            notes: "Test notes",
            dueDate: dueDate,
            dueTime: dueTime,
            reminderDate: reminderDate,
            priority: .high,
            estimatedDuration: 3600
        )

        XCTAssertEqual(task.title, "Complete Task")
        XCTAssertEqual(task.notes, "Test notes")
        XCTAssertNotNil(task.dueDate)
        XCTAssertNotNil(task.dueTime)
        XCTAssertNotNil(task.reminderDate)
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.estimatedDuration, 3600)
    }

    func testCreateTaskWithRecurringRule() throws {
        let rule = RecurringRule(frequency: .daily, interval: 1)

        let task = taskService.createTask(
            title: "Daily Task",
            dueDate: Date(),
            recurringRule: rule
        )

        XCTAssertNotNil(task.recurringRule)
        XCTAssertEqual(task.recurringRule?.frequency, .daily)
    }

    // MARK: - Read Tests

    func testFetchAllTasks() throws {
        taskService.createTask(title: "Task 1")
        taskService.createTask(title: "Task 2")
        taskService.createTask(title: "Task 3")

        taskService.fetchAllTasks()

        XCTAssertEqual(taskService.tasks.count, 3)
    }

    func testFetchTodayTasks() throws {
        taskService.createTask(title: "Today Task", dueDate: Date())
        taskService.createTask(title: "Tomorrow Task", dueDate: Date().addingDays(1))
        taskService.createTask(title: "No Date Task")

        let todayTasks = taskService.fetchTodayTasks()

        XCTAssertEqual(todayTasks.count, 1)
        XCTAssertEqual(todayTasks.first?.title, "Today Task")
    }

    func testFetchOverdueTasks() throws {
        taskService.createTask(title: "Overdue Task", dueDate: Date().addingDays(-2))
        taskService.createTask(title: "Today Task", dueDate: Date())
        taskService.createTask(title: "Future Task", dueDate: Date().addingDays(2))

        let overdueTasks = taskService.fetchOverdueTasks()

        XCTAssertEqual(overdueTasks.count, 1)
        XCTAssertEqual(overdueTasks.first?.title, "Overdue Task")
    }

    func testFetchUpcomingTasks() throws {
        taskService.createTask(title: "Today Task", dueDate: Date())
        taskService.createTask(title: "Tomorrow Task", dueDate: Date().addingDays(1))
        taskService.createTask(title: "Next Week Task", dueDate: Date().addingDays(5))
        taskService.createTask(title: "Far Future Task", dueDate: Date().addingDays(14))

        let upcomingTasks = taskService.fetchUpcomingTasks()

        XCTAssertEqual(upcomingTasks.count, 2) // Tomorrow and Next Week
    }

    func testSearchTasks() throws {
        taskService.createTask(title: "Buy groceries")
        taskService.createTask(title: "Call mom")
        taskService.createTask(title: "Buy birthday present", notes: "For mom")

        let groceryResults = taskService.searchTasks(query: "groceries")
        XCTAssertEqual(groceryResults.count, 1)

        let buyResults = taskService.searchTasks(query: "buy")
        XCTAssertEqual(buyResults.count, 2)

        let momResults = taskService.searchTasks(query: "mom")
        XCTAssertEqual(momResults.count, 2) // One in title, one in notes
    }

    // MARK: - Update Tests

    func testUpdateTask() throws {
        let task = taskService.createTask(title: "Original Title")
        var updatedTask = task
        updatedTask = task.updated(title: "Updated Title")

        taskService.updateTask(updatedTask)

        let fetchedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertEqual(fetchedTask?.title, "Updated Title")
    }

    func testToggleTaskCompletion() throws {
        let task = taskService.createTask(title: "Test Task")
        XCTAssertFalse(task.isCompleted)

        taskService.toggleTaskCompletion(task)

        let fetchedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertTrue(fetchedTask?.isCompleted ?? false)

        taskService.toggleTaskCompletion(fetchedTask!)

        let refetchedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertFalse(refetchedTask?.isCompleted ?? true)
    }

    func testRecurringTaskCompletion() throws {
        let rule = RecurringRule(frequency: .daily, interval: 1)
        let task = taskService.createTask(
            title: "Daily Task",
            dueDate: Date(),
            recurringRule: rule
        )

        let initialCount = taskService.tasks.count

        taskService.toggleTaskCompletion(task)

        // Should create a new task for the next occurrence
        XCTAssertEqual(taskService.tasks.count, initialCount + 1)

        // Original should be completed
        let completedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertTrue(completedTask?.isCompleted ?? false)

        // New task should have next due date
        let newTask = taskService.tasks.first { $0.id != task.id && $0.title == "Daily Task" }
        XCTAssertNotNil(newTask)
        XCTAssertFalse(newTask?.isCompleted ?? true)
    }

    // MARK: - Delete Tests

    func testDeleteTask() throws {
        let task = taskService.createTask(title: "Task to Delete")
        XCTAssertEqual(taskService.tasks.count, 1)

        taskService.deleteTask(task)

        XCTAssertEqual(taskService.tasks.count, 0)
    }

    func testArchiveTask() throws {
        let task = taskService.createTask(title: "Task to Archive")

        taskService.archiveTask(task)

        // Archived tasks should not appear in regular fetch
        let fetchedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertNil(fetchedTask)
    }

    func testDeleteCompletedTasks() throws {
        let task1 = taskService.createTask(title: "Task 1")
        taskService.createTask(title: "Task 2")
        taskService.toggleTaskCompletion(task1)

        let initialCount = taskService.tasks.count

        taskService.deleteCompletedTasks()

        XCTAssertLessThan(taskService.tasks.count, initialCount)
    }

    // MARK: - Performance Tests

    func testFetchPerformance() throws {
        // Create 100 tasks
        for i in 0..<100 {
            taskService.createTask(title: "Task \(i)")
        }

        measure {
            taskService.fetchAllTasks()
        }
    }

    func testSearchPerformance() throws {
        // Create 100 tasks
        for i in 0..<100 {
            taskService.createTask(title: "Task \(i)", notes: "Notes for task \(i)")
        }

        measure {
            _ = taskService.searchTasks(query: "task")
        }
    }
}
