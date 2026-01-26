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

    // MARK: - Subtask Tests

    func testCreateSubtask() throws {
        // Create parent task
        let parent = taskService.createTask(title: "Parent Task")

        // Create subtask
        let subtask = taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)

        XCTAssertNotNil(subtask)
        XCTAssertEqual(subtask?.title, "Subtask 1")
        XCTAssertEqual(subtask?.parentTaskID, parent.id)
        XCTAssertTrue(subtask?.isSubtask ?? false)
        XCTAssertFalse(subtask?.isCompleted ?? true)
    }

    func testSubtaskInheritsDueDateFromParent() throws {
        let dueDate = Date()
        let parent = taskService.createTask(title: "Parent Task", dueDate: dueDate)

        let subtask = taskService.createSubtask(title: "Subtask", parentTaskID: parent.id)

        XCTAssertNotNil(subtask?.dueDate)
        // Compare dates (ignoring sub-second precision)
        if let subtaskDueDate = subtask?.dueDate {
            XCTAssertEqual(
                Calendar.current.compare(subtaskDueDate, to: dueDate, toGranularity: .second),
                .orderedSame
            )
        }
    }

    func testSubtaskInheritsPriorityFromParent() throws {
        let parent = taskService.createTask(title: "Parent Task", priority: .high)

        let subtask = taskService.createSubtask(title: "Subtask", parentTaskID: parent.id)

        XCTAssertEqual(subtask?.priority, .high)
    }

    func testSubtaskCanOverridePriority() throws {
        let parent = taskService.createTask(title: "Parent Task", priority: .high)

        let subtask = taskService.createSubtask(title: "Subtask", parentTaskID: parent.id, priority: .low)

        XCTAssertEqual(subtask?.priority, .low)
    }

    func testCreateMultipleSubtasks() throws {
        let parent = taskService.createTask(title: "Parent Task")
        let titles = ["Subtask 1", "Subtask 2", "Subtask 3"]

        let subtasks = taskService.createSubtasks(titles: titles, parentTaskID: parent.id)

        XCTAssertEqual(subtasks.count, 3)
        XCTAssertEqual(subtasks[0].title, "Subtask 1")
        XCTAssertEqual(subtasks[1].title, "Subtask 2")
        XCTAssertEqual(subtasks[2].title, "Subtask 3")
    }

    func testFetchSubtasks() throws {
        let parent = taskService.createTask(title: "Parent Task")
        taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)
        taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id)

        let subtasks = taskService.fetchSubtasks(forParentID: parent.id)

        XCTAssertEqual(subtasks.count, 2)
    }

    func testSubtasksExcludedFromTopLevelFetch() throws {
        let parent = taskService.createTask(title: "Parent Task")
        taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)
        taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id)

        taskService.fetchAllTasks()

        // Only parent should be in top-level tasks
        XCTAssertEqual(taskService.tasks.count, 1)
        XCTAssertEqual(taskService.tasks.first?.title, "Parent Task")
    }

    func testToggleSubtaskCompletion() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask = taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtask")
            return
        }
        XCTAssertFalse(subtask.isCompleted)

        taskService.toggleSubtaskCompletion(subtask)

        let updatedSubtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertTrue(updatedSubtasks.first?.isCompleted ?? false)
    }

    func testAutoCompleteParentWhenAllSubtasksComplete() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask1 = taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id),
              let subtask2 = taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtasks")
            return
        }

        // Complete first subtask
        taskService.toggleSubtaskCompletion(subtask1)

        // Parent should not be completed yet
        taskService.fetchAllTasks()
        let parentAfterFirst = taskService.tasks.first { $0.id == parent.id }
        XCTAssertFalse(parentAfterFirst?.isCompleted ?? true)

        // Complete second subtask
        taskService.toggleSubtaskCompletion(subtask2)

        // Parent should now be auto-completed
        taskService.fetchAllTasks()
        let parentAfterAll = taskService.tasks.first { $0.id == parent.id }
        XCTAssertTrue(parentAfterAll?.isCompleted ?? false)
    }

    func testParentNotAutoCompletedWhenSomeSubtasksIncomplete() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask1 = taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id),
              let _ = taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtasks")
            return
        }

        // Complete only first subtask
        taskService.toggleSubtaskCompletion(subtask1)

        // Parent should not be completed
        taskService.fetchAllTasks()
        let parentTask = taskService.tasks.first { $0.id == parent.id }
        XCTAssertFalse(parentTask?.isCompleted ?? true)
    }

    func testUncompletingSubtaskUncompletesParent() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask1 = taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id),
              let subtask2 = taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtasks")
            return
        }

        // Complete both subtasks
        taskService.toggleSubtaskCompletion(subtask1)
        taskService.toggleSubtaskCompletion(subtask2)

        // Verify parent is completed
        taskService.fetchAllTasks()
        var parentTask = taskService.tasks.first { $0.id == parent.id }
        XCTAssertTrue(parentTask?.isCompleted ?? false)

        // Uncomplete one subtask
        let completedSubtask = taskService.fetchSubtasks(forParentID: parent.id).first!
        taskService.toggleSubtaskCompletion(completedSubtask)

        // Parent should no longer be completed
        taskService.fetchAllTasks()
        parentTask = taskService.tasks.first { $0.id == parent.id }
        XCTAssertFalse(parentTask?.isCompleted ?? true)
    }

    func testDeleteSubtask() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask = taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtask")
            return
        }

        let initialCount = taskService.fetchSubtasks(forParentID: parent.id).count
        XCTAssertEqual(initialCount, 1)

        taskService.deleteTask(subtask)

        let remainingSubtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(remainingSubtasks.count, 0)
    }

    func testDeleteParentDeletesSubtasks() throws {
        let parent = taskService.createTask(title: "Parent Task")
        taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)
        taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id)

        // Verify subtasks exist
        let initialSubtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(initialSubtasks.count, 2)

        // Delete parent
        taskService.deleteTask(parent)

        // Subtasks should be cascade deleted
        let remainingSubtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(remainingSubtasks.count, 0)
    }

    func testPromoteSubtaskToTask() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask = taskService.createSubtask(title: "Subtask to Promote", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtask")
            return
        }

        XCTAssertTrue(subtask.isSubtask)

        taskService.promoteSubtaskToTask(subtask)

        // Task should now be top-level
        taskService.fetchAllTasks()
        let promotedTask = taskService.tasks.first { $0.title == "Subtask to Promote" }
        XCTAssertNotNil(promotedTask)
        XCTAssertFalse(promotedTask?.isSubtask ?? true)
        XCTAssertNil(promotedTask?.parentTaskID)

        // Subtask count should be reduced
        let remainingSubtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(remainingSubtasks.count, 0)
    }

    func testSubtaskProgress() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask1 = taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id),
              let _ = taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id),
              let _ = taskService.createSubtask(title: "Subtask 3", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtasks")
            return
        }

        taskService.fetchAllTasks()
        var parentTask = taskService.tasks.first { $0.id == parent.id }

        // Initial progress: 0/3
        XCTAssertEqual(parentTask?.completedSubtaskCount, 0)
        XCTAssertEqual(parentTask?.subtasks.count, 3)
        XCTAssertEqual(parentTask?.subtaskProgress ?? 0.0, 0.0, accuracy: 0.01)

        // Complete one subtask
        taskService.toggleSubtaskCompletion(subtask1)

        taskService.fetchAllTasks()
        parentTask = taskService.tasks.first { $0.id == parent.id }

        // Progress: 1/3
        XCTAssertEqual(parentTask?.completedSubtaskCount, 1)
        XCTAssertEqual(parentTask?.subtaskProgress ?? 0.0, 1.0/3.0, accuracy: 0.01)
    }

    func testReorderSubtasks() throws {
        let parent = taskService.createTask(title: "Parent Task")
        guard let subtask1 = taskService.createSubtask(title: "First", parentTaskID: parent.id),
              let subtask2 = taskService.createSubtask(title: "Second", parentTaskID: parent.id),
              let subtask3 = taskService.createSubtask(title: "Third", parentTaskID: parent.id) else {
            XCTFail("Failed to create subtasks")
            return
        }

        // Initial order: First, Second, Third
        var subtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasks[0].title, "First")
        XCTAssertEqual(subtasks[1].title, "Second")
        XCTAssertEqual(subtasks[2].title, "Third")

        // Reorder to: Third, First, Second
        let reordered = [subtask3, subtask1, subtask2]
        taskService.reorderSubtasks(reordered, parentID: parent.id)

        subtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasks[0].title, "Third")
        XCTAssertEqual(subtasks[1].title, "First")
        XCTAssertEqual(subtasks[2].title, "Second")
    }

    func testAddingSubtaskToCompletedParentUncompletesIt() throws {
        let parent = taskService.createTask(title: "Parent Task")
        taskService.toggleTaskCompletion(parent)

        // Verify parent is completed
        taskService.fetchAllTasks()
        var parentTask = taskService.tasks.first { $0.id == parent.id }
        XCTAssertTrue(parentTask?.isCompleted ?? false)

        // Add a subtask
        taskService.createSubtask(title: "New Subtask", parentTaskID: parent.id)

        // Parent should no longer be completed
        taskService.fetchAllTasks()
        parentTask = taskService.tasks.first { $0.id == parent.id }
        XCTAssertFalse(parentTask?.isCompleted ?? true)
    }

    func testSubtaskCreationFailsForInvalidParent() throws {
        let invalidParentID = UUID()

        let subtask = taskService.createSubtask(title: "Orphan Subtask", parentTaskID: invalidParentID)

        XCTAssertNil(subtask)
    }

    func testSubtasksInheritParentListChange() throws {
        // Create a list
        let listService = TaskListService(persistenceController: persistenceController)
        let list1 = listService.createList(name: "List 1")
        let list2 = listService.createList(name: "List 2")

        // Create parent task in list 1 with subtasks
        let parent = taskService.createTask(title: "Parent Task", listID: list1.id)
        taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)
        taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id)

        // Verify subtasks don't have explicit list (they inherit from parent contextually)
        let subtasksBefore = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasksBefore.count, 2)

        // Move parent to list 2
        var updatedParent = parent
        updatedParent = parent.updated(listID: list2.id)
        taskService.updateTask(updatedParent)

        // Verify subtasks now have list 2
        let subtasksAfter = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasksAfter.count, 2)
        for subtask in subtasksAfter {
            XCTAssertEqual(subtask.listID, list2.id, "Subtask should inherit parent's new list")
        }
    }

    func testSubtasksInheritParentListRemoval() throws {
        // Create a list
        let listService = TaskListService(persistenceController: persistenceController)
        let list = listService.createList(name: "Test List")

        // Create parent task in list with subtasks
        let parent = taskService.createTask(title: "Parent Task", listID: list.id)
        taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)

        // Remove parent from list (set to nil)
        // Note: .some(nil) is needed because listID is UUID?? (double optional)
        // Passing nil directly means "don't change", while .some(nil) means "set to nil"
        let updatedParent = parent.updated(listID: .some(nil))
        taskService.updateTask(updatedParent)

        // Verify subtasks also have no list
        let subtasksAfter = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasksAfter.count, 1)
        XCTAssertNil(subtasksAfter.first?.listID, "Subtask should have no list when parent is removed from list")
    }

