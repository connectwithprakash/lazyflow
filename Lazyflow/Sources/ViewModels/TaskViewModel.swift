import Foundation
import Combine

/// ViewModel for task detail and editing
@MainActor
final class TaskViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var dueDate: Date?
    @Published var hasDueDate: Bool = false
    @Published var dueTime: Date?
    @Published var hasDueTime: Bool = false
    @Published var reminderDate: Date?
    @Published var hasReminder: Bool = false
    @Published var priority: Priority = .none
    @Published var category: TaskCategory = .uncategorized
    @Published var customCategoryID: UUID?  // When set, takes precedence over system category
    @Published var selectedListID: UUID?
    @Published var estimatedDuration: TimeInterval?
    @Published var isRecurring: Bool = false
    @Published var recurringFrequency: RecurringFrequency = .daily
    @Published var recurringInterval: Int = 1
    @Published var recurringDaysOfWeek: [Int] = []
    @Published var recurringEndDate: Date?

    // Intraday recurring properties
    @Published var hourInterval: Int = 2
    @Published var timesPerDay: Int = 3
    @Published var specificTimes: [Date] = []
    @Published var useSpecificTimes: Bool = false
    @Published var activeHoursStart: Date = TaskViewModel.defaultActiveHoursStart
    @Published var activeHoursEnd: Date = TaskViewModel.defaultActiveHoursEnd

    @Published var isValid: Bool = false
    @Published var isSaving: Bool = false

    private let taskService: TaskService
    private var existingTask: Task?
    private var cancellables = Set<AnyCancellable>()

    init(taskService: TaskService = TaskService(), task: Task? = nil) {
        self.taskService = taskService
        self.existingTask = task

        if let task = task {
            loadTask(task)
        }

        setupValidation()
    }

    private func loadTask(_ task: Task) {
        title = task.title
        notes = task.notes ?? ""
        dueDate = task.dueDate
        hasDueDate = task.dueDate != nil
        dueTime = task.dueTime
        hasDueTime = task.dueTime != nil
        reminderDate = task.reminderDate
        hasReminder = task.reminderDate != nil
        priority = task.priority
        category = task.category
        customCategoryID = task.customCategoryID
        selectedListID = task.listID
        estimatedDuration = task.estimatedDuration

        if let rule = task.recurringRule {
            isRecurring = true
            recurringFrequency = rule.frequency
            recurringInterval = rule.interval
            recurringDaysOfWeek = rule.daysOfWeek ?? []
            recurringEndDate = rule.endDate

            // Load intraday fields
            hourInterval = rule.hourInterval ?? 2
            timesPerDay = rule.timesPerDay ?? 3
            specificTimes = rule.specificTimes ?? []
            useSpecificTimes = rule.specificTimes != nil && !rule.specificTimes!.isEmpty
            activeHoursStart = rule.activeHoursStart ?? TaskViewModel.defaultActiveHoursStart
            activeHoursEnd = rule.activeHoursEnd ?? TaskViewModel.defaultActiveHoursEnd
        }
    }

    private func setupValidation() {
        $title
            .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .assign(to: &$isValid)
    }

    // MARK: - Actions

    func save() -> Task? {
        guard isValid else { return nil }
        isSaving = true
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        var recurringRule: RecurringRule?
        if isRecurring {
            // Determine intraday fields based on frequency
            let isIntraday = recurringFrequency == .hourly || recurringFrequency == .timesPerDay
            let ruleHourInterval = recurringFrequency == .hourly ? hourInterval : nil
            let ruleTimesPerDay = recurringFrequency == .timesPerDay ? timesPerDay : nil
            let ruleSpecificTimes = (recurringFrequency == .timesPerDay && useSpecificTimes) ? specificTimes : nil
            let ruleActiveStart = isIntraday ? activeHoursStart : nil
            let ruleActiveEnd = isIntraday ? activeHoursEnd : nil

            recurringRule = RecurringRule(
                frequency: recurringFrequency,
                interval: recurringInterval,
                daysOfWeek: recurringDaysOfWeek.isEmpty ? nil : recurringDaysOfWeek,
                endDate: recurringEndDate,
                hourInterval: ruleHourInterval,
                timesPerDay: ruleTimesPerDay,
                specificTimes: ruleSpecificTimes,
                activeHoursStart: ruleActiveStart,
                activeHoursEnd: ruleActiveEnd
            )
        }

        if var existing = existingTask {
            existing = existing.updated(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                dueDate: hasDueDate ? dueDate : nil,
                dueTime: hasDueTime ? dueTime : nil,
                reminderDate: hasReminder ? reminderDate : nil,
                priority: priority,
                category: category,
                customCategoryID: customCategoryID,
                listID: selectedListID,
                estimatedDuration: estimatedDuration,
                recurringRule: recurringRule
            )
            taskService.updateTask(existing)
            return existing
        } else {
            return taskService.createTask(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                dueDate: hasDueDate ? dueDate : nil,
                dueTime: hasDueTime ? dueTime : nil,
                reminderDate: hasReminder ? reminderDate : nil,
                priority: priority,
                category: category,
                customCategoryID: customCategoryID,
                listID: selectedListID,
                estimatedDuration: estimatedDuration,
                recurringRule: recurringRule
            )
        }
    }

    func delete() {
        guard let task = existingTask else { return }
        taskService.deleteTask(task)
    }

    var isEditing: Bool {
        existingTask != nil
    }

    /// Whether the existing task has subtasks (used to prevent intraday recurring on tasks with subtasks)
    var hasSubtasks: Bool {
        existingTask?.hasSubtasks ?? false
    }

    /// Frequencies available for this task (excludes intraday if task has subtasks)
    var availableFrequencies: [RecurringFrequency] {
        if hasSubtasks {
            return RecurringFrequency.allCases.filter { $0 != .hourly && $0 != .timesPerDay }
        }
        return Array(RecurringFrequency.allCases)
    }

    // MARK: - Quick Actions

    func setDueToday() {
        hasDueDate = true
        dueDate = Date()
    }

    func setDueTomorrow() {
        hasDueDate = true
        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
    }

    func setDueNextWeek() {
        hasDueDate = true
        dueDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
    }

    func clearDueDate() {
        hasDueDate = false
        dueDate = nil
        hasDueTime = false
        dueTime = nil
    }

    // MARK: - Category Selection

    /// Select a system category (clears custom category)
    func selectSystemCategory(_ category: TaskCategory) {
        self.category = category
        self.customCategoryID = nil
    }

    /// Select a custom category
    func selectCustomCategory(_ categoryID: UUID) {
        self.category = .uncategorized  // Reset system category
        self.customCategoryID = categoryID
    }

    /// Clear category selection (back to uncategorized)
    func clearCategory() {
        self.category = .uncategorized
        self.customCategoryID = nil
    }

    /// Whether any category (system or custom) is selected
    var hasCategorySelected: Bool {
        category != .uncategorized || customCategoryID != nil
    }
}

// MARK: - Defaults and Presets

extension TaskViewModel {
    /// Default active hours start (8:00 AM)
    static var defaultActiveHoursStart: Date {
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Default active hours end (10:00 PM)
    static var defaultActiveHoursEnd: Date {
        var components = DateComponents()
        components.hour = 22
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    static let durationPresets: [(String, TimeInterval)] = [
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("45 min", 45 * 60),
        ("1 hour", 60 * 60),
        ("1.5 hours", 90 * 60),
        ("2 hours", 120 * 60),
        ("3 hours", 180 * 60),
        ("4 hours", 240 * 60)
    ]
}
