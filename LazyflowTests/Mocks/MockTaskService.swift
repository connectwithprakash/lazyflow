import Foundation
@testable import Lazyflow

/// In-memory mock of TaskServiceProtocol for unit testing.
/// Records method calls and operates on a simple array — no Core Data dependency.
final class MockTaskService: TaskServiceProtocol {
    // MARK: - Observable Properties

    private(set) var tasks: [Task] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?
    private(set) var pendingDeleteTaskID: UUID?
    var canUndo: Bool = false
    var canRedo: Bool = false

    // MARK: - Call Recording

    private(set) var calls: [String] = []

    // MARK: - Fetch Operations

    func fetchAllTasks() {
        calls.append("fetchAllTasks")
    }

    func fetchTodayTasks() -> [Task] {
        calls.append("fetchTodayTasks")
        let todayStart = Calendar.current.startOfDay(for: Date())
        let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= todayStart && dueDate < tomorrowStart
        }
    }

    func fetchOverdueTasks() -> [Task] {
        calls.append("fetchOverdueTasks")
        let todayStart = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < todayStart && !task.isCompleted
        }
    }

    func fetchUpcomingTasks() -> [Task] {
        calls.append("fetchUpcomingTasks")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= tomorrow && !task.isCompleted
        }
    }

    func fetchTasks(forListID listID: UUID) -> [Task] {
        calls.append("fetchTasks(forListID:)")
        return tasks.filter { $0.listID == listID }
    }

    func fetchCompletedTasks() -> [Task] {
        calls.append("fetchCompletedTasks")
        return tasks.filter(\.isCompleted)
    }

    func fetchTasksCompletedOn(date: Date) -> [Task] {
        calls.append("fetchTasksCompletedOn")
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startOfDay && completedAt < endOfDay
        }
    }

    func fetchTasksDueOn(date: Date) -> [Task] {
        calls.append("fetchTasksDueOn")
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfDay && dueDate < endOfDay
        }
    }

    func fetchTasksWithoutDueDate() -> [Task] {
        calls.append("fetchTasksWithoutDueDate")
        return tasks.filter { $0.dueDate == nil }
    }

    func searchTasks(query: String) -> [Task] {
        calls.append("searchTasks")
        let lowered = query.lowercased()
        return tasks.filter { $0.title.lowercased().contains(lowered) }
    }

    func fetchSubtasks(forParentID parentID: UUID) -> [Task] {
        calls.append("fetchSubtasks")
        return tasks.filter { $0.parentTaskID == parentID }
    }

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
    ) -> Task {
        calls.append("createTask")
        let task = Task(
            title: title,
            notes: notes,
            dueDate: dueDate,
            dueTime: dueTime,
            reminderDate: reminderDate,
            priority: priority,
            category: category,
            customCategoryID: customCategoryID,
            listID: listID,
            linkedEventID: linkedEventID,
            calendarItemExternalIdentifier: calendarItemExternalIdentifier,
            lastSyncedAt: lastSyncedAt,
            scheduledStartTime: scheduledStartTime,
            scheduledEndTime: scheduledEndTime,
            estimatedDuration: estimatedDuration,
            recurringRule: recurringRule
        )
        tasks.append(task)
        return task
    }

    @discardableResult
    func createSubtask(
        title: String,
        parentTaskID: UUID,
        notes: String?,
        dueDate: Date?,
        dueTime: Date?,
        priority: Priority?
    ) -> Task? {
        calls.append("createSubtask")
        let subtask = Task(
            title: title,
            notes: notes,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority ?? .none,
            parentTaskID: parentTaskID
        )
        tasks.append(subtask)
        return subtask
    }

    @discardableResult
    func createSubtasks(titles: [String], parentTaskID: UUID) -> [Task] {
        calls.append("createSubtasks")
        return titles.compactMap { createSubtask(title: $0, parentTaskID: parentTaskID, notes: nil, dueDate: nil, dueTime: nil, priority: nil) }
    }

    // MARK: - Update Operations

    func updateTask(_ task: Task) {
        calls.append("updateTask")
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }

    func toggleTaskCompletion(_ task: Task) {
        calls.append("toggleTaskCompletion")
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = tasks[index]
            updated.isCompleted.toggle()
            updated.completedAt = updated.isCompleted ? Date() : nil
            tasks[index] = updated
        }
    }

    func incrementIntradayCompletion(_ task: Task) {
        calls.append("incrementIntradayCompletion")
    }

    func resetIntradayCompletions(_ task: Task) {
        calls.append("resetIntradayCompletions")
    }

    func resetAllIntradayCompletions() {
        calls.append("resetAllIntradayCompletions")
    }

    func moveTask(_ task: Task, toListID listID: UUID?) {
        calls.append("moveTask")
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = tasks[index]
            updated.listID = listID
            tasks[index] = updated
        }
    }

    // MARK: - In-Progress Management

    func getInProgressTask() -> Task? {
        calls.append("getInProgressTask")
        return tasks.first(where: \.isInProgress)
    }

    func startWorking(on task: Task) {
        calls.append("startWorking")
    }

    func stopWorking(on task: Task) {
        calls.append("stopWorking")
    }

    func resumeWorking(on task: Task) {
        calls.append("resumeWorking")
    }

    // MARK: - Calendar Integration

    func linkTaskToEvent(_ task: Task, eventID: String, calendarItemExternalIdentifier: String?) {
        calls.append("linkTaskToEvent")
    }

    func unlinkTaskFromEvent(_ task: Task) {
        calls.append("unlinkTaskFromEvent")
    }

    func createCalendarEvent(for task: Task, startDate: Date, duration: TimeInterval) throws {
        calls.append("createCalendarEvent")
    }

    // MARK: - Delete Operations

    func deleteTask(_ task: Task, deleteLinkedEvent: Bool, allowUndo: Bool) {
        calls.append("deleteTask")
        tasks.removeAll { $0.id == task.id }
    }

    func commitPendingChanges() {
        calls.append("commitPendingChanges")
        pendingDeleteTaskID = nil
    }

    func discardPendingChanges() {
        calls.append("discardPendingChanges")
        pendingDeleteTaskID = nil
    }

    func archiveTask(_ task: Task) {
        calls.append("archiveTask")
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = tasks[index]
            updated.isArchived = true
            tasks[index] = updated
        }
    }

    func deleteCompletedTasks() {
        calls.append("deleteCompletedTasks")
        tasks.removeAll(where: \.isCompleted)
    }

    // MARK: - Subtask Operations

    func promoteSubtaskToTask(_ subtask: Task) {
        calls.append("promoteSubtaskToTask")
    }

    @discardableResult
    func checkAutoCompleteParent(subtaskID: UUID) -> Bool {
        calls.append("checkAutoCompleteParent")
        return false
    }

    func toggleSubtaskCompletion(_ subtask: Task) {
        calls.append("toggleSubtaskCompletion")
        toggleTaskCompletion(subtask)
    }

    func reorderSubtasks(_ subtasks: [Task], parentID: UUID) {
        calls.append("reorderSubtasks")
    }

    // MARK: - Undo/Redo

    func undo() { calls.append("undo") }
    func redo() { calls.append("redo") }
    func beginUndoGrouping(named name: String?) { calls.append("beginUndoGrouping") }
    func endUndoGrouping() { calls.append("endUndoGrouping") }
    func removeAllUndoActions() { calls.append("removeAllUndoActions") }
}
