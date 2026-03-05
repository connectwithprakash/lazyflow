import Foundation

/// Mutable draft struct for AI-extracted tasks during review
public struct TaskDraft: Identifiable {
    public let id = UUID()
    public var title: String
    public var dueDate: Date?
    public var dueTime: Date?
    public var priority: Priority
    public var category: TaskCategory
    public var customCategoryID: UUID?
    public var listID: UUID?
    public var isSelected: Bool = true
    public var isExpanded: Bool = false
    public var subtasks: [TaskDraft] = []

    // Track AI's original suggestions for learning
    public let originalTitle: String
    public let originalPriority: Priority
    public let originalCategory: TaskCategory
    public let originalDueDate: Date?

    public init(
        title: String,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        priority: Priority = .none,
        category: TaskCategory = .uncategorized,
        customCategoryID: UUID? = nil,
        listID: UUID? = nil,
        subtasks: [TaskDraft] = []
    ) {
        self.title = title
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.priority = priority
        self.category = category
        self.customCategoryID = customCategoryID
        self.listID = listID
        self.subtasks = subtasks

        self.originalTitle = title
        self.originalPriority = priority
        self.originalCategory = category
        self.originalDueDate = dueDate
    }

    /// Whether the user has modified this draft from the AI suggestion
    public var isModified: Bool {
        title != originalTitle ||
        priority != originalPriority ||
        category != originalCategory ||
        dueDate != originalDueDate ||
        subtasks.contains(where: \.isModified)
    }

    /// Total selected count including subtasks (parent deselected = 0)
    public var totalSelectedCount: Int {
        guard isSelected else { return 0 }
        let subtaskCount = subtasks.filter(\.isSelected).count
        return 1 + subtaskCount
    }
}
