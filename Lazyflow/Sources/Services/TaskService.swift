import CoreData
import Foundation
import Combine

/// Service responsible for all Task-related CRUD operations
final class TaskService: ObservableObject {
    static let shared = TaskService()

    private let persistenceController: PersistenceController
    private let notificationService: NotificationService
    private let calendarService: CalendarService

    @Published private(set) var tasks: [Task] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private var cancellables = Set<AnyCancellable>()

    init(
        persistenceController: PersistenceController = .shared,
        notificationService: NotificationService = .shared,
        calendarService: CalendarService = .shared
    ) {
        self.persistenceController = persistenceController
        self.notificationService = notificationService
        self.calendarService = calendarService
        setupObservers()
        fetchAllTasks()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Listen for local Core Data saves
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllTasks()
            }
            .store(in: &cancellables)

        // Listen for CloudKit sync completion (remote changes)
        NotificationCenter.default.publisher(for: .cloudKitSyncDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllTasks()
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Operations

    /// Fetch all non-archived, non-deleted top-level tasks (excluding subtasks)
    func fetchAllTasks() {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        // Only fetch top-level tasks (not subtasks) that are not archived and not soft-deleted
        request.predicate = NSPredicate(format: "isArchived == NO AND parentTask == nil AND isSoftDeleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.priorityRaw, ascending: false),
            NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)
        ]

        do {
            let entities = try context.fetch(request)
            tasks = entities.map { $0.toDomainModel() }
            // Sync tasks to widget
            syncTasksToWidget()
        } catch {
            self.error = error
            print("Failed to fetch tasks: \(error)")
        }
    }

    /// Sync tasks to widget via shared UserDefaults
    private func syncTasksToWidget() {
        let widgetData = tasks.map { $0.toWidgetData() }
        WidgetDataStore.saveTasks(widgetData)

        // Update Live Activity if active
        _Concurrency.Task { @MainActor in
            await LiveActivityManager.shared.updateFromTasks(tasks)
        }
    }

