import XCTest
import Combine
@testable import Lazyflow

@MainActor
final class FocusSessionCoordinatorTests: XCTestCase {
    var persistenceController: PersistenceController!
    var taskService: TaskService!
    var coordinator: FocusSessionCoordinator!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        taskService = TaskService(persistenceController: persistenceController)
        coordinator = FocusSessionCoordinator(taskService: taskService)
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        taskService = nil
        coordinator = nil
    }

    // MARK: - enterFocus

    func testEnterFocus_setsFocusState_andStartsWorking() {
        let task = createTask(title: "Focus task")

        coordinator.enterFocus(task: task)

        XCTAssertEqual(coordinator.focusTaskID, task.id)
        XCTAssertTrue(coordinator.isFocusPresented)
        XCTAssertEqual(taskService.getInProgressTask()?.id, task.id)
    }

    // MARK: - dismissFocus

    func testDismissFocus_hidesPresentation_preservesTaskID() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)

        coordinator.dismissFocus()

        XCTAssertFalse(coordinator.isFocusPresented)
        XCTAssertEqual(coordinator.focusTaskID, task.id)
    }

    // MARK: - takeBreak

    func testTakeBreak_clearsState_andStopsWorking() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)

        coordinator.takeBreak()

        XCTAssertNil(coordinator.focusTaskID)
        XCTAssertFalse(coordinator.isFocusPresented)
        XCTAssertNil(taskService.getInProgressTask())
    }

    // MARK: - markComplete + finishCompletion

    func testMarkComplete_setsAnimating_completesTask_preservesPresentation() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)

        coordinator.markComplete()

        // During animation: focusTaskID and isFocusPresented preserved
        XCTAssertTrue(coordinator.isCompletionAnimating)
        XCTAssertNotNil(coordinator.focusTaskID)
        XCTAssertTrue(coordinator.isFocusPresented)
        let updatedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertTrue(updatedTask?.isCompleted == true)
    }

    func testFinishCompletion_clearsAllState() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)
        coordinator.markComplete()

        coordinator.finishCompletion()

        XCTAssertNil(coordinator.focusTaskID)
        XCTAssertFalse(coordinator.isFocusPresented)
        XCTAssertFalse(coordinator.isCompletionAnimating)
    }

    // MARK: - switchTask

    func testSwitchTask_updatesTaskID_andStartsNewTask() {
        let task1 = createTask(title: "First task")
        let task2 = createTask(title: "Second task")
        coordinator.enterFocus(task: task1)

        coordinator.switchTask(to: task2)

        XCTAssertEqual(coordinator.focusTaskID, task2.id)
        XCTAssertTrue(coordinator.isFocusPresented)
        XCTAssertEqual(taskService.getInProgressTask()?.id, task2.id)
    }

    func testSwitchTask_doesNotInvalidate() {
        let task1 = createTask(title: "First task")
        let task2 = createTask(title: "Second task")
        coordinator.enterFocus(task: task1)

        // focusTaskID is updated before startWorking, preventing invalidation
        coordinator.switchTask(to: task2)

        XCTAssertTrue(coordinator.isFocusPresented)
        XCTAssertEqual(coordinator.focusTaskID, task2.id)
    }

    // MARK: - reopenFocus

    func testReopenFocus_setsPresented() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)
        coordinator.dismissFocus()

        coordinator.reopenFocus()

        XCTAssertTrue(coordinator.isFocusPresented)
    }

    // MARK: - shouldShowPill

    func testShouldShowPill_true_whenDismissedButInProgress() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)
        coordinator.dismissFocus()

        XCTAssertTrue(coordinator.shouldShowPill)
    }

    func testShouldShowPill_false_whenNoInProgressTask() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)
        coordinator.takeBreak()

        XCTAssertFalse(coordinator.shouldShowPill)
    }

    func testShouldShowPill_false_whenInProgressTaskDiffers() {
        let task1 = createTask(title: "First task")
        let task2 = createTask(title: "Second task")

        coordinator.enterFocus(task: task1)
        coordinator.dismissFocus()

        // Externally start task2
        taskService.startWorking(on: task2)

        XCTAssertFalse(coordinator.shouldShowPill)
    }

    // MARK: - handleTaskInvalidated

    func testHandleTaskInvalidated_clearsAllState() {
        let task = createTask(title: "Focus task")
        coordinator.enterFocus(task: task)

        coordinator.handleTaskInvalidated()

        XCTAssertNil(coordinator.focusTaskID)
        XCTAssertFalse(coordinator.isFocusPresented)
    }

    // MARK: - Helpers

    @discardableResult
    private func createTask(title: String) -> Task {
        taskService.createTask(title: title, dueDate: Date())
        return taskService.tasks.first { $0.title == title }!
    }
}
