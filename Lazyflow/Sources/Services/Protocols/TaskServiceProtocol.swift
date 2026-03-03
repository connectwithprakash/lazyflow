import Foundation

/// Protocol defining the public API surface of TaskService consumed by ViewModels.
protocol TaskServiceProtocol: AnyObject {
    // MARK: - Observable Properties

    var tasks: [Task] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var pendingDeleteTaskID: UUID? { get }
    var canUndo: Bool { get }
    var canRedo: Bool { get }

    // MARK: - Fetch Operations

    func fetchAllTasks()
    func fetchTodayTasks() -> [Task]
    func fetchOverdueTasks() -> [Task]
    func fetchUpcomingTasks() -> [Task]
    func fetchTasks(forListID listID: UUID) -> [Task]
    func fetchCompletedTasks() -> [Task]
    func fetchTasksCompletedOn(date: Date) -> [Task]
    func fetchTasksDueOn(date: Date) -> [Task]
    func fetchTasksWithoutDueDate() -> [Task]
    func searchTasks(query: String) -> [Task]
    func fetchSubtasks(forParentID parentID: UUID) -> [Task]

    // MARK: - Create Operations

    @discardableResult
    func createTask(
        title: String,
        notes: String?,
        dueDate: Date?,
        dueTime: Date?,
        reminderDate: Date?,
        priority: Priority,
        category: TaskCategory,
        customCategoryID: UUID?,
        listID: UUID?,
        estimatedDuration: TimeInterval?,
        recurringRule: RecurringRule?,
        linkedEventID: String?,
        calendarItemExternalIdentifier: String?,
        lastSyncedAt: Date?,
        scheduledStartTime: Date?,
        scheduledEndTime: Date?
    ) -> Task

    @discardableResult
    func createSubtask(
        title: String,
        parentTaskID: UUID,
        notes: String?,
        dueDate: Date?,
        dueTime: Date?,
        priority: Priority?
    ) -> Task?

    @discardableResult
    func createSubtasks(titles: [String], parentTaskID: UUID) -> [Task]

    // MARK: - Update Operations

    func updateTask(_ task: Task)
    func toggleTaskCompletion(_ task: Task)
    func incrementIntradayCompletion(_ task: Task)
    func resetIntradayCompletions(_ task: Task)
    func resetAllIntradayCompletions()
    func moveTask(_ task: Task, toListID listID: UUID?)

    // MARK: - In-Progress Management

    func getInProgressTask() -> Task?
    func startWorking(on task: Task)
    func stopWorking(on task: Task)
    func resumeWorking(on task: Task)

    // MARK: - Calendar Integration

    func linkTaskToEvent(_ task: Task, eventID: String, calendarItemExternalIdentifier: String?)
    func unlinkTaskFromEvent(_ task: Task)
    func createCalendarEvent(for task: Task, startDate: Date, duration: TimeInterval) throws

    // MARK: - Delete Operations

    func deleteTask(_ task: Task, deleteLinkedEvent: Bool, allowUndo: Bool)
    func commitPendingChanges()
    func discardPendingChanges()
    func archiveTask(_ task: Task)
    func deleteCompletedTasks()

    // MARK: - Subtask Operations

    func promoteSubtaskToTask(_ subtask: Task)
    @discardableResult
    func checkAutoCompleteParent(subtaskID: UUID) -> Bool
    func toggleSubtaskCompletion(_ subtask: Task)
    func reorderSubtasks(_ subtasks: [Task], parentID: UUID)

    // MARK: - Undo/Redo

    func undo()
    func redo()
    func beginUndoGrouping(named name: String?)
    func endUndoGrouping()
    func removeAllUndoActions()
}

// MARK: - Default Parameter Values

extension TaskServiceProtocol {
    @discardableResult
    func createTask(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        reminderDate: Date? = nil,
        priority: Priority = .none,
        category: TaskCategory = .uncategorized,
        customCategoryID: UUID? = nil,
        listID: UUID? = nil,
        estimatedDuration: TimeInterval? = nil,
        recurringRule: RecurringRule? = nil,
        linkedEventID: String? = nil,
        calendarItemExternalIdentifier: String? = nil,
        lastSyncedAt: Date? = nil,
        scheduledStartTime: Date? = nil,
        scheduledEndTime: Date? = nil
    ) -> Task {
        createTask(
            title: title,
            notes: notes,
            dueDate: dueDate,
            dueTime: dueTime,
            reminderDate: reminderDate,
            priority: priority,
            category: category,
            customCategoryID: customCategoryID,
            listID: listID,
            estimatedDuration: estimatedDuration,
            recurringRule: recurringRule,
            linkedEventID: linkedEventID,
            calendarItemExternalIdentifier: calendarItemExternalIdentifier,
            lastSyncedAt: lastSyncedAt,
            scheduledStartTime: scheduledStartTime,
            scheduledEndTime: scheduledEndTime
        )
    }

    @discardableResult
    func createSubtask(
        title: String,
        parentTaskID: UUID,
        notes: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        priority: Priority? = nil
    ) -> Task? {
        createSubtask(
            title: title,
            parentTaskID: parentTaskID,
            notes: notes,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority
        )
    }

    func deleteTask(_ task: Task, deleteLinkedEvent: Bool = false, allowUndo: Bool = false) {
        deleteTask(task, deleteLinkedEvent: deleteLinkedEvent, allowUndo: allowUndo)
    }

    func linkTaskToEvent(_ task: Task, eventID: String, calendarItemExternalIdentifier: String? = nil) {
        linkTaskToEvent(task, eventID: eventID, calendarItemExternalIdentifier: calendarItemExternalIdentifier)
    }

    func beginUndoGrouping(named name: String? = nil) {
        beginUndoGrouping(named: name)
    }
}