// MARK: - Undo Tests

    func testUndoDeleteTaskWithSubtasks() throws {
        // Create a parent task with subtasks
        let parent = taskService.createTask(title: "Parent Task with Subtasks")
        taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)
        taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id)
        taskService.createSubtask(title: "Subtask 3", parentTaskID: parent.id)

        // Verify setup: 1 parent task with 3 subtasks
        taskService.fetchAllTasks()
        XCTAssertEqual(taskService.tasks.count, 1)
        let subtasksBefore = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasksBefore.count, 3)

        // Delete the parent task with allowUndo: true (doesn't save immediately)
        taskService.deleteTask(parent, allowUndo: true)

        // Verify deletion is visible in context
        taskService.fetchAllTasks()
        XCTAssertEqual(taskService.tasks.count, 0, "Parent task should be deleted")
        let subtasksAfterDelete = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasksAfterDelete.count, 0, "Subtasks should be deleted with parent")

        // Undo the deletion (restores soft-deleted tasks)
        XCTAssertNotNil(taskService.pendingDeleteTaskID, "Should have pending delete")
        taskService.discardPendingChanges()

        // Verify restoration: parent AND subtasks should be back
        taskService.fetchAllTasks()
        XCTAssertEqual(taskService.tasks.count, 1, "Parent task should be restored")
        XCTAssertEqual(taskService.tasks.first?.title, "Parent Task with Subtasks")

        let subtasksAfterUndo = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasksAfterUndo.count, 3, "All 3 subtasks should be restored")

        // Verify subtask titles
        let subtaskTitles = Set(subtasksAfterUndo.map { $0.title })
        XCTAssertTrue(subtaskTitles.contains("Subtask 1"))
        XCTAssertTrue(subtaskTitles.contains("Subtask 2"))
        XCTAssertTrue(subtaskTitles.contains("Subtask 3"))
    }

    func testDeleteWithAllowUndoUsesSoftDelete() throws {
        let task = taskService.createTask(title: "Test Task")

        // Delete with allowUndo: true (soft delete)
        taskService.deleteTask(task, allowUndo: true)

        // Verify task is not visible (soft deleted)
        taskService.fetchAllTasks()
        XCTAssertEqual(taskService.tasks.count, 0, "Task should not be visible after soft delete")
        XCTAssertNotNil(taskService.pendingDeleteTaskID, "Should have pending delete task ID")

        // Discard changes (restores soft-deleted task)
        taskService.discardPendingChanges()
        taskService.fetchAllTasks()
        XCTAssertEqual(taskService.tasks.count, 1, "Task should be restored after discard")
        XCTAssertNil(taskService.pendingDeleteTaskID, "Should not have pending delete after discard")
    }

    func testCommitPendingChangesHardDeletesTask() throws {
        let task = taskService.createTask(title: "Test Task")

        // Delete with allowUndo: true (soft delete)
        taskService.deleteTask(task, allowUndo: true)
        XCTAssertNotNil(taskService.pendingDeleteTaskID, "Should have pending delete")

        // Commit changes (hard deletes the soft-deleted task)
        taskService.commitPendingChanges()
        XCTAssertNil(taskService.pendingDeleteTaskID, "Should not have pending delete after commit")

        // Discard now should have no effect - task is permanently gone
        taskService.discardPendingChanges()
        taskService.fetchAllTasks()
        XCTAssertEqual(taskService.tasks.count, 0, "Task should remain deleted after commit")
    }

    func testUndoDeleteSubtask() throws {
        // Create a parent task with subtasks
        let parent = taskService.createTask(title: "Parent Task")
        taskService.createSubtask(title: "Subtask 1", parentTaskID: parent.id)
        taskService.createSubtask(title: "Subtask 2", parentTaskID: parent.id)

        // Verify setup
        var subtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasks.count, 2)

        // Delete one subtask with allowUndo: true (soft delete)
        let subtaskToDelete = subtasks.first!
        taskService.deleteTask(subtaskToDelete, allowUndo: true)

        // Verify subtask is not visible (soft deleted)
        subtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasks.count, 1, "Should have 1 subtask after soft delete")
        XCTAssertNotNil(taskService.pendingDeleteTaskID, "Should have pending delete")

        // Undo the deletion (restore soft-deleted subtask)
        taskService.discardPendingChanges()

        // Verify subtask is restored
        subtasks = taskService.fetchSubtasks(forParentID: parent.id)
        XCTAssertEqual(subtasks.count, 2, "Should have 2 subtasks after undo")
        XCTAssertTrue(subtasks.contains { $0.title == "Subtask 1" }, "Subtask 1 should be restored")
        XCTAssertTrue(subtasks.contains { $0.title == "Subtask 2" }, "Subtask 2 should be restored")
    }

    // MARK: - Time Tracking (startedAt) Tests

    func testStartWorking_SetsStartedAt() throws {
        let task = taskService.createTask(title: "Task to start")
        XCTAssertNil(task.startedAt)

        taskService.startWorking(on: task)

        let updatedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertNotNil(updatedTask?.startedAt)
        XCTAssertTrue(updatedTask?.isInProgress ?? false)
    }

    func testStopWorking_PreservesStartedAt() throws {
        let task = taskService.createTask(title: "Task to stop")
        taskService.startWorking(on: task)

        let inProgressTask = taskService.tasks.first { $0.id == task.id }!
        let originalStartedAt = inProgressTask.startedAt

        taskService.stopWorking(on: inProgressTask)

        let stoppedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertFalse(stoppedTask?.isInProgress ?? true)
        XCTAssertEqual(stoppedTask?.startedAt, originalStartedAt)
    }

    func testResumeWorking_PreservesOriginalStartedAt() throws {
        let task = taskService.createTask(title: "Task to resume")

        // Start working
        taskService.startWorking(on: task)
        let firstStart = taskService.tasks.first { $0.id == task.id }!
        let originalStartedAt = firstStart.startedAt

        // Stop working
        taskService.stopWorking(on: firstStart)

        // Wait briefly to ensure time difference
        Thread.sleep(forTimeInterval: 0.1)

        // Resume working
        let stoppedTask = taskService.tasks.first { $0.id == task.id }!
        taskService.startWorking(on: stoppedTask)

        let resumedTask = taskService.tasks.first { $0.id == task.id }
        // Original startedAt should be preserved (not updated to new time)
        XCTAssertEqual(resumedTask?.startedAt, originalStartedAt)
        XCTAssertTrue(resumedTask?.isInProgress ?? false)
    }

    func testCompleteTask_PreservesStartedAt() throws {
        let task = taskService.createTask(title: "Task to complete")
        taskService.startWorking(on: task)

        let inProgressTask = taskService.tasks.first { $0.id == task.id }!
        let originalStartedAt = inProgressTask.startedAt

        taskService.toggleTaskCompletion(inProgressTask)

        let completedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertTrue(completedTask?.isCompleted ?? false)
        XCTAssertEqual(completedTask?.startedAt, originalStartedAt)
        XCTAssertNotNil(completedTask?.completedAt)
    }

    func testUncompleteTask_ClearsStartedAt() throws {
        let task = taskService.createTask(title: "Task to uncomplete")
        taskService.startWorking(on: task)

        let inProgressTask = taskService.tasks.first { $0.id == task.id }!
        taskService.toggleTaskCompletion(inProgressTask)

        let completedTask = taskService.tasks.first { $0.id == task.id }!
        XCTAssertNotNil(completedTask.startedAt)

        // Uncomplete the task
        taskService.toggleTaskCompletion(completedTask)

        let uncompletedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertFalse(uncompletedTask?.isCompleted ?? true)
        XCTAssertNil(uncompletedTask?.startedAt)
        XCTAssertNil(uncompletedTask?.completedAt)
    }

    func testActualDuration_CalculatesCorrectly() throws {
        // Create a task with known startedAt and completedAt
        let startedAt = Date()
        let completedAt = startedAt.addingTimeInterval(3600) // 1 hour later

        let task = Task(
            title: "Timed Task",
            completedAt: completedAt,
            startedAt: startedAt
        )

        XCTAssertNotNil(task.actualDuration)
        XCTAssertEqual(task.actualDuration ?? 0, 3600, accuracy: 1)
    }

    func testFormattedActualDuration_HoursAndMinutes() throws {
        let startedAt = Date()
        let completedAt = startedAt.addingTimeInterval(5700) // 1h 35m

        let task = Task(
            title: "Long Task",
            status: .completed,
            completedAt: completedAt,
            startedAt: startedAt
        )

        XCTAssertEqual(task.formattedActualDuration, "1:35") // Timer format H:MM
    }

    func testFormattedActualDuration_HoursOnly() throws {
        let startedAt = Date()
        let completedAt = startedAt.addingTimeInterval(7200) // 2h

        let task = Task(
            title: "Two Hour Task",
            status: .completed,
            completedAt: completedAt,
            startedAt: startedAt
        )

        XCTAssertEqual(task.formattedActualDuration, "2:00") // Timer format H:MM
    }

    func testFormattedActualDuration_MinutesOnly() throws {
        let startedAt = Date()
        let completedAt = startedAt.addingTimeInterval(1800) // 30m

        let task = Task(
            title: "Short Task",
            status: .completed,
            completedAt: completedAt,
            startedAt: startedAt
        )

        XCTAssertEqual(task.formattedActualDuration, "30:00") // Timer format M:SS
    }

    func testFormattedActualDuration_LessThanMinute() throws {
        let startedAt = Date()
        let completedAt = startedAt.addingTimeInterval(45) // 45 seconds

        let task = Task(
            title: "Quick Task",
            status: .completed,
            completedAt: completedAt,
            startedAt: startedAt
        )

        XCTAssertEqual(task.formattedActualDuration, "0:45") // Timer format M:SS
    }

    func testFormattedActualDuration_NilWithoutStartedAt() throws {
        let task = Task(
            title: "Task without tracking",
            status: .completed,
            completedAt: Date()
        )

        XCTAssertNil(task.actualDuration)
        XCTAssertNil(task.formattedActualDuration)
    }

    func testStartWorkingOnNewTask_StopsCurrentInProgress() throws {
        let task1 = taskService.createTask(title: "Task 1")
        let task2 = taskService.createTask(title: "Task 2")

        taskService.startWorking(on: task1)

        let task1InProgress = taskService.tasks.first { $0.id == task1.id }
        XCTAssertTrue(task1InProgress?.isInProgress ?? false)

        taskService.startWorking(on: task2)

        let task1After = taskService.tasks.first { $0.id == task1.id }
        let task2After = taskService.tasks.first { $0.id == task2.id }

        XCTAssertFalse(task1After?.isInProgress ?? true)
        XCTAssertTrue(task2After?.isInProgress ?? false)
        // Task 1's startedAt should be preserved
        XCTAssertNotNil(task1After?.startedAt)
    }
}
