import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// Domain model representing a task
struct Task: Identifiable, Codable, Equatable, Hashable, Transferable {
    let id: UUID
    var title: String
    var notes: String?
    var dueDate: Date?
    var dueTime: Date?
    var reminderDate: Date?
    var isCompleted: Bool
    var isArchived: Bool
    var priority: Priority
    var listID: UUID?
    var linkedEventID: String?
    var estimatedDuration: TimeInterval?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var recurringRule: RecurringRule?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        reminderDate: Date? = nil,
        isCompleted: Bool = false,
        isArchived: Bool = false,
        priority: Priority = .none,
        listID: UUID? = nil,
        linkedEventID: String? = nil,
        estimatedDuration: TimeInterval? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        recurringRule: RecurringRule? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.reminderDate = reminderDate
        self.isCompleted = isCompleted
        self.isArchived = isArchived
        self.priority = priority
        self.listID = listID
        self.linkedEventID = linkedEventID
        self.estimatedDuration = estimatedDuration
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recurringRule = recurringRule
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

    /// Create a completed copy of this task
    func completed() -> Task {
        var copy = self
        copy.isCompleted = true
        copy.completedAt = Date()
        copy.updatedAt = Date()
        return copy
    }

    /// Create an uncompleted copy of this task
    func uncompleted() -> Task {
        var copy = self
        copy.isCompleted = false
        copy.completedAt = nil
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
        listID: UUID?? = nil,
        estimatedDuration: TimeInterval?? = nil,
        recurringRule: RecurringRule?? = nil
    ) -> Task {
        var copy = self

        if let title = title { copy.title = title }
        if let notes = notes { copy.notes = notes }
        if let dueDate = dueDate { copy.dueDate = dueDate }
        if let dueTime = dueTime { copy.dueTime = dueTime }
        if let reminderDate = reminderDate { copy.reminderDate = reminderDate }
        if let priority = priority { copy.priority = priority }
        if let listID = listID { copy.listID = listID }
        if let estimatedDuration = estimatedDuration { copy.estimatedDuration = estimatedDuration }
        if let recurringRule = recurringRule { copy.recurringRule = recurringRule }

        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Transferable
extension Task {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: Task.self, contentType: .task)
    }
}

extension UTType {
    static var task: UTType {
        UTType(exportedAs: "com.connectwithprakash.taskweave.task")
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