    /// Fetch tasks due today
    func fetchTodayTasks() -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfDay && dueDate < endOfDay && !task.isArchived
        }
    }

    /// Fetch overdue tasks
    func fetchOverdueTasks() -> [Task] {
        let startOfToday = Calendar.current.startOfDay(for: Date())

        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < startOfToday && !task.isCompleted && !task.isArchived
        }
    }

    /// Fetch upcoming tasks (next 7 days, excluding today)
    func fetchUpcomingTasks() -> [Task] {
        let calendar = Calendar.current
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfTomorrow) else {
            return []
        }

        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfTomorrow && dueDate < endOfWeek && !task.isArchived
        }
    }

    /// Fetch tasks for a specific list
    func fetchTasks(forListID listID: UUID) -> [Task] {
        return tasks.filter { $0.listID == listID && !$0.isArchived }
    }

    /// Fetch completed tasks
    func fetchCompletedTasks() -> [Task] {
        return tasks.filter { $0.isCompleted && !$0.isArchived }
    }

    /// Fetch tasks completed on a specific date (using completedAt field)
    func fetchTasksCompletedOn(date: Date) -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startOfDay && completedAt < endOfDay
        }
    }

    /// Fetch tasks that were due on a specific date (planned for that day)
    func fetchTasksDueOn(date: Date) -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfDay && dueDate < endOfDay && !task.isArchived
        }
    }

    /// Fetch tasks without a due date
    func fetchTasksWithoutDueDate() -> [Task] {
        return tasks.filter { $0.dueDate == nil && !$0.isCompleted && !$0.isArchived }
    }

    /// Search tasks by title or notes
    func searchTasks(query: String) -> [Task] {
        guard !query.isEmpty else { return tasks }

        let lowercasedQuery = query.lowercased()
        return tasks.filter { task in
            task.title.lowercased().contains(lowercasedQuery) ||
            (task.notes?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    // MARK: - Create Operations

    /// Create a new task
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
        linkedEventID: String? = nil
    ) -> Task {
        let context = persistenceController.viewContext

        let entity = TaskEntity(context: context)
        entity.id = UUID()
        entity.title = title
        entity.notes = notes
        entity.dueDate = dueDate
        entity.dueTime = dueTime
        entity.reminderDate = reminderDate
        entity.priorityRaw = priority.rawValue
        entity.categoryRaw = category.rawValue
        entity.customCategoryID = customCategoryID
        entity.isCompleted = false
        entity.isArchived = false
        entity.estimatedDuration = estimatedDuration ?? 0
        entity.linkedEventID = linkedEventID
        entity.createdAt = Date()
        entity.updatedAt = Date()

        // Set list relationship
        if let listID = listID {
            let listRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
            listRequest.predicate = NSPredicate(format: "id == %@", listID as CVarArg)
            if let list = try? context.fetch(listRequest).first {
                entity.list = list
            }
        }

        // Create recurring rule if provided
        if let rule = recurringRule {
            let ruleEntity = RecurringRuleEntity(context: context)
            ruleEntity.update(from: rule)
            entity.recurringRule = ruleEntity
        }

        persistenceController.save()

        // Schedule notification if reminder is set
        if let reminderDate = reminderDate, let taskID = entity.id {
            notificationService.scheduleTaskReminder(
                taskID: taskID,
                title: title,
                reminderDate: reminderDate
            )
        }

        let task = entity.toDomainModel()
        fetchAllTasks()
        return task
    }

    // MARK: - Update Operations

    /// Update an existing task
    func updateTask(_ task: Task) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }

            entity.title = task.title
            entity.notes = task.notes
            entity.dueDate = task.dueDate
            entity.dueTime = task.dueTime
            entity.reminderDate = task.reminderDate
            entity.priorityRaw = task.priority.rawValue
            entity.categoryRaw = task.category.rawValue
            entity.customCategoryID = task.customCategoryID
            entity.statusRaw = task.status.rawValue
            entity.isCompleted = task.isCompleted
            entity.isArchived = task.isArchived
            entity.completedAt = task.completedAt
            entity.startedAt = task.startedAt
            entity.accumulatedDuration = task.accumulatedDuration
            entity.estimatedDuration = task.estimatedDuration ?? 0
            entity.linkedEventID = task.linkedEventID
            entity.updatedAt = Date()
            entity.parentTaskID = task.parentTaskID
            entity.subtaskOrder = task.subtaskOrder
            entity.intradayCompletionsToday = Int16(task.intradayCompletionsToday)
            entity.lastIntradayCompletionDate = task.lastIntradayCompletionDate

            // Update list relationship
            let oldListID = entity.list?.id
            if let listID = task.listID {
                let listRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
                listRequest.predicate = NSPredicate(format: "id == %@", listID as CVarArg)
                entity.list = try? context.fetch(listRequest).first
            } else {
                entity.list = nil
            }

            // If list changed and this is a parent task, update subtasks to same list
            let listChanged = oldListID != task.listID
            if listChanged && entity.parentTaskID == nil {
                updateSubtasksListID(parentID: task.id, newListID: task.listID, context: context)
            }

            // Update recurring rule
            if let rule = task.recurringRule {
                if let existingRule = entity.recurringRule {
                    existingRule.update(from: rule)
                } else {
                    let ruleEntity = RecurringRuleEntity(context: context)
                    ruleEntity.update(from: rule)
                    entity.recurringRule = ruleEntity
                }
            } else {
                if let existingRule = entity.recurringRule {
                    context.delete(existingRule)
                }
                entity.recurringRule = nil
            }

            persistenceController.save()

            // Update notification
            notificationService.cancelTaskReminder(taskID: task.id)
            if let reminderDate = task.reminderDate, !task.isCompleted {
                notificationService.scheduleTaskReminder(
                    taskID: task.id,
                    title: task.title,
                    reminderDate: reminderDate
                )
            }

            // Sync to calendar if linked
            syncTaskToCalendar(task)

            fetchAllTasks()
        } catch {
            self.error = error
            print("Failed to update task: \(error)")
        }
    }

    /// Sync task changes to linked calendar event
    private func syncTaskToCalendar(_ task: Task) {
        guard task.linkedEventID != nil else { return }

        do {
            try calendarService.syncTaskToEvent(task)
        } catch {
            print("Failed to sync task to calendar: \(error)")
        }
    }

    /// Toggle task completion status
    func toggleTaskCompletion(_ task: Task) {
        // For intraday tasks that aren't yet complete for today, increment completion instead
        if task.isIntradayTask && !task.isCompleted && !task.isIntradayCompleteForToday {
            incrementIntradayCompletion(task)
            return
        }

        var updatedTask = task
        if task.isCompleted {
            updatedTask = task.uncompleted()
        } else {
            updatedTask = task.completed()

            // Handle recurring task completion
            if let rule = task.recurringRule, let dueDate = task.dueDate {
                if let nextDate = rule.nextOccurrence(from: dueDate) {
                    // Create next occurrence
                    createTask(
                        title: task.title,
                        notes: task.notes,
                        dueDate: nextDate,
                        dueTime: task.dueTime,
                        reminderDate: task.reminderDate != nil ? nextDate : nil,
                        priority: task.priority,
                        listID: task.listID,
                        estimatedDuration: task.estimatedDuration,
                        recurringRule: task.recurringRule
                    )
                }
            }
        }
        updateTask(updatedTask)
    }

    /// Increment intraday completion count for a recurring intraday task
    /// This is used when user taps to mark one instance of an intraday task (e.g., "Drink water every 2 hours")
    func incrementIntradayCompletion(_ task: Task) {
        guard task.isIntradayTask else { return }

        var updatedTask = task.incrementIntradayCompletion()

        // Check if all completions for today are done
        if updatedTask.isIntradayCompleteForToday {
            // Mark the task as completed for today
            updatedTask.status = .completed
            updatedTask.completedAt = Date()
        }

        updateTask(updatedTask)
    }

    /// Reset intraday completions for a task (called at the start of a new day)
    func resetIntradayCompletions(_ task: Task) {
        guard task.isIntradayTask else { return }

        var updatedTask = task.resetIntradayCompletions()

        // If task was completed yesterday, reset it to pending for today
        if updatedTask.status == .completed {
            updatedTask.status = .pending
            updatedTask.completedAt = nil
        }

        updateTask(updatedTask)
    }

    /// Reset all intraday task completions (called at the start of a new day)
    func resetAllIntradayCompletions() {
        let intradayTasks = tasks.filter { $0.isIntradayTask }
        for task in intradayTasks {
            resetIntradayCompletions(task)
        }
    }

    /// Move task to a different list
    func moveTask(_ task: Task, toListID listID: UUID?) {
        var updatedTask = task
        updatedTask = task.updated(listID: listID)
        updateTask(updatedTask)
    }

    // MARK: - In Progress Management

    /// Get the currently in-progress task (only one allowed at a time)
    func getInProgressTask() -> Task? {
        return tasks.first { $0.isInProgress }
    }

    /// Start working on a task (stops any other in-progress task)
    func startWorking(on task: Task) {
        // First, stop any currently in-progress task
        if let currentInProgress = getInProgressTask(), currentInProgress.id != task.id {
            let stopped = currentInProgress.stopProgress()
            updateTask(stopped)
        }

        // Then start working on the new task
        let inProgressTask = task.inProgress()
        updateTask(inProgressTask)
    }

    /// Stop working on a task
    func stopWorking(on task: Task) {
        let stoppedTask = task.stopProgress()
        updateTask(stoppedTask)
    }

    // MARK: - Calendar Integration

    /// Link a task to a calendar event
    func linkTaskToEvent(_ task: Task, eventID: String) {
        var updatedTask = task
        updatedTask.linkedEventID = eventID
        updateTask(updatedTask)
    }

    /// Unlink a task from its calendar event
    func unlinkTaskFromEvent(_ task: Task) {
        var updatedTask = task
        updatedTask.linkedEventID = nil
        updateTask(updatedTask)
    }

    /// Create a calendar event from a task
    func createCalendarEvent(for task: Task, startDate: Date, duration: TimeInterval) {
        do {
            let event = try calendarService.createTimeBlock(for: task, startDate: startDate, duration: duration)
            linkTaskToEvent(task, eventID: event.eventIdentifier)
        } catch {
            print("Failed to create calendar event: \(error)")
        }
    }

    // MARK: - Delete Operations (Soft Delete Pattern)

    /// ID of task pending deletion (for undo support)
    private(set) var pendingDeleteTaskID: UUID?

    /// Delete a task using soft delete pattern
    /// - Parameters:
    ///   - task: The task to delete
    ///   - deleteLinkedEvent: Whether to delete the linked calendar event
    ///   - allowUndo: If true, uses soft delete to allow undo. Call `commitPendingDelete()` after undo window closes.
    func deleteTask(_ task: Task, deleteLinkedEvent: Bool = false, allowUndo: Bool = false) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }

            // Store parent ID (for subtask status update)
            let parentTaskID = entity.parentTaskID

            if allowUndo {
                // Soft delete: mark as deleted but keep in database
                entity.isSoftDeleted = true
                entity.deletedAt = Date()
                pendingDeleteTaskID = task.id

                // Also soft-delete subtasks if this is a parent task
                if let subtasks = entity.subtasks as? Set<TaskEntity> {
                    for subtask in subtasks {
                        subtask.isSoftDeleted = true
                        subtask.deletedAt = Date()
                    }
                }
            } else {
                // Hard delete: remove from database immediately
                context.delete(entity)
            }

            persistenceController.save()

            // Cancel any scheduled notifications
            notificationService.cancelTaskReminder(taskID: task.id)

            // Delete linked calendar event if requested
            if deleteLinkedEvent {
                deleteLinkedCalendarEvent(for: task)
            }

            // Update parent status if this was a subtask
            if let parentID = parentTaskID {
                updateParentStatusAfterSubtaskChange(parentID: parentID)
            }

            fetchAllTasks()
        } catch {
            self.error = error
            print("Failed to delete task: \(error)")
        }
    }

    /// Commit pending delete (call after undo window closes without undo)
    /// This performs the actual hard delete of soft-deleted tasks
    func commitPendingChanges() {
        guard let taskID = pendingDeleteTaskID else { return }

        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                // Hard delete the soft-deleted task and its subtasks
                context.delete(entity)
                persistenceController.save()
            }
        } catch {
            print("Failed to commit pending delete: \(error)")
        }

        pendingDeleteTaskID = nil
    }

    /// Undo pending delete (call when user taps undo)
    /// This restores soft-deleted tasks by clearing the soft delete flags
    func discardPendingChanges() {
        guard let taskID = pendingDeleteTaskID else { return }

        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                // Restore the soft-deleted task
                entity.isSoftDeleted = false
                entity.deletedAt = nil

                // Also restore subtasks
                if let subtasks = entity.subtasks as? Set<TaskEntity> {
                    for subtask in subtasks {
                        subtask.isSoftDeleted = false
                        subtask.deletedAt = nil
                    }
                }

                persistenceController.save()
                fetchAllTasks()
            }
        } catch {
            print("Failed to undo delete: \(error)")
        }

        pendingDeleteTaskID = nil
    }

    /// Delete linked calendar event for a task
    private func deleteLinkedCalendarEvent(for task: Task) {
        guard task.linkedEventID != nil else { return }

        do {
            try calendarService.deleteLinkedEvent(for: task)
        } catch {
            print("Failed to delete linked calendar event: \(error)")
        }
    }

    /// Archive a task
    func archiveTask(_ task: Task) {
        var updatedTask = task
        updatedTask.isArchived = true
        updatedTask.updatedAt = Date()
        updateTask(updatedTask)
    }

    /// Delete all completed tasks
    func deleteCompletedTasks() {
        let completedTasks = fetchCompletedTasks()
        for task in completedTasks {
            deleteTask(task)
        }
    }

    // MARK: - Subtask Operations

    /// Create a subtask linked to a parent task
    @discardableResult
    func createSubtask(
        title: String,
        parentTaskID: UUID,
        notes: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        priority: Priority? = nil
    ) -> Task? {
        let context = persistenceController.viewContext

        // Find the parent task entity
        let parentRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        parentRequest.predicate = NSPredicate(format: "id == %@", parentTaskID as CVarArg)

        guard let parentEntity = try? context.fetch(parentRequest).first else {
            print("Failed to find parent task: \(parentTaskID)")
            return nil
        }

        // If parent is completed, adding a new subtask should uncomplete it
        if parentEntity.isCompleted {
            parentEntity.isCompleted = false
            parentEntity.statusRaw = TaskStatus.inProgress.rawValue  // Has some completed subtasks
            parentEntity.completedAt = nil
            parentEntity.updatedAt = Date()
        } else if parentEntity.statusRaw == TaskStatus.pending.rawValue {
            // Check if there are any existing completed subtasks
            let existingSubtasks = parentEntity.subtasks as? Set<TaskEntity> ?? []
            if existingSubtasks.contains(where: { $0.isCompleted }) {
                parentEntity.statusRaw = TaskStatus.inProgress.rawValue
                parentEntity.updatedAt = Date()
            }
        }

        // Calculate next subtask order
        let existingSubtaskCount = (parentEntity.subtasks as? Set<TaskEntity>)?.count ?? 0

        let entity = TaskEntity(context: context)
        entity.id = UUID()
        entity.title = title
        entity.notes = notes
        entity.dueDate = dueDate ?? parentEntity.dueDate
        entity.dueTime = dueTime ?? parentEntity.dueTime
        entity.priorityRaw = priority?.rawValue ?? parentEntity.priorityRaw
        entity.categoryRaw = parentEntity.categoryRaw
        entity.customCategoryID = parentEntity.customCategoryID  // Inherit custom category from parent
        entity.isCompleted = false
        entity.statusRaw = TaskStatus.pending.rawValue
        entity.isArchived = false
        entity.estimatedDuration = 0
        entity.createdAt = Date()
        entity.updatedAt = Date()
        entity.parentTask = parentEntity
        entity.parentTaskID = parentTaskID
        entity.subtaskOrder = Int32(existingSubtaskCount)
        entity.list = parentEntity.list

        persistenceController.save()
        fetchAllTasks()

        return entity.toDomainModel()
    }

    /// Create multiple subtasks at once (for AI suggestions)
    @discardableResult
    func createSubtasks(titles: [String], parentTaskID: UUID) -> [Task] {
        var createdSubtasks: [Task] = []
        for title in titles {
            if let subtask = createSubtask(title: title, parentTaskID: parentTaskID) {
                createdSubtasks.append(subtask)
            }
        }
        return createdSubtasks
    }

    /// Fetch subtasks for a parent task (excludes soft-deleted)
    func fetchSubtasks(forParentID parentID: UUID) -> [Task] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "parentTaskID == %@ AND isSoftDeleted == NO", parentID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.subtaskOrder, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: true)
        ]

        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomainModel() }
        } catch {
            print("Failed to fetch subtasks: \(error)")
            return []
        }
    }

    /// Update all subtasks to inherit parent's list assignment
    private func updateSubtasksListID(parentID: UUID, newListID: UUID?, context: NSManagedObjectContext) {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "parentTaskID == %@ AND isSoftDeleted == NO", parentID as CVarArg)

        do {
            let subtaskEntities = try context.fetch(request)

            // Get the new list entity if there's a listID
            var newListEntity: TaskListEntity?
            if let listID = newListID {
                let listRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
                listRequest.predicate = NSPredicate(format: "id == %@", listID as CVarArg)
                newListEntity = try? context.fetch(listRequest).first
            }

            // Update each subtask's list
            for subtaskEntity in subtaskEntities {
                subtaskEntity.list = newListEntity
                subtaskEntity.updatedAt = Date()
            }
        } catch {
            print("Failed to update subtasks list: \(error)")
        }
    }

    /// Promote a subtask to a standalone task
    func promoteSubtaskToTask(_ subtask: Task) {
        guard subtask.isSubtask, let parentID = subtask.parentTaskID else { return }

        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", subtask.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }
            entity.parentTask = nil
            entity.parentTaskID = nil
            entity.subtaskOrder = 0
            entity.updatedAt = Date()

            persistenceController.save()

            // Update parent status after removing this subtask
            updateParentStatusAfterSubtaskChange(parentID: parentID)

            fetchAllTasks()
        } catch {
            self.error = error
            print("Failed to promote subtask: \(error)")
        }
    }

    /// Check if parent task should be auto-completed when a subtask is completed
    /// Returns true if parent was auto-completed
    @discardableResult
    func checkAutoCompleteParent(subtaskID: UUID) -> Bool {
        let context = persistenceController.viewContext

        // Find the subtask
        let subtaskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        subtaskRequest.predicate = NSPredicate(format: "id == %@", subtaskID as CVarArg)

        guard let subtaskEntity = try? context.fetch(subtaskRequest).first,
              let parentEntity = subtaskEntity.parentTask,
              let parentID = parentEntity.id else {
            return false
        }

        // Check if all non-deleted subtasks are completed
        let activeSubtasks = (parentEntity.subtasks as? Set<TaskEntity>)?.filter { !$0.isSoftDeleted } ?? []
        let allSubtasksCompleted = !activeSubtasks.isEmpty && activeSubtasks.allSatisfy { $0.isCompleted }

        if allSubtasksCompleted && !parentEntity.isCompleted {
            parentEntity.isCompleted = true
            parentEntity.statusRaw = TaskStatus.completed.rawValue
            parentEntity.completedAt = Date()
            parentEntity.updatedAt = Date()

            persistenceController.save()
            fetchAllTasks()

            // Post notification for UI to show celebration
            NotificationCenter.default.post(
                name: .parentTaskAutoCompleted,
                object: nil,
                userInfo: ["parentTaskID": parentID, "parentTitle": parentEntity.title ?? ""]
            )

            return true
        }

        return false
    }

    /// Toggle subtask completion with auto-complete check
    func toggleSubtaskCompletion(_ subtask: Task) {
        var updatedTask = subtask
        if subtask.isCompleted {
            updatedTask = subtask.uncompleted()
        } else {
            updatedTask = subtask.completed()
        }
        updateTask(updatedTask)

        // Check for auto-completion of parent when subtask is completed
        if updatedTask.isCompleted {
            // First try auto-complete (all subtasks done)
            if !checkAutoCompleteParent(subtaskID: subtask.id) {
                // If not auto-completed, at least mark parent as in-progress
                markParentInProgressIfNeeded(subtaskID: subtask.id)
            }
        } else {
            // If subtask is uncompleted, ensure parent is also uncompleted
            uncompleteParentIfNeeded(subtaskID: subtask.id)
        }
    }

    /// Mark parent task as in-progress when a subtask is completed (but not all)
    private func markParentInProgressIfNeeded(subtaskID: UUID) {
        let context = persistenceController.viewContext

        // Find the subtask to get its parentTaskID
        let subtaskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        subtaskRequest.predicate = NSPredicate(format: "id == %@", subtaskID as CVarArg)

        guard let subtaskEntity = try? context.fetch(subtaskRequest).first,
              let parentTaskID = subtaskEntity.parentTaskID else {
            return
        }

        // Find the parent task
        let parentRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        parentRequest.predicate = NSPredicate(format: "id == %@", parentTaskID as CVarArg)

        guard let parentEntity = try? context.fetch(parentRequest).first,
              parentEntity.statusRaw == TaskStatus.pending.rawValue else {
            return
        }

        // Parent is pending but now has a completed subtask - mark as in progress
        parentEntity.statusRaw = TaskStatus.inProgress.rawValue
        parentEntity.updatedAt = Date()

        persistenceController.save()
        fetchAllTasks()
    }

    /// Update parent status after a subtask is deleted or promoted
    private func updateParentStatusAfterSubtaskChange(parentID: UUID) {
        let context = persistenceController.viewContext

        let parentRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        parentRequest.predicate = NSPredicate(format: "id == %@", parentID as CVarArg)

        guard let parentEntity = try? context.fetch(parentRequest).first else {
            return
        }

        // Get remaining active subtasks (exclude soft-deleted)
        let allSubtasks = parentEntity.subtasks as? Set<TaskEntity> ?? []
        let subtaskEntities = allSubtasks.filter { !$0.isSoftDeleted }

        // If no active subtasks remain, set to pending (or keep current if no subtasks to track)
        if subtaskEntities.isEmpty {
            // No subtasks - parent status based on its own completion
            // Keep as-is since the parent might have been manually completed
            return
        }

        // Check completion status of remaining active subtasks
        let completedCount = subtaskEntities.filter { $0.isCompleted }.count
        let totalCount = subtaskEntities.count

        let newStatus: TaskStatus
        if completedCount == totalCount {
            newStatus = .completed
        } else if completedCount > 0 {
            newStatus = .inProgress
        } else {
            newStatus = .pending
        }

        let currentStatus = TaskStatus(rawValue: parentEntity.statusRaw) ?? .pending
        if currentStatus != newStatus {
            parentEntity.statusRaw = newStatus.rawValue
            parentEntity.isCompleted = (newStatus == .completed)
            if newStatus == .completed {
                parentEntity.completedAt = Date()
            } else {
                parentEntity.completedAt = nil
            }
            parentEntity.updatedAt = Date()
            persistenceController.save()
        }
    }

    /// Update parent task status when a subtask is uncompleted
    private func uncompleteParentIfNeeded(subtaskID: UUID) {
        let context = persistenceController.viewContext

        // Find the subtask to get its parentTaskID
        let subtaskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        subtaskRequest.predicate = NSPredicate(format: "id == %@", subtaskID as CVarArg)

        guard let subtaskEntity = try? context.fetch(subtaskRequest).first,
              let parentTaskID = subtaskEntity.parentTaskID else {
            return
        }

        // Find the parent task
        let parentRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        parentRequest.predicate = NSPredicate(format: "id == %@", parentTaskID as CVarArg)

        guard let parentEntity = try? context.fetch(parentRequest).first else {
            return
        }

        // Check how many active subtasks are still completed (exclude soft-deleted)
        let allSubtasks = parentEntity.subtasks as? Set<TaskEntity> ?? []
        let subtaskEntities = allSubtasks.filter { !$0.isSoftDeleted }
        let completedCount = subtaskEntities.filter { $0.isCompleted }.count

        // Determine new status based on completed subtask count
        let newStatus: TaskStatus
        if completedCount == subtaskEntities.count && completedCount > 0 {
            // All completed - shouldn't happen here, but handle it
            newStatus = .completed
        } else if completedCount > 0 {
            // Some completed - in progress
            newStatus = .inProgress
        } else {
            // None completed - pending
            newStatus = .pending
        }

        // Only update if status changed
        let currentStatus = TaskStatus(rawValue: parentEntity.statusRaw) ?? .pending
        if currentStatus != newStatus {
            parentEntity.statusRaw = newStatus.rawValue
            parentEntity.isCompleted = (newStatus == .completed)
            if newStatus != .completed {
                parentEntity.completedAt = nil
            }
            parentEntity.updatedAt = Date()

            persistenceController.save()
            fetchAllTasks()
        }
    }

    /// Reorder subtasks
    func reorderSubtasks(_ subtasks: [Task], parentID: UUID) {
        let context = persistenceController.viewContext

        for (index, subtask) in subtasks.enumerated() {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", subtask.id as CVarArg)

            if let entity = try? context.fetch(request).first {
                entity.subtaskOrder = Int32(index)
                entity.updatedAt = Date()
            }
        }

        persistenceController.save()
        fetchAllTasks()
    }

    // MARK: - Undo Support

    /// Check if there are actions that can be undone
    var canUndo: Bool {
        persistenceController.canUndo
    }

    /// Check if there are actions that can be redone
    var canRedo: Bool {
        persistenceController.canRedo
    }

    /// Undo the last action and refresh tasks
    /// This uses Core Data's built-in UndoManager which automatically
    /// handles relationships (subtasks are restored with their parent)
    func undo() {
        persistenceController.undo()
        fetchAllTasks()
    }

    /// Redo the last undone action and refresh tasks
    func redo() {
        persistenceController.redo()
        fetchAllTasks()
    }

    /// Begin an undo grouping for multiple operations
    /// Use this when you want multiple changes to be undone as a single action
    func beginUndoGrouping(named name: String? = nil) {
        persistenceController.beginUndoGrouping(named: name)
    }

    /// End an undo grouping
    func endUndoGrouping() {
        persistenceController.endUndoGrouping()
    }

    /// Remove all undo actions (clear the undo stack)
    func removeAllUndoActions() {
        persistenceController.removeAllUndoActions()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let parentTaskAutoCompleted = Notification.Name("parentTaskAutoCompleted")
}

