import Foundation

/// Mutable draft struct for AI-extracted tasks during review
struct TaskDraft: Identifiable {
    let id = UUID()
    var title: String
    var dueDate: Date?
    var dueTime: Date?
    var priority: Priority
    var category: TaskCategory
    var customCategoryID: UUID?
    var listID: UUID?
    var isSelected: Bool = true
    var isExpanded: Bool = false
    var subtasks: [TaskDraft] = []

    // Track AI's original suggestions for learning
    let originalTitle: String
    let originalPriority: Priority
    let originalCategory: TaskCategory
    let originalDueDate: Date?

    init(
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
    var isModified: Bool {
        title != originalTitle ||
        priority != originalPriority ||
        category != originalCategory ||
        dueDate != originalDueDate ||
        subtasks.contains(where: \.isModified)
    }

    /// Total selected count including subtasks (parent deselected = 0)
    var totalSelectedCount: Int {
        guard isSelected else { return 0 }
        let subtaskCount = subtasks.filter(\.isSelected).count
        return 1 + subtaskCount
    }
}
