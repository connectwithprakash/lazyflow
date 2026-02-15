import Combine
import SwiftUI

/// Thin coordinator managing Focus Mode state.
/// Pure in-memory — no persistence, no rehydration.
@MainActor
final class FocusSessionCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var focusTaskID: UUID?
    @Published var isFocusPresented: Bool = false

    /// When true, the success animation is playing and invalidation
    /// should be suppressed (the task was just completed by us).
    @Published var isCompletionAnimating: Bool = false

    /// Suppresses invalidation during task switch handoff.
    private var isSwitching: Bool = false

    // MARK: - Dependencies

    private let taskService: TaskService
    private let prioritizationService: PrioritizationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        taskService: TaskService = .shared,
        prioritizationService: PrioritizationService = .shared
    ) {
        self.taskService = taskService
        self.prioritizationService = prioritizationService

        // Observe task changes to invalidate stale focus state
        // (covers both full-screen and pill modes)
        taskService.$tasks
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkForExternalInvalidation()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed

    /// The task currently in focus, if still valid.
    var focusedTask: Task? {
        guard let id = focusTaskID else { return nil }
        return taskService.tasks.first { $0.id == id }
    }

    /// Show the return-to-focus pill when dismissed but task still in progress.
    var shouldShowPill: Bool {
        guard let id = focusTaskID, !isFocusPresented else { return false }
        return taskService.getInProgressTask()?.id == id
    }

    /// Up to 2 alternative suggestions for "Switch Task".
    var alternatives: [TaskSuggestion] {
        Array(
            prioritizationService.cachedSuggestions
                .filter { $0.task.id != focusTaskID }
                .prefix(2)
        )
    }

    // MARK: - Actions

    /// Enter Focus Mode for a task. Starts working if not already.
    func enterFocus(task: Task) {
        taskService.startWorking(on: task)
        focusTaskID = task.id
        isFocusPresented = true
    }

    /// Dismiss Focus overlay without stopping the task (pill will show).
    func dismissFocus() {
        isFocusPresented = false
    }

    /// Reopen Focus Mode from the pill.
    func reopenFocus() {
        isFocusPresented = true
    }

    /// Take a break — stop working and exit focus entirely.
    func takeBreak() {
        if let task = focusedTask {
            taskService.stopWorking(on: task)
        }
        focusTaskID = nil
        isFocusPresented = false
    }

    /// Mark the focused task as complete.
    /// Does NOT clear focusTaskID immediately — the caller drives the
    /// success animation and then calls `finishCompletion()`.
    func markComplete() {
        isCompletionAnimating = true
        if let task = focusedTask {
            taskService.toggleTaskCompletion(task)
        }
    }

    /// Called after the 1.2s success animation completes.
    func finishCompletion() {
        isCompletionAnimating = false
        focusTaskID = nil
        isFocusPresented = false
    }

    /// Switch to a different task while staying in Focus Mode.
    /// Guards against invalidation during the handoff window.
    func switchTask(to newTask: Task) {
        isSwitching = true
        focusTaskID = newTask.id
        taskService.startWorking(on: newTask)
        isSwitching = false
    }

    /// Handle external invalidation (task deleted, completed, or stopped externally).
    func handleTaskInvalidated() {
        focusTaskID = nil
        isFocusPresented = false
    }

    // MARK: - Private

    private func checkForExternalInvalidation() {
        guard let id = focusTaskID, !isCompletionAnimating, !isSwitching else { return }
        let task = taskService.tasks.first { $0.id == id }
        if task == nil || task?.isCompleted == true || task?.isInProgress != true {
            handleTaskInvalidated()
        }
    }
}
