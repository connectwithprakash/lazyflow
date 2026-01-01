import Foundation
import WidgetKit

/// Shared data store using UserDefaults with App Groups
/// This allows the widget to access task data written by the main app
struct WidgetDataStore {
    private static let appGroupIdentifier = "group.com.taskweave.shared"
    private static let tasksKey = "widget_tasks"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Save tasks for widget display and refresh widgets
    static func saveTasks(_ tasks: [WidgetTaskData]) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(tasks) {
            defaults.set(encoded, forKey: tasksKey)
            // Trigger widget refresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Load tasks for widget display
    static func loadTasks() -> [WidgetTaskData] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([WidgetTaskData].self, from: data) else {
            return []
        }
        return tasks
    }
}

/// Codable task data for widget sharing
struct WidgetTaskData: Codable, Identifiable {
    let id: UUID
    let title: String
    let priority: Int16
    let isCompleted: Bool
    let dueDate: Date?
}

// MARK: - Task Extension for Widget Data
extension Task {
    /// Convert to widget-compatible data
    func toWidgetData() -> WidgetTaskData {
        WidgetTaskData(
            id: id,
            title: title,
            priority: priority.rawValue,
            isCompleted: isCompleted,
            dueDate: dueDate
        )
    }
}
