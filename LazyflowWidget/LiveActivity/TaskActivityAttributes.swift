import ActivityKit
import Foundation

/// Defines the data model for Lazyflow Live Activities
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

        /// Priority of the next task
        let nextTaskPriority: Int16

        /// Title of task currently being worked on (in-progress status)
        let inProgressTaskTitle: String?

        /// When the in-progress task was started
        let inProgressStartedAt: Date?

        /// Priority of the in-progress task
        let inProgressPriority: Int16

        /// Estimated duration of in-progress task (if set)
        let inProgressEstimatedDuration: TimeInterval?

        /// Computed progress (0.0 to 1.0)
        var progress: Double {
            guard totalCount > 0 else { return 0 }
            return Double(completedCount) / Double(totalCount)
        }

        /// Remaining tasks count
        var remainingCount: Int {
            totalCount - completedCount
        }

        /// Whether there's an active in-progress task
        var hasInProgressTask: Bool {
            inProgressTaskTitle != nil
        }

        /// Initialize with all fields
        init(
            completedCount: Int,
            totalCount: Int,
            currentTaskTitle: String?,
            currentTaskPriority: Int16,
            nextTaskTitle: String?,
            nextTaskPriority: Int16 = 0,
            inProgressTaskTitle: String? = nil,
            inProgressStartedAt: Date? = nil,
            inProgressPriority: Int16 = 0,
            inProgressEstimatedDuration: TimeInterval? = nil
        ) {
            self.completedCount = completedCount
            self.totalCount = totalCount
            self.currentTaskTitle = currentTaskTitle
            self.currentTaskPriority = currentTaskPriority
            self.nextTaskTitle = nextTaskTitle
            self.nextTaskPriority = nextTaskPriority
            self.inProgressTaskTitle = inProgressTaskTitle
            self.inProgressStartedAt = inProgressStartedAt
            self.inProgressPriority = inProgressPriority
            self.inProgressEstimatedDuration = inProgressEstimatedDuration
        }
    }
}
