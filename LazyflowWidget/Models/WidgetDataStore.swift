import Foundation

/// Shared data store using UserDefaults with App Groups
/// This allows the widget to access task data written by the main app
struct WidgetDataStore {
    private static let appGroupIdentifier = "group.com.lazyflow.shared"
    private static let tasksKey = "widget_tasks"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Save tasks for widget display
    static func saveTasks(_ tasks: [WidgetTaskData]) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(tasks) {
            defaults.set(encoded, forKey: tasksKey)
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

    func toWidgetTask() -> WidgetTask {
        WidgetTask(
            id: id,
            title: title,
            priority: priority,
            isCompleted: isCompleted,
            dueDate: dueDate
        )
    }
}
