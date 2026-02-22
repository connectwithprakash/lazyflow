import Combine
import SwiftUI

/// Thin coordinator managing Focus Mode state.
/// Persists active session to @AppStorage for rehydration across app restarts.
@MainActor
final class FocusSessionCoordinator: ObservableObject {

    // MARK: - Persistence Keys

    private static let focusTaskIDKey = "focusSessionTaskID"
    private static let focusStartedAtKey = "focusSessionStartedAt"
    private static let focusIsPausedKey = "focusSessionIsPaused"
    private static let focusIsOnBreakKey = "focusSessionIsOnBreak"

    // MARK: - Published State

    @Published var focusTaskID: UUID? {
        didSet { persistState() }
    }
    @Published var isFocusPresented: Bool = false

    /// When true, the success animation is playing and invalidation
    /// should be suppressed (the task was just completed by us).
    @Published var isCompletionAnimating: Bool = false

    /// When true, the focus ring timer is paused (user tapped ring).
    @Published var isPaused: Bool = false {
        didSet { persistState() }
    }

    /// When true, user took a break — task stopped but focusTaskID retained
    /// so the pill shows and Focus can be resumed.
    @Published var isOnBreak: Bool = false {
        didSet { persistState() }
    }

    // MARK: - Pomodoro State

    /// Timer mode: stopwatch (elapsed) or pomodoro (countdown).
    enum TimerMode: String, CaseIterable, Identifiable {
        case stopwatch
        case pomodoro

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .stopwatch: return "Stopwatch"
            case .pomodoro: return "Pomodoro"
            }
        }
    }

    @Published var timerMode: TimerMode = .stopwatch

    /// Pomodoro work interval in seconds. User-configurable via Settings.
    var pomodoroWorkInterval: TimeInterval {
        let minutes = UserDefaults.standard.double(forKey: "pomodoroWorkMinutes")
        return minutes > 0 ? minutes * 60 : 25 * 60
    }

    /// Pomodoro break interval in seconds. User-configurable via Settings.
    var pomodoroBreakInterval: TimeInterval {
        let minutes = UserDefaults.standard.double(forKey: "pomodoroBreakMinutes")
        return minutes > 0 ? minutes * 60 : 5 * 60
    }

    /// Timestamp when current Pomodoro interval started (for countdown)
    @Published var pomodoroIntervalStart: Date?

    /// Accumulated elapsed time in the current Pomodoro interval (handles pause)
    @Published var pomodoroAccumulatedElapsed: TimeInterval = 0

    /// Whether currently in a Pomodoro break interval
    @Published var isPomodoroBreak: Bool = false

    /// Number of completed Pomodoro work intervals in this session
    @Published var pomodoroCompletedIntervals: Int = 0

    /// Remaining seconds in the current Pomodoro interval (pause-aware)
    var pomodoroRemainingSeconds: TimeInterval {
        let interval = isPomodoroBreak ? pomodoroBreakInterval : pomodoroWorkInterval
        var elapsed = pomodoroAccumulatedElapsed
        if let start = pomodoroIntervalStart, !isPaused {
            elapsed += Date().timeIntervalSince(start)
        }
        return max(0, interval - elapsed)
    }

    /// Whether the current Pomodoro interval has elapsed
    var isPomodoroIntervalComplete: Bool {
        pomodoroRemainingSeconds <= 0
    }

    /// Suppresses invalidation during task switch handoff.
    private var isSwitching: Bool = false

    // MARK: - Dependencies

    private let taskService: TaskService
    private let prioritizationService: PrioritizationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        taskService: TaskService = .shared,
        prioritizationService: PrioritizationService? = nil
    ) {
        self.taskService = taskService
        self.prioritizationService = prioritizationService ?? PrioritizationService.shared

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

    /// Show the return-to-focus pill when dismissed but task still in progress,
    /// when paused, on break, or during Pomodoro break.
    var shouldShowPill: Bool {
        guard let id = focusTaskID, !isFocusPresented else { return false }
        if isOnBreak || isPaused || isPomodoroBreak { return true }
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
        isOnBreak = false
        isPaused = false
        resetPomodoroState()
        taskService.startWorking(on: task)
        focusTaskID = task.id
        isFocusPresented = true

        // Start Pomodoro interval if in pomodoro mode
        if timerMode == .pomodoro {
            startPomodoroInterval()
        }
    }

    /// Dismiss Focus overlay without stopping the task (pill will show).
    func dismissFocus() {
        isFocusPresented = false
    }

    /// Reopen Focus Mode from the pill.
    func reopenFocus() {
        // During Pomodoro break, don't resume task work — just reopen the view
        if !isPomodoroBreak {
            if let task = focusedTask {
                if isOnBreak || isPaused {
                    taskService.resumeWorking(on: task)
                }
            }
            isOnBreak = false

            // Resume pomodoro countdown if it was paused
            if timerMode == .pomodoro && isPaused {
                pomodoroIntervalStart = Date()
            }
            isPaused = false
        }
        isFocusPresented = true
    }

    /// Toggle pause/resume on the focus ring timer.
    func togglePause() {
        if !isPaused {
            // Pausing: accumulate pomodoro elapsed time
            if timerMode == .pomodoro, let start = pomodoroIntervalStart {
                pomodoroAccumulatedElapsed += Date().timeIntervalSince(start)
                pomodoroIntervalStart = nil
            }
            isPaused = true
            // Only stop task work if not already stopped (i.e., not during Pomodoro break)
            if !isPomodoroBreak, let task = focusedTask {
                taskService.stopWorking(on: task)
            }
        } else {
            // Resuming: restart pomodoro interval timer
            if timerMode == .pomodoro {
                pomodoroIntervalStart = Date()
            }
            isPaused = false
            // Only resume task work if not in Pomodoro break (break keeps work stopped)
            if !isPomodoroBreak, let task = focusedTask {
                taskService.resumeWorking(on: task)
            }
        }
    }

    /// Take a break — stop working and dismiss overlay, but retain focus session.
    /// The pill will show so the user can resume later.
    /// If already in a Pomodoro break, this is a no-op (use the Pomodoro break flow instead).
    func takeBreak() {
        guard !isPomodoroBreak else { return }
        if let task = focusedTask {
            taskService.stopWorking(on: task)
        }
        isOnBreak = true
        isPaused = false
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
        isPaused = false
        isOnBreak = false
        focusTaskID = nil
        isFocusPresented = false
        resetPomodoroState()
        clearPersistedState()
    }

    /// Switch to a different task while staying in Focus Mode.
    /// Guards against invalidation during the handoff window.
    func switchTask(to newTask: Task) {
        isSwitching = true
        isPaused = false
        isPomodoroBreak = false
        isOnBreak = false
        focusTaskID = newTask.id
        taskService.startWorking(on: newTask)
        isSwitching = false

        // Restart Pomodoro interval for the new task if in Pomodoro mode
        if timerMode == .pomodoro {
            startPomodoroInterval()
        }
    }

    // MARK: - Pomodoro Actions

    /// Start a new Pomodoro work interval
    func startPomodoroInterval() {
        isPomodoroBreak = false
        pomodoroAccumulatedElapsed = 0
        pomodoroIntervalStart = Date()
    }

    /// Transition to Pomodoro break
    func startPomodoroBreak() {
        pomodoroCompletedIntervals += 1
        isPomodoroBreak = true
        isPaused = false  // Normalize: break starts unpaused
        pomodoroAccumulatedElapsed = 0
        pomodoroIntervalStart = Date()

        // Stop working on the task during break
        if let task = focusedTask {
            taskService.stopWorking(on: task)
        }
    }

    /// End Pomodoro break and start next work interval
    func endPomodoroBreak() {
        isPomodoroBreak = false
        isOnBreak = false  // Clear any stale regular break flag
        isPaused = false   // Normalize: work starts unpaused
        pomodoroAccumulatedElapsed = 0
        pomodoroIntervalStart = Date()

        // Resume working on the task
        if let task = focusedTask {
            taskService.resumeWorking(on: task)
        }
    }

    /// Switch timer mode, cleaning up state from the previous mode.
    /// No-op if already in the requested mode.
    func setTimerMode(_ mode: TimerMode) {
        guard mode != timerMode else { return }

        let wasInPomodoroBreak = isPomodoroBreak
        let wasPaused = isPaused
        timerMode = mode

        if mode == .stopwatch {
            // Leaving Pomodoro: reset all Pomodoro state
            resetPomodoroState()
            // If we were in a Pomodoro break or paused, resume work
            if wasInPomodoroBreak || wasPaused {
                isPaused = false
                if let task = focusedTask {
                    taskService.resumeWorking(on: task)
                }
            }
        } else if mode == .pomodoro {
            startPomodoroInterval()
        }
    }

    /// Reset Pomodoro state
    private func resetPomodoroState() {
        pomodoroIntervalStart = nil
        pomodoroAccumulatedElapsed = 0
        isPomodoroBreak = false
        pomodoroCompletedIntervals = 0
    }

    /// Handle external invalidation (task deleted, completed, or stopped externally).
    func handleTaskInvalidated() {
        isPaused = false
        isOnBreak = false
        focusTaskID = nil
        isFocusPresented = false
        resetPomodoroState()
        clearPersistedState()
    }

    // MARK: - Persistence

    /// Save current focus state to UserDefaults for rehydration across restarts
    private func persistState() {
        let defaults = UserDefaults.standard
        if let id = focusTaskID {
            defaults.set(id.uuidString, forKey: Self.focusTaskIDKey)
            defaults.set(isPaused, forKey: Self.focusIsPausedKey)
            defaults.set(isOnBreak, forKey: Self.focusIsOnBreakKey)
        } else {
            defaults.removeObject(forKey: Self.focusTaskIDKey)
            defaults.removeObject(forKey: Self.focusStartedAtKey)
            defaults.removeObject(forKey: Self.focusIsPausedKey)
            defaults.removeObject(forKey: Self.focusIsOnBreakKey)
        }
    }

    /// Clear persisted state (called when session ends normally)
    private func clearPersistedState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.focusTaskIDKey)
        defaults.removeObject(forKey: Self.focusStartedAtKey)
        defaults.removeObject(forKey: Self.focusIsPausedKey)
        defaults.removeObject(forKey: Self.focusIsOnBreakKey)
    }

    /// Attempt to restore a focus session from persisted state.
    /// Returns true if a valid session was restored (pill will show).
    @discardableResult
    func rehydrate() -> Bool {
        let defaults = UserDefaults.standard
        guard let idString = defaults.string(forKey: Self.focusTaskIDKey),
              let id = UUID(uuidString: idString) else {
            return false
        }

        // Validate that the task still exists and is not completed/deleted
        guard let task = taskService.tasks.first(where: { $0.id == id }),
              !task.isCompleted else {
            clearPersistedState()
            return false
        }

        focusTaskID = id
        isPaused = defaults.bool(forKey: Self.focusIsPausedKey)
        isOnBreak = defaults.bool(forKey: Self.focusIsOnBreakKey)

        if isPaused || isOnBreak {
            // Ensure the task is stopped — it may still have stale in-progress state
            // from a previous session that wasn't fully flushed before the app quit.
            if task.isInProgress {
                taskService.stopWorking(on: task)
            }
        } else if !task.isInProgress {
            // Active session (not paused/break): resume so elapsed timer keeps ticking.
            taskService.resumeWorking(on: task)
        }

        // Don't auto-present fullscreen — show the pill so the user can choose to resume
        return true
    }

    // MARK: - Private

    private func checkForExternalInvalidation() {
        guard let id = focusTaskID, !isCompletionAnimating, !isSwitching else { return }
        let task = taskService.tasks.first { $0.id == id }
        // Always invalidate if task was deleted or completed externally
        if task == nil || task?.isCompleted == true {
            handleTaskInvalidated()
            return
        }
        // During pause, break, or Pomodoro break, task is intentionally stopped — don't check isInProgress
        if isPaused || isOnBreak || isPomodoroBreak { return }
        if task?.isInProgress != true {
            handleTaskInvalidated()
        }
    }
}