// MARK: - TaskEntity to Domain Model

extension TaskEntity {
    func toDomainModel(includeSubtasks: Bool = true) -> Task {
        let recurringRule = self.recurringRule?.toRecurringRule()

        // Handle status with backward compatibility for legacy isCompleted field
        let status: TaskStatus
        if let rawStatus = TaskStatus(rawValue: statusRaw), rawStatus != .pending {
            // Use statusRaw if it's explicitly set to non-pending
            status = rawStatus
        } else if isCompleted {
            // Legacy migration: if isCompleted is true but statusRaw is pending, use completed
            status = .completed
        } else {
            status = TaskStatus(rawValue: statusRaw) ?? .pending
        }

        // Convert subtasks (avoiding infinite recursion by not including nested subtasks)
        // Filter out soft-deleted subtasks
        var subtaskModels: [Task] = []
        if includeSubtasks, let subtaskEntities = subtasks as? Set<TaskEntity> {
            subtaskModels = subtaskEntities
                .filter { !$0.isSoftDeleted }
                .sorted { ($0.subtaskOrder, $0.createdAt ?? Date()) < ($1.subtaskOrder, $1.createdAt ?? Date()) }
                .map { $0.toDomainModel(includeSubtasks: false) }
        }

        return Task(
            id: id ?? UUID(),
            title: title ?? "",
            notes: notes,
            dueDate: dueDate,
            dueTime: dueTime,
            reminderDate: reminderDate,
            status: status,
            isArchived: isArchived,
            priority: Priority(rawValue: priorityRaw) ?? .none,
            category: TaskCategory(rawValue: categoryRaw) ?? .uncategorized,
            customCategoryID: customCategoryID,
            listID: list?.id,
            linkedEventID: linkedEventID,
            estimatedDuration: estimatedDuration > 0 ? estimatedDuration : nil,
            completedAt: completedAt,
            startedAt: startedAt,
            accumulatedDuration: accumulatedDuration,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            recurringRule: recurringRule,
            intradayCompletionsToday: Int(intradayCompletionsToday),
            lastIntradayCompletionDate: lastIntradayCompletionDate,
            parentTaskID: parentTaskID,
            subtasks: subtaskModels,
            subtaskOrder: subtaskOrder
        )
    }
}
