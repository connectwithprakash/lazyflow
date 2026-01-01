import ActivityKit
import Foundation

/// Manages Live Activity lifecycle for task tracking
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    /// Currently active task tracking activity
    @Published private(set) var currentActivity: Activity<TaskActivityAttributes>?

    /// Whether Live Activities are supported on this device
    var areActivitiesSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Whether there's an active task tracking activity
    var isTrackingActive: Bool {
        currentActivity != nil
    }

    private init() {}

    // MARK: - Public Methods

    /// Start tracking tasks with a Live Activity
    /// - Parameters:
    ///   - completedCount: Number of completed tasks
    ///   - totalCount: Total number of tasks
    ///   - currentTask: Title of the current task
    ///   - currentPriority: Priority of the current task
    ///   - nextTask: Title of the next task
    func startTracking(
        completedCount: Int,
        totalCount: Int,
        currentTask: String?,
        currentPriority: Int16,
        nextTask: String?
    ) async {
        // Don't start if not supported or already tracking
        guard areActivitiesSupported else {
            print("Live Activities not supported on this device")
            return
        }

        // End any existing activity first
        if currentActivity != nil {
            await stopTracking()
        }

        let attributes = TaskActivityAttributes(startedAt: Date())
        let initialState = TaskActivityAttributes.ContentState(
            completedCount: completedCount,
            totalCount: totalCount,
            currentTaskTitle: currentTask,
            currentTaskPriority: currentPriority,
            nextTaskTitle: nextTask
        )

        let content = ActivityContent(
            state: initialState,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("Live Activity started: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Update the Live Activity with new task progress
    /// - Parameters:
    ///   - completedCount: Number of completed tasks
    ///   - totalCount: Total number of tasks
    ///   - currentTask: Title of the current task
    ///   - currentPriority: Priority of the current task
    ///   - nextTask: Title of the next task
    func updateProgress(
        completedCount: Int,
        totalCount: Int,
        currentTask: String?,
        currentPriority: Int16,
        nextTask: String?
    ) async {
        guard let activity = currentActivity else { return }

        let updatedState = TaskActivityAttributes.ContentState(
            completedCount: completedCount,
            totalCount: totalCount,
            currentTaskTitle: currentTask,
            currentTaskPriority: currentPriority,
            nextTaskTitle: nextTask
        )

        let content = ActivityContent(
            state: updatedState,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        )

        await activity.update(content)
        print("Live Activity updated: \(completedCount)/\(totalCount)")
    }

    /// Stop the current Live Activity
    /// - Parameter showFinalState: Whether to show a final "complete" state
    func stopTracking(showFinalState: Bool = false) async {
        guard let activity = currentActivity else { return }

        if showFinalState {
            // Show completion state briefly before dismissing
            let finalState = TaskActivityAttributes.ContentState(
                completedCount: activity.content.state.totalCount,
                totalCount: activity.content.state.totalCount,
                currentTaskTitle: nil,
                currentTaskPriority: 0,
                nextTaskTitle: nil
            )
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(finalContent, dismissalPolicy: .after(.now + 5))
        } else {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        currentActivity = nil
        print("Live Activity stopped")
    }

    /// Convenience method to update from task arrays
    /// - Parameter tasks: Array of tasks to display progress for
    func updateFromTasks(_ tasks: [Task]) async {
        let todayTasks = tasks.filter { $0.isDueToday || $0.isOverdue }
        let completedCount = todayTasks.filter { $0.isCompleted }.count
        let totalCount = todayTasks.count

        let incompleteTasks = todayTasks.filter { !$0.isCompleted }
            .sorted { task1, task2 in
                // Sort by priority (higher first), then by due date
                if task1.priority != task2.priority {
                    return task1.priority.rawValue > task2.priority.rawValue
                }
                if let date1 = task1.dueDate, let date2 = task2.dueDate {
                    return date1 < date2
                }
                return task1.dueDate != nil
            }

        let currentTask = incompleteTasks.first
        let nextTask = incompleteTasks.dropFirst().first

        if totalCount == 0 {
            // No tasks for today, stop tracking
            await stopTracking()
        } else if completedCount == totalCount {
            // All done, show completion state
            await stopTracking(showFinalState: true)
        } else if isTrackingActive {
            // Update existing activity
            await updateProgress(
                completedCount: completedCount,
                totalCount: totalCount,
                currentTask: currentTask?.title,
                currentPriority: currentTask?.priority.rawValue ?? 0,
                nextTask: nextTask?.title
            )
        }
    }
}
