import ActivityKit
import Foundation

/// Defines the data model for Taskweave Live Activities
struct TaskActivityAttributes: ActivityAttributes {
    /// Static content set when the activity starts (doesn't change)
    let startedAt: Date

    /// Dynamic content that can be updated throughout the activity's lifecycle
    struct ContentState: Codable, Hashable {
        /// Number of completed tasks
        let completedCount: Int

        /// Total number of tasks for today
        let totalCount: Int

        /// Title of the current/next task to work on
        let currentTaskTitle: String?

        /// Priority of the current task (0=none, 1=low, 2=medium, 3=high, 4=urgent)
        let currentTaskPriority: Int16

        /// Title of the next task after current
        let nextTaskTitle: String?

        /// Computed progress (0.0 to 1.0)
        var progress: Double {
            guard totalCount > 0 else { return 0 }
            return Double(completedCount) / Double(totalCount)
        }

        /// Remaining tasks count
        var remainingCount: Int {
            totalCount - completedCount
        }
    }
}
