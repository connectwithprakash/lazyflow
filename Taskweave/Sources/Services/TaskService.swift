import CoreData
import Foundation
import Combine

/// Service responsible for all Task-related CRUD operations
final class TaskService: ObservableObject {
    private let persistenceController: PersistenceController
    private let notificationService: NotificationService

    @Published private(set) var tasks: [Task] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private var cancellables = Set<AnyCancellable>()

    init(
        persistenceController: PersistenceController = .shared,
        notificationService: NotificationService = .shared
    ) {
        self.persistenceController = persistenceController
        self.notificationService = notificationService
        setupObservers()
        fetchAllTasks()
    }

    // MARK: - Setup

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllTasks()
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Operations

    /// Fetch all non-archived tasks
    func fetchAllTasks() {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.priorityRaw, ascending: false),
            NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)
        ]

        do {
            let entities = try context.fetch(request)
            tasks = entities.map { $0.toDomainModel() }
        } catch {
            self.error = error
            print("Failed to fetch tasks: \(error)")
        }
    }

    /// Fetch tasks due today
    func fetchTodayTasks() -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

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
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfTomorrow)!

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
        listID: UUID? = nil,
        estimatedDuration: TimeInterval? = nil,
        recurringRule: RecurringRule? = nil
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
        entity.isCompleted = false
        entity.isArchived = false
        entity.estimatedDuration = estimatedDuration ?? 0
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
            ruleEntity.id = rule.id
            ruleEntity.frequencyRaw = rule.frequency.rawValue
            ruleEntity.interval = Int16(rule.interval)
            ruleEntity.daysOfWeek = rule.daysOfWeek
            ruleEntity.endDate = rule.endDate
            entity.recurringRule = ruleEntity
        }

        persistenceController.save()

        // Schedule notification if reminder is set
        if let reminderDate = reminderDate {
            notificationService.scheduleTaskReminder(
                taskID: entity.id!,
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
            entity.isCompleted = task.isCompleted
            entity.isArchived = task.isArchived
            entity.completedAt = task.completedAt
            entity.estimatedDuration = task.estimatedDuration ?? 0
            entity.linkedEventID = task.linkedEventID
            entity.updatedAt = Date()

            // Update list relationship
            if let listID = task.listID {
                let listRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
                listRequest.predicate = NSPredicate(format: "id == %@", listID as CVarArg)
                entity.list = try? context.fetch(listRequest).first
            } else {
                entity.list = nil
            }

            // Update recurring rule
            if let rule = task.recurringRule {
                if let existingRule = entity.recurringRule {
                    existingRule.frequencyRaw = rule.frequency.rawValue
                    existingRule.interval = Int16(rule.interval)
                    existingRule.daysOfWeek = rule.daysOfWeek
                    existingRule.endDate = rule.endDate
                } else {
                    let ruleEntity = RecurringRuleEntity(context: context)
                    ruleEntity.id = rule.id
                    ruleEntity.frequencyRaw = rule.frequency.rawValue
                    ruleEntity.interval = Int16(rule.interval)
                    ruleEntity.daysOfWeek = rule.daysOfWeek
                    ruleEntity.endDate = rule.endDate
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

            fetchAllTasks()
        } catch {
            self.error = error
            print("Failed to update task: \(error)")
        }
    }

    /// Toggle task completion status
    func toggleTaskCompletion(_ task: Task) {
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

    /// Move task to a different list
    func moveTask(_ task: Task, toListID listID: UUID?) {
        var updatedTask = task
        updatedTask = task.updated(listID: listID)
        updateTask(updatedTask)
    }

    // MARK: - Delete Operations

    /// Delete a task
    func deleteTask(_ task: Task) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }
            context.delete(entity)
            persistenceController.save()

            // Cancel any scheduled notifications
            notificationService.cancelTaskReminder(taskID: task.id)

            fetchAllTasks()
        } catch {
            self.error = error
            print("Failed to delete task: \(error)")
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
}

// MARK: - TaskEntity to Domain Model

extension TaskEntity {
    func toDomainModel() -> Task {
        var recurringRule: RecurringRule?
        if let ruleEntity = self.recurringRule {
            recurringRule = RecurringRule(
                id: ruleEntity.id ?? UUID(),
                frequency: RecurringFrequency(rawValue: ruleEntity.frequencyRaw) ?? .daily,
                interval: Int(ruleEntity.interval),
                daysOfWeek: ruleEntity.daysOfWeek,
                endDate: ruleEntity.endDate
            )
        }

        return Task(
            id: id ?? UUID(),
            title: title ?? "",
            notes: notes,
            dueDate: dueDate,
            dueTime: dueTime,
            reminderDate: reminderDate,
            isCompleted: isCompleted,
            isArchived: isArchived,
            priority: Priority(rawValue: priorityRaw) ?? .none,
            listID: list?.id,
            linkedEventID: linkedEventID,
            estimatedDuration: estimatedDuration > 0 ? estimatedDuration : nil,
            completedAt: completedAt,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            recurringRule: recurringRule
        )
    }
}
