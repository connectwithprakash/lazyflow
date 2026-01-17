import SwiftUI

/// App design constants
enum WidgetDesign {
    static let accentColor = Color(red: 0.129, green: 0.541, blue: 0.553) // Teal #218A8D
    static let urgentColor = Color(red: 0.898, green: 0.224, blue: 0.208) // Red
    static let highColor = Color(red: 0.961, green: 0.518, blue: 0.141)   // Orange
    static let mediumColor = Color(red: 0.965, green: 0.753, blue: 0.196) // Yellow
    static let lowColor = Color(red: 0.255, green: 0.478, blue: 0.871)    // Blue
}

/// Lightweight task model for widget display
struct WidgetTask: Identifiable {
    let id: UUID
    let title: String
    let priority: Int16
    let isCompleted: Bool
    let dueDate: Date?
    let subtaskCount: Int
    let completedSubtaskCount: Int

    init(
        id: UUID,
        title: String,
        priority: Int16,
        isCompleted: Bool,
        dueDate: Date?,
        subtaskCount: Int = 0,
        completedSubtaskCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.subtaskCount = subtaskCount
        self.completedSubtaskCount = completedSubtaskCount
    }

    var hasSubtasks: Bool {
        subtaskCount > 0
    }

    var subtaskProgress: Double {
        guard subtaskCount > 0 else { return 0 }
        return Double(completedSubtaskCount) / Double(subtaskCount)
    }

    var subtaskProgressString: String? {
        guard hasSubtasks else { return nil }
        return "\(completedSubtaskCount)/\(subtaskCount)"
    }

    var priorityColor: Color {
        switch priority {
        case 4: return WidgetDesign.urgentColor
        case 3: return WidgetDesign.highColor
        case 2: return WidgetDesign.mediumColor
        case 1: return WidgetDesign.lowColor
        default: return .gray.opacity(0.4)
        }
    }

    var priorityName: String {
        switch priority {
        case 4: return "Urgent"
        case 3: return "High"
        case 2: return "Medium"
        case 1: return "Low"
        default: return ""
        }
    }
}
