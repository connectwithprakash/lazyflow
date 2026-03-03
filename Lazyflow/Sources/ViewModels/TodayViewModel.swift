import Foundation
import Observation
import Combine

/// Atomic data structure for all task lists - ensures single SwiftUI update
struct TodayTaskData: Equatable {
    var overdueTasks: [Task]
    var todayTasks: [Task]
    var completedTodayTasks: [Task]

    static let empty = TodayTaskData(overdueTasks: [], todayTasks: [], completedTodayTasks: [])
}

/// ViewModel for the Today view
@MainActor
@Observable
final class TodayViewModel {
    // SINGLE source of truth - atomic updates prevent UICollectionView crashes
    private(set) var taskData = TodayTaskData.empty

    var isLoading: Bool = false
    var showAddTask: Bool = false
    var selectedTask: Task?
    var searchQuery: String = "" {
        didSet { scheduleSearchDebounce() }
    }
    var expandedTaskIDs: Set<UUID> = []

    // Computed properties for backward compatibility
    var overdueTasks: [Task] { taskData.overdueTasks }
    var todayTasks: [Task] { taskData.todayTasks }
    var completedTodayTasks: [Task] { taskData.completedTodayTasks }

    private let taskService: TaskService
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var searchDebounceTask: _Concurrency.Task<Void, Never>?

    init(taskService: TaskService = .shared) {
        self.taskService = taskService
        setupBindings()
    }

    private func setupBindings() {
        // Observe Core Data saves to refresh tasks
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)
    }

    private func scheduleSearchDebounce() {
        searchDebounceTask?.cancel()
        let query = searchQuery
        searchDebounceTask = _Concurrency.Task { @MainActor [weak self] in
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(AppConstants.Timing.searchDebounce * 1_000_000_000))
            guard !_Concurrency.Task.isCancelled else { return }
            self?.filterTasks(query: query)
        }
    }

    func refreshTasks() {
        isLoading = true
        defer { isLoading = false }

        let overdue = taskService.fetchOverdueTasks()
        let today = taskService.fetchTodayTasks()

        // ATOMIC UPDATE: Single @Published property change = single SwiftUI update
        // NOTE: Do NOT use withAnimation here - it interferes with UICollectionView batch updates
        // Let SwiftUI handle animations at the View layer via implicit animations
        taskData = TodayTaskData(
            overdueTasks: overdue.filter { !$0.isCompleted },
            todayTasks: today.filter { !$0.isCompleted },
            completedTodayTasks: today.filter { $0.isCompleted }
        )
    }

    private func filterTasks(query: String) {
        if query.isEmpty {
            refreshTasks()
        } else {
            let searchResults = taskService.searchTasks(query: query)
            let todayDate = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: todayDate)!

            let filteredToday = searchResults.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= todayDate && dueDate < tomorrow && !task.isCompleted
            }
            let filteredOverdue = searchResults.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < todayDate && !task.isCompleted
            }

            // ATOMIC UPDATE - no withAnimation to prevent UICollectionView batch update conflicts
            taskData = TodayTaskData(
                overdueTasks: filteredOverdue,
                todayTasks: filteredToday,
                completedTodayTasks: taskData.completedTodayTasks
            )
        }
    }

    // MARK: - Actions

    func toggleTaskCompletion(_ task: Task) {
        taskService.toggleTaskCompletion(task)
    }

    func deleteTask(_ task: Task, allowUndo: Bool = false) {
        taskService.deleteTask(task, allowUndo: allowUndo)
    }

    /// Commit pending changes (call when undo window closes without undo)
    func commitPendingChanges() {
        taskService.commitPendingChanges()
    }

    /// Discard pending changes (call when undo is tapped for delete)
    func discardPendingChanges() {
        taskService.discardPendingChanges()
    }

    func updateTaskPriority(_ task: Task, priority: Priority) {
        var updatedTask = task
        updatedTask.priority = priority
        taskService.updateTask(updatedTask)
    }

    func updateTaskDueDate(_ task: Task, dueDate: Date?) {
        var updatedTask = task
        updatedTask.dueDate = dueDate
        taskService.updateTask(updatedTask)
    }

    func startWorking(on task: Task) {
        taskService.startWorking(on: task)
    }

    func resumeWorking(on task: Task) {
        taskService.resumeWorking(on: task)
    }

    func stopWorking(on task: Task) {
        taskService.stopWorking(on: task)
    }

    func createTask(title: String, priority: Priority = .none) {
        taskService.createTask(
            title: title,
            dueDate: Date(),
            priority: priority
        )
    }

    var totalTaskCount: Int {
        overdueTasks.count + todayTasks.count
    }

    /// Count of ALL incomplete tasks (not just today/overdue) — used for Next Up gating
    var allIncompleteTaskCount: Int {
        taskService.tasks.filter { !$0.isCompleted && !$0.isArchived }.count
    }

    var completedTaskCount: Int {
        completedTodayTasks.count
    }

    var progressPercentage: Double {
        let total = totalTaskCount + completedTaskCount
        guard total > 0 else { return 0 }
        return Double(completedTaskCount) / Double(total)
    }

    // MARK: - Expansion State Management

    func isExpanded(_ taskID: UUID) -> Bool {
        expandedTaskIDs.contains(taskID)
    }

    func toggleExpansion(_ taskID: UUID) {
        if expandedTaskIDs.contains(taskID) {
            expandedTaskIDs.remove(taskID)
        } else {
            expandedTaskIDs.insert(taskID)
        }
    }

    func setExpanded(_ taskID: UUID, expanded: Bool) {
        if expanded {
            expandedTaskIDs.insert(taskID)
        } else {
            expandedTaskIDs.remove(taskID)
        }
    }

    /// Auto-expand tasks that have incomplete subtasks
    func autoExpandTasksWithSubtasks() {
        let allTasks = overdueTasks + todayTasks
        for task in allTasks where task.hasSubtasks && !task.allSubtasksCompleted {
            expandedTaskIDs.insert(task.id)
        }
    }
}
