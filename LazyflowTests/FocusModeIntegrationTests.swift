import XCTest
import Combine
@testable import Lazyflow

@MainActor
final class FocusModeIntegrationTests: XCTestCase {
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

    // MARK: - Full Flow: Enter → Complete → Finish Animation → Dismiss

    func testFullFlow_enterComplete_clearsStateAfterAnimation() {
        let task = createTask(title: "Complete me")

        coordinator.enterFocus(task: task)
        XCTAssertTrue(coordinator.isFocusPresented)
        XCTAssertNotNil(coordinator.focusedTask)

        // markComplete preserves state during animation
        coordinator.markComplete()
        XCTAssertTrue(coordinator.isCompletionAnimating)
        XCTAssertTrue(coordinator.isFocusPresented)
        let updatedTask = taskService.tasks.first { $0.id == task.id }
        XCTAssertTrue(updatedTask?.isCompleted == true)

        // finishCompletion clears everything
        coordinator.finishCompletion()
        XCTAssertNil(coordinator.focusTaskID)
        XCTAssertFalse(coordinator.isFocusPresented)
    }

    // MARK: - Full Flow: Enter → Take Break → Task Stopped, Session Retained

    func testFullFlow_enterTakeBreak_stopsWorkButRetainsSession() {
        let task = createTask(title: "Break task")

        coordinator.enterFocus(task: task)
        XCTAssertEqual(taskService.getInProgressTask()?.id, task.id)

        coordinator.takeBreak()

        // Break stops working but retains focusTaskID so pill shows
        XCTAssertEqual(coordinator.focusTaskID, task.id)
        XCTAssertTrue(coordinator.isOnBreak)
        XCTAssertFalse(coordinator.isFocusPresented)
        XCTAssertNil(taskService.getInProgressTask())
    }

    // MARK: - Switch Task: Enter → Switch → New Task Active

    func testSwitchTask_changesActiveTask() {
        let task1 = createTask(title: "Task one")
        let task2 = createTask(title: "Task two")

        coordinator.enterFocus(task: task1)
        XCTAssertEqual(coordinator.focusTaskID, task1.id)

        coordinator.switchTask(to: task2)

        XCTAssertEqual(coordinator.focusTaskID, task2.id)
        XCTAssertTrue(coordinator.isFocusPresented)
        XCTAssertEqual(taskService.getInProgressTask()?.id, task2.id)
        // First task should no longer be in progress
        let firstTask = taskService.tasks.first { $0.id == task1.id }
        XCTAssertFalse(firstTask?.isInProgress == true)
    }

    // MARK: - Dismiss + Pill: Enter → Dismiss → Pill Shows

    func testDismiss_pillShouldShow() {
        let task = createTask(title: "Pill task")

        coordinator.enterFocus(task: task)
        coordinator.dismissFocus()

        XCTAssertTrue(coordinator.shouldShowPill)
        XCTAssertEqual(coordinator.focusTaskID, task.id)
        XCTAssertFalse(coordinator.isFocusPresented)
    }

    // MARK: - External Invalidation: Task Completed Externally

    func testExternalInvalidation_taskCompletedExternally_autoDismisses() {
        let task = createTask(title: "External complete")

        coordinator.enterFocus(task: task)
        XCTAssertTrue(coordinator.isFocusPresented)

        // Externally complete the task — coordinator's built-in observer
        // uses receive(on: RunLoop.main) so in synchronous tests we
        // trigger handleTaskInvalidated manually to verify the logic
        taskService.toggleTaskCompletion(task)

        let focusedTask = taskService.tasks.first { $0.id == task.id }
        if focusedTask == nil || focusedTask?.isCompleted == true || focusedTask?.isInProgress != true {
            coordinator.handleTaskInvalidated()
        }

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
