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
    @Published var selectedListID: UUID?
    @Published var estimatedDuration: TimeInterval?
    @Published var isRecurring: Bool = false
    @Published var recurringFrequency: RecurringFrequency = .daily
    @Published var recurringInterval: Int = 1
    @Published var recurringDaysOfWeek: [Int] = []
    @Published var recurringEndDate: Date?

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
        selectedListID = task.listID
        estimatedDuration = task.estimatedDuration

        if let rule = task.recurringRule {
            isRecurring = true
            recurringFrequency = rule.frequency
            recurringInterval = rule.interval
            recurringDaysOfWeek = rule.daysOfWeek ?? []
            recurringEndDate = rule.endDate
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
            recurringRule = RecurringRule(
                frequency: recurringFrequency,
                interval: recurringInterval,
                daysOfWeek: recurringDaysOfWeek.isEmpty ? nil : recurringDaysOfWeek,
                endDate: recurringEndDate
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
}

// MARK: - Duration Presets

extension TaskViewModel {
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
