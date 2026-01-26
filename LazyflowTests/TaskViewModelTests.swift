import XCTest
import Combine
@testable import Lazyflow

@MainActor
final class TaskViewModelTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var viewModel: TaskViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        viewModel = TaskViewModel(taskService: taskService)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskService = nil
        viewModel = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests

    func testInitialState_NewTask() {
        XCTAssertEqual(viewModel.title, "")
        XCTAssertEqual(viewModel.notes, "")
        XCTAssertNil(viewModel.dueDate)
        XCTAssertFalse(viewModel.hasDueDate)
        XCTAssertNil(viewModel.dueTime)
        XCTAssertFalse(viewModel.hasDueTime)
        XCTAssertNil(viewModel.reminderDate)
        XCTAssertFalse(viewModel.hasReminder)
        XCTAssertEqual(viewModel.priority, .none)
        XCTAssertEqual(viewModel.category, .uncategorized)
        XCTAssertNil(viewModel.selectedListID)
        XCTAssertNil(viewModel.estimatedDuration)
        XCTAssertFalse(viewModel.isRecurring)
        XCTAssertFalse(viewModel.isValid)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertFalse(viewModel.isEditing)
    }

    func testInitialState_ExistingTask() async throws {
        let existingTask = taskService.createTask(
            title: "Existing Task",
            notes: "Some notes",
            dueDate: Date(),
            priority: .high,
            category: .work
        )

        let editViewModel = TaskViewModel(taskService: taskService, task: existingTask)

        XCTAssertEqual(editViewModel.title, "Existing Task")
        XCTAssertEqual(editViewModel.notes, "Some notes")
        XCTAssertTrue(editViewModel.hasDueDate)
        XCTAssertEqual(editViewModel.priority, .high)
        XCTAssertEqual(editViewModel.category, .work)
        XCTAssertTrue(editViewModel.isEditing)
        XCTAssertTrue(editViewModel.isValid)
    }

    func testInitialState_RecurringTask() async throws {
        let rule = RecurringRule(frequency: .weekly, interval: 2, daysOfWeek: [1, 3, 5])
        let existingTask = taskService.createTask(
            title: "Recurring Task",
            dueDate: Date(),
            recurringRule: rule
        )

        let editViewModel = TaskViewModel(taskService: taskService, task: existingTask)

        XCTAssertTrue(editViewModel.isRecurring)
        XCTAssertEqual(editViewModel.recurringFrequency, .weekly)
        XCTAssertEqual(editViewModel.recurringInterval, 2)
        XCTAssertEqual(editViewModel.recurringDaysOfWeek, [1, 3, 5])
    }

    // MARK: - Validation Tests

    func testValidation_EmptyTitle_IsInvalid() {
        viewModel.title = ""
        XCTAssertFalse(viewModel.isValid)
    }

    func testValidation_WhitespaceOnly_IsInvalid() {
        viewModel.title = "   "
        XCTAssertFalse(viewModel.isValid)
    }

    func testValidation_ValidTitle_IsValid() async throws {
        viewModel.title = "Valid Task"

        // Wait for validation to update
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.isValid)
    }

    func testValidation_TitleWithWhitespace_IsValid() async throws {
        viewModel.title = "  Task with spaces  "

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.isValid)
    }

    // MARK: - Save Tests

    func testSave_NewTask_CreatesTask() async throws {
        viewModel.title = "New Task"
        viewModel.notes = "Task notes"
        viewModel.hasDueDate = true
        viewModel.dueDate = Date()
        viewModel.priority = .medium

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNotNil(savedTask)
        XCTAssertEqual(savedTask?.title, "New Task")
        XCTAssertEqual(savedTask?.notes, "Task notes")
        XCTAssertEqual(savedTask?.priority, .medium)
    }

    func testSave_EmptyTitle_ReturnsNil() {
        viewModel.title = ""

        let savedTask = viewModel.save()

        XCTAssertNil(savedTask)
    }

    func testSave_ExistingTask_UpdatesTask() async throws {
        let existingTask = taskService.createTask(title: "Original Title")
        let editViewModel = TaskViewModel(taskService: taskService, task: existingTask)

        editViewModel.title = "Updated Title"
        editViewModel.priority = .urgent

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = editViewModel.save()

        XCTAssertNotNil(savedTask)
        XCTAssertEqual(savedTask?.id, existingTask.id)
        XCTAssertEqual(savedTask?.title, "Updated Title")
        XCTAssertEqual(savedTask?.priority, .urgent)
    }

    func testSave_WithRecurringRule() async throws {
        viewModel.title = "Recurring Task"
        viewModel.isRecurring = true
        viewModel.recurringFrequency = .daily
        viewModel.recurringInterval = 1

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNotNil(savedTask)
        XCTAssertNotNil(savedTask?.recurringRule)
        XCTAssertEqual(savedTask?.recurringRule?.frequency, .daily)
    }

    func testSave_TrimsTitleAndNotes() async throws {
        viewModel.title = "  Trimmed Title  "
        viewModel.notes = "  Trimmed Notes  "

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertEqual(savedTask?.title, "Trimmed Title")
        XCTAssertEqual(savedTask?.notes, "Trimmed Notes")
    }

    func testSave_EmptyNotes_SetsToNil() async throws {
        viewModel.title = "Task"
        viewModel.notes = "   "

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNil(savedTask?.notes)
    }

    // MARK: - Delete Tests

    func testDelete_RemovesTask() async throws {
        let existingTask = taskService.createTask(title: "Task to Delete")
        let editViewModel = TaskViewModel(taskService: taskService, task: existingTask)

        let initialCount = taskService.tasks.count
        editViewModel.delete()

        XCTAssertLessThan(taskService.tasks.count, initialCount)
    }

    func testDelete_NewTask_DoesNothing() {
        let initialCount = taskService.tasks.count
        viewModel.delete()

        XCTAssertEqual(taskService.tasks.count, initialCount)
    }

    // MARK: - Quick Actions Tests

    func testSetDueToday() {
        viewModel.setDueToday()

        XCTAssertTrue(viewModel.hasDueDate)
        XCTAssertNotNil(viewModel.dueDate)
        XCTAssertTrue(Calendar.current.isDateInToday(viewModel.dueDate!))
    }

    func testSetDueTomorrow() {
        viewModel.setDueTomorrow()

        XCTAssertTrue(viewModel.hasDueDate)
        XCTAssertNotNil(viewModel.dueDate)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(viewModel.dueDate!))
    }

    func testSetDueNextWeek() {
        viewModel.setDueNextWeek()

        XCTAssertTrue(viewModel.hasDueDate)
        XCTAssertNotNil(viewModel.dueDate)

        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
        XCTAssertTrue(Calendar.current.isDate(viewModel.dueDate!, inSameDayAs: nextWeek))
    }

    func testClearDueDate() {
        viewModel.hasDueDate = true
        viewModel.dueDate = Date()
        viewModel.hasDueTime = true
        viewModel.dueTime = Date()

        viewModel.clearDueDate()

        XCTAssertFalse(viewModel.hasDueDate)
        XCTAssertNil(viewModel.dueDate)
        XCTAssertFalse(viewModel.hasDueTime)
        XCTAssertNil(viewModel.dueTime)
    }

    // MARK: - Duration Presets Tests

    func testDurationPresets_Contains8Options() {
        XCTAssertEqual(TaskViewModel.durationPresets.count, 8)
    }

    func testDurationPresets_Values() {
        let presets = TaskViewModel.durationPresets

        XCTAssertEqual(presets[0].0, "15 min")
        XCTAssertEqual(presets[0].1, 15 * 60)
        XCTAssertEqual(presets[1].0, "30 min")
        XCTAssertEqual(presets[1].1, 30 * 60)
        XCTAssertEqual(presets[2].0, "45 min")
        XCTAssertEqual(presets[2].1, 45 * 60)
        XCTAssertEqual(presets[3].0, "1 hour")
        XCTAssertEqual(presets[3].1, 60 * 60)
        XCTAssertEqual(presets[4].0, "1.5 hours")
        XCTAssertEqual(presets[4].1, 90 * 60)
        XCTAssertEqual(presets[5].0, "2 hours")
        XCTAssertEqual(presets[5].1, 120 * 60)
        XCTAssertEqual(presets[6].0, "3 hours")
        XCTAssertEqual(presets[6].1, 180 * 60)
        XCTAssertEqual(presets[7].0, "4 hours")
        XCTAssertEqual(presets[7].1, 240 * 60)
    }

    // MARK: - Category Tests

    func testCategoryChange() async throws {
        viewModel.title = "Work Task"
        viewModel.category = .work

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertEqual(savedTask?.category, .work)
    }

    func testCategoryChange_EditExistingTask() async throws {
        // Create task with initial category
        let existingTask = taskService.createTask(
            title: "Task",
            category: .personal
        )

        // Edit and change category
        let editViewModel = TaskViewModel(taskService: taskService, task: existingTask)
        XCTAssertEqual(editViewModel.category, .personal)

        editViewModel.category = .work

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = editViewModel.save()

        XCTAssertEqual(savedTask?.category, .work)
    }

    func testAllCategoriesAvailable() {
        // Verify all categories can be set
        let allCategories: [TaskCategory] = [
            .uncategorized, .work, .personal, .health,
            .finance, .shopping, .errands, .learning, .home
        ]

        for category in allCategories {
            viewModel.category = category
            XCTAssertEqual(viewModel.category, category)
        }
    }

    // MARK: - Estimated Duration Tests

    func testEstimatedDuration() async throws {
        viewModel.title = "Timed Task"
        viewModel.estimatedDuration = 3600 // 1 hour

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertEqual(savedTask?.estimatedDuration, 3600)
    }

    // MARK: - Reminder Tests

    func testReminder_SetAndSave() async throws {
        viewModel.title = "Task with Reminder"
        viewModel.hasReminder = true
        viewModel.reminderDate = Date().addingTimeInterval(3600)

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNotNil(savedTask?.reminderDate)
    }

    func testReminder_ClearWhenDisabled() async throws {
        viewModel.title = "Task"
        viewModel.hasReminder = true
        viewModel.reminderDate = Date().addingTimeInterval(3600)
        viewModel.hasReminder = false

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNil(savedTask?.reminderDate)
    }

    // MARK: - List Assignment Tests

    func testListAssignment() async throws {
        // Create a real TaskList first so the listID is valid in the database
        let taskListService = TaskListService(persistenceController: persistenceController)
        let createdList = taskListService.createList(name: "Test List")

        viewModel.title = "List Task"
        viewModel.selectedListID = createdList.id

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertEqual(savedTask?.listID, createdList.id)
    }

    func testListAssignment_MoveTaskBetweenLists() async throws {
        // Create two lists
        let taskListService = TaskListService(persistenceController: persistenceController)
        let list1 = taskListService.createList(name: "List 1")
        let list2 = taskListService.createList(name: "List 2")

        // Create task in list 1
        let existingTask = taskService.createTask(
            title: "Task",
            listID: list1.id
        )

        // Edit and move to list 2
        let editViewModel = TaskViewModel(taskService: taskService, task: existingTask)
        XCTAssertEqual(editViewModel.selectedListID, list1.id)

        editViewModel.selectedListID = list2.id

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = editViewModel.save()

        XCTAssertEqual(savedTask?.listID, list2.id)
    }

    func testListAssignment_RemoveFromList() async throws {
        // Create a list
        let taskListService = TaskListService(persistenceController: persistenceController)
        let list = taskListService.createList(name: "Test List")

        // Create task in list
        let existingTask = taskService.createTask(
            title: "Task",
            listID: list.id
        )

        // Edit and remove from list
        let editViewModel = TaskViewModel(taskService: taskService, task: existingTask)
        editViewModel.selectedListID = nil

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = editViewModel.save()

        XCTAssertNil(savedTask?.listID)
    }

    // MARK: - Recurring Rule Tests

    func testRecurringRule_Weekly_WithDays() async throws {
        viewModel.title = "Weekly Task"
        viewModel.isRecurring = true
        viewModel.recurringFrequency = .weekly
        viewModel.recurringInterval = 1
        viewModel.recurringDaysOfWeek = [1, 3, 5] // Mon, Wed, Fri

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNotNil(savedTask?.recurringRule)
        XCTAssertEqual(savedTask?.recurringRule?.frequency, .weekly)
        XCTAssertEqual(savedTask?.recurringRule?.daysOfWeek, [1, 3, 5])
    }

    func testRecurringRule_WithEndDate() async throws {
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!

        viewModel.title = "Limited Recurring Task"
        viewModel.isRecurring = true
        viewModel.recurringFrequency = .daily
        viewModel.recurringEndDate = endDate

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNotNil(savedTask?.recurringRule?.endDate)
    }

    func testRecurringRule_Disabled_NoRule() async throws {
        viewModel.title = "Non-recurring Task"
        viewModel.isRecurring = false
        viewModel.recurringFrequency = .daily // Set but should be ignored

        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000)

        let savedTask = viewModel.save()

        XCTAssertNil(savedTask?.recurringRule)
    }

    // MARK: - Performance Tests

    func testSavePerformance() {
        measure {
            viewModel.title = "Performance Test Task"
            _ = viewModel.save()
        }
    }
}
