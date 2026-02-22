import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// Task status representing the current state
enum TaskStatus: Int16, Codable, CaseIterable {
    case pending = 0      // Default - not started
    case inProgress = 1   // Actively working on
    case completed = 2    // Done

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
}

/// Domain model representing a task
struct Task: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var notes: String?
    var dueDate: Date?
    var dueTime: Date?
    var reminderDate: Date?
    var status: TaskStatus
    var isArchived: Bool

    /// Computed property for backward compatibility
    var isCompleted: Bool {
        get { status == .completed }
        set { status = newValue ? .completed : .pending }
    }

    /// Check if task is currently in progress
    var isInProgress: Bool {
        status == .inProgress
    }
    var priority: Priority
    var category: TaskCategory
    var customCategoryID: UUID?  // When set, takes precedence over system category
    var listID: UUID?
    var linkedEventID: String?
    var calendarItemExternalIdentifier: String?
    var lastSyncedAt: Date?
    var scheduledStartTime: Date?
    var scheduledEndTime: Date?
    var estimatedDuration: TimeInterval?
    var completedAt: Date?
    var startedAt: Date?
    var accumulatedDuration: TimeInterval  // Total time spent across all work sessions
    var createdAt: Date
    var updatedAt: Date
    var recurringRule: RecurringRule?

    // MARK: - Intraday Completion Tracking
    var intradayCompletionsToday: Int
    var lastIntradayCompletionDate: Date?

    // MARK: - Subtask Support
    var parentTaskID: UUID?
    var subtasks: [Task]
    var subtaskOrder: Int32

    /// Whether this task is a subtask (has a parent)
    var isSubtask: Bool {
        parentTaskID != nil
    }

    /// Whether this task has subtasks
    var hasSubtasks: Bool {
        !subtasks.isEmpty
    }

    /// Count of completed subtasks
    var completedSubtaskCount: Int {
        subtasks.filter { $0.isCompleted }.count
    }

    /// Progress of subtasks as a value from 0.0 to 1.0
    var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return 0 }
        return Double(completedSubtaskCount) / Double(subtasks.count)
    }

    /// Progress string for display (e.g., "2/3")
    var subtaskProgressString: String? {
        guard hasSubtasks else { return nil }
        return "\(completedSubtaskCount)/\(subtasks.count)"
    }

    /// Whether all subtasks are completed
    var allSubtasksCompleted: Bool {
        guard hasSubtasks else { return false }
        return completedSubtaskCount == subtasks.count
    }

    // MARK: - Intraday Progress

    /// Whether this is an intraday recurring task
    var isIntradayTask: Bool {
        recurringRule?.isIntraday ?? false
    }

    /// Target completions for today (based on recurring rule)
    var intradayTargetToday: Int {
        guard let rule = recurringRule, rule.isIntraday else { return 0 }

        switch rule.frequency {
        case .hourly:
            // Calculate how many times based on hour interval and active hours
            let times = rule.calculateIntradayTimes(for: Date())
            return times.count
        case .timesPerDay:
            return rule.timesPerDay ?? 3
        default:
            return 0
        }
    }

    /// Current intraday completions (auto-resets if date changed)
    var currentIntradayCompletions: Int {
        guard let lastDate = lastIntradayCompletionDate else {
            return 0
        }
        // Reset if not same day
        if !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            return 0
        }
        return intradayCompletionsToday
    }

    /// Progress string for intraday tasks (e.g., "2/3")
    var intradayProgressString: String? {
        guard isIntradayTask else { return nil }
        let target = intradayTargetToday
        guard target > 0 else { return nil }
        return "\(currentIntradayCompletions)/\(target)"
    }

    /// Progress as value from 0.0 to 1.0 for intraday tasks
    var intradayProgress: Double {
        guard isIntradayTask else { return 0 }
        let target = intradayTargetToday
        guard target > 0 else { return 0 }
        return min(1.0, Double(currentIntradayCompletions) / Double(target))
    }

    /// Whether all intraday completions are done for today
    var isIntradayCompleteForToday: Bool {
        guard isIntradayTask else { return false }
        return currentIntradayCompletions >= intradayTargetToday
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        reminderDate: Date? = nil,
        status: TaskStatus = .pending,
        isArchived: Bool = false,
        priority: Priority = .none,
        category: TaskCategory = .uncategorized,
        customCategoryID: UUID? = nil,
        listID: UUID? = nil,
        linkedEventID: String? = nil,
        calendarItemExternalIdentifier: String? = nil,
        lastSyncedAt: Date? = nil,
        scheduledStartTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        completedAt: Date? = nil,
        startedAt: Date? = nil,
        accumulatedDuration: TimeInterval = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        recurringRule: RecurringRule? = nil,
        intradayCompletionsToday: Int = 0,
        lastIntradayCompletionDate: Date? = nil,
        parentTaskID: UUID? = nil,
        subtasks: [Task] = [],
        subtaskOrder: Int32 = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.reminderDate = reminderDate
        self.status = status
        self.isArchived = isArchived
        self.priority = priority
        self.category = category
        self.customCategoryID = customCategoryID
        self.listID = listID
        self.linkedEventID = linkedEventID
        self.calendarItemExternalIdentifier = calendarItemExternalIdentifier
        self.lastSyncedAt = lastSyncedAt
        self.scheduledStartTime = scheduledStartTime
        self.scheduledEndTime = scheduledEndTime
        self.estimatedDuration = estimatedDuration
        self.completedAt = completedAt
        self.startedAt = startedAt
        self.accumulatedDuration = accumulatedDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recurringRule = recurringRule
        self.intradayCompletionsToday = intradayCompletionsToday
        self.lastIntradayCompletionDate = lastIntradayCompletionDate
        self.parentTaskID = parentTaskID
        self.subtasks = subtasks
        self.subtaskOrder = subtaskOrder
    }

    /// Convenience initializer for backward compatibility with isCompleted
    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        reminderDate: Date? = nil,
        isCompleted: Bool,
        isArchived: Bool = false,
        priority: Priority = .none,
        category: TaskCategory = .uncategorized,
        customCategoryID: UUID? = nil,
        listID: UUID? = nil,
        linkedEventID: String? = nil,
        calendarItemExternalIdentifier: String? = nil,
        lastSyncedAt: Date? = nil,
        scheduledStartTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        completedAt: Date? = nil,
        startedAt: Date? = nil,
        accumulatedDuration: TimeInterval = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        recurringRule: RecurringRule? = nil,
        intradayCompletionsToday: Int = 0,
        lastIntradayCompletionDate: Date? = nil,
        parentTaskID: UUID? = nil,
        subtasks: [Task] = [],
        subtaskOrder: Int32 = 0
    ) {
        self.init(
            id: id,
            title: title,
            notes: notes,
            dueDate: dueDate,
            dueTime: dueTime,
            reminderDate: reminderDate,
            status: isCompleted ? .completed : .pending,
            isArchived: isArchived,
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
            completedAt: completedAt,
            startedAt: startedAt,
            accumulatedDuration: accumulatedDuration,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recurringRule: recurringRule,
            intradayCompletionsToday: intradayCompletionsToday,
            lastIntradayCompletionDate: lastIntradayCompletionDate,
            parentTaskID: parentTaskID,
            subtasks: subtasks,
            subtaskOrder: subtaskOrder
        )
    }

    /// Check if task is due today
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    /// Check if task is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date() && !Calendar.current.isDateInToday(dueDate)
    }

    /// Check if task is upcoming (within next 7 days)
    var isUpcoming: Bool {
        guard let dueDate = dueDate else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        return dueDate >= today && dueDate <= weekFromNow
    }

    /// Check if task has a reminder set
    var hasReminder: Bool {
        reminderDate != nil
    }

    /// Whether this task has a scheduled time block
    var isScheduled: Bool {
        scheduledStartTime != nil
    }

    /// Whether this task is eligible for automatic calendar sync
    var isEligibleForAutoSync: Bool {
        dueDate != nil && dueTime != nil && estimatedDuration != nil && (estimatedDuration ?? 0) > 0 && !isCompleted && !isArchived
    }

    /// Formatted scheduled time range (e.g., "2:00 – 3:30 PM" or "2:00 PM")
    var formattedScheduledTime: String? {
        guard let start = scheduledStartTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if let end = scheduledEndTime {
            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: end)
            return "\(startStr) – \(endStr)"
        }
        return formatter.string(from: start)
    }

    /// Check if task is recurring
    var isRecurring: Bool {
        recurringRule != nil
    }

    /// Formatted due date string
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }

        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(dueDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: dueDate)
        }
    }

    /// Formatted due time string
    var formattedDueTime: String? {
        guard let dueTime = dueTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dueTime)
    }

    /// Formatted estimated duration
    var formattedDuration: String? {
        guard let duration = estimatedDuration, duration > 0 else { return nil }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Actual time spent on the task (from startedAt to completedAt)
    var actualDuration: TimeInterval? {
        guard let started = startedAt, let completed = completedAt else { return nil }
        return completed.timeIntervalSince(started)
    }

    /// Formatted actual duration string in timer format (H:MM or M:SS)
    var formattedActualDuration: String? {
        guard let duration = actualDuration, duration > 0 else { return nil }
        return Self.formatDurationAsTimer(duration)
    }

    /// Current elapsed time including accumulated duration (for in-progress tasks)
    var elapsedTime: TimeInterval? {
        guard let started = startedAt, !isCompleted else { return nil }
        return accumulatedDuration + Date().timeIntervalSince(started)
    }

    /// Formatted elapsed time for in-progress tasks
    var formattedElapsedTime: String? {
        guard let elapsed = elapsedTime, elapsed > 0 else { return nil }
        return Self.formatDurationAsTimer(elapsed)
    }

    /// Format duration as timer (H:MM for >= 1 hour, M:SS for < 1 hour)
    static func formatDurationAsTimer(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Create a completed copy of this task
    /// Finalizes accumulated duration for time tracking
    func completed() -> Task {
        var copy = self
        copy.status = .completed
        copy.completedAt = Date()
        // Finalize accumulated duration if task was in progress
        if let started = copy.startedAt {
            copy.accumulatedDuration += Date().timeIntervalSince(started)
        }
        copy.updatedAt = Date()
        return copy
    }

    /// Create an uncompleted copy of this task
    /// Clears startedAt and accumulated duration since we're resetting the task
    func uncompleted() -> Task {
        var copy = self
        copy.status = .pending
        copy.completedAt = nil
        copy.startedAt = nil
        copy.accumulatedDuration = 0
        copy.updatedAt = Date()
        return copy
    }

    /// Create an in-progress copy of this task
    /// Sets startedAt on first start, preserves it when resuming
    func inProgress() -> Task {
        var copy = self
        copy.status = .inProgress
        // Only set startedAt if not already set (first time starting)
        // When resuming after a pause, preserve the original startedAt
        if copy.startedAt == nil {
            copy.startedAt = Date()
        }
        copy.updatedAt = Date()
        return copy
    }

    /// Create a pending copy of this task (stop progress)
    /// Accumulates time spent before pausing
    func stopProgress() -> Task {
        var copy = self
        copy.status = .pending
        // Accumulate time spent in current work session
        if let started = copy.startedAt {
            copy.accumulatedDuration += Date().timeIntervalSince(started)
        }
        copy.startedAt = nil
        copy.updatedAt = Date()
        return copy
    }

    /// Increment intraday completion count
    /// Resets count if it's a new day
    func incrementIntradayCompletion() -> Task {
        var copy = self
        let now = Date()

        // Reset if new day
        if let lastDate = copy.lastIntradayCompletionDate,
           !Calendar.current.isDate(lastDate, inSameDayAs: now) {
            copy.intradayCompletionsToday = 0
        }

        copy.intradayCompletionsToday += 1
        copy.lastIntradayCompletionDate = now
        copy.updatedAt = now
        return copy
    }

    /// Reset intraday completion count (for new day or manual reset)
    func resetIntradayCompletions() -> Task {
        var copy = self
        copy.intradayCompletionsToday = 0
        copy.lastIntradayCompletionDate = nil
        copy.updatedAt = Date()
        return copy
    }

    /// Create a copy with updated fields
    func updated(
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date?? = nil,
        dueTime: Date?? = nil,
        reminderDate: Date?? = nil,
        priority: Priority? = nil,
        category: TaskCategory? = nil,
        customCategoryID: UUID?? = nil,
        listID: UUID?? = nil,
        estimatedDuration: TimeInterval?? = nil,
        recurringRule: RecurringRule?? = nil,
        parentTaskID: UUID?? = nil,
        subtasks: [Task]? = nil,
        subtaskOrder: Int32? = nil
    ) -> Task {
        var copy = self

        if let title = title { copy.title = title }
        if let notes = notes { copy.notes = notes }
        if let dueDate = dueDate { copy.dueDate = dueDate }
        if let dueTime = dueTime { copy.dueTime = dueTime }
        if let reminderDate = reminderDate { copy.reminderDate = reminderDate }
        if let priority = priority { copy.priority = priority }
        if let category = category { copy.category = category }
        if let customCategoryID = customCategoryID { copy.customCategoryID = customCategoryID }
        if let listID = listID { copy.listID = listID }
        if let estimatedDuration = estimatedDuration { copy.estimatedDuration = estimatedDuration }
        if let recurringRule = recurringRule { copy.recurringRule = recurringRule }
        if let parentTaskID = parentTaskID { copy.parentTaskID = parentTaskID }
        if let subtasks = subtasks { copy.subtasks = subtasks }
        if let subtaskOrder = subtaskOrder { copy.subtaskOrder = subtaskOrder }

        copy.updatedAt = Date()
        return copy
    }

    /// Whether task has a custom category assigned
    var hasCustomCategory: Bool {
        customCategoryID != nil
    }
}

// MARK: - Sample Data
extension Task {
    static let sample = Task(
        title: "Review pull request",
        notes: "Check the new authentication module",
        dueDate: Date(),
        priority: .high,
        estimatedDuration: 1800 // 30 minutes
    )

    static let sampleTasks: [Task] = [
        Task(title: "Complete project documentation", dueDate: Date(), priority: .high),
        Task(title: "Review code changes", dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()), priority: .medium),
        Task(title: "Update dependencies", dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()), priority: .low),
        Task(title: "Write unit tests", priority: .medium),
        Task(title: "Fix bug in login flow", dueDate: Date(), isCompleted: true, priority: .urgent)
    ]
}

// MARK: - Transferable (Drag & Drop)
extension Task: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: Task.self, contentType: .task)
    }
}

// MARK: - UTType Extension
extension UTType {
    static var task: UTType {
        UTType(exportedAs: "com.lazyflow.task")
    }
}
