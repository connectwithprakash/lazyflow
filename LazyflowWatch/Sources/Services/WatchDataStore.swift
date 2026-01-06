import Foundation

/// Manages task data storage for Watch
final class WatchDataStore {
    static let shared = WatchDataStore()

    private let defaults = UserDefaults.standard
    private let tasksKey = "watchTasks"
    private let lastSyncKey = "watchLastSync"
    private let completedCountKey = "watchCompletedCount"
    private let totalCountKey = "watchTotalCount"

    private init() {}

    // MARK: - Tasks

    var todayTasks: [WatchTask] {
        get {
            guard let data = defaults.data(forKey: tasksKey),
                  let tasks = try? JSONDecoder().decode([WatchTask].self, from: data) else {
                return []
            }
            return tasks
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: tasksKey)
            }
        }
    }

    // MARK: - Sync Metadata

    var lastSyncDate: Date? {
        get {
            defaults.object(forKey: lastSyncKey) as? Date
        }
        set {
            defaults.set(newValue, forKey: lastSyncKey)
        }
    }

    // MARK: - Progress Stats

    var completedCount: Int {
        get { defaults.integer(forKey: completedCountKey) }
        set { defaults.set(newValue, forKey: completedCountKey) }
    }

    var totalCount: Int {
        get { defaults.integer(forKey: totalCountKey) }
        set { defaults.set(newValue, forKey: totalCountKey) }
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    // MARK: - Update

    func updateTasks(_ tasks: [WatchTask]) {
        todayTasks = tasks
        completedCount = tasks.filter { $0.isCompleted }.count
        totalCount = tasks.count
        lastSyncDate = Date()
    }

    func markTaskCompleted(id: UUID) {
        var tasks = todayTasks
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let task = tasks[index]
            tasks[index] = WatchTask(
                id: task.id,
                title: task.title,
                isCompleted: true,
                priority: task.priority,
                isOverdue: task.isOverdue,
                dueTime: task.dueTime
            )
            updateTasks(tasks)
        }
    }
}
