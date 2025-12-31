import AppIntents
import CoreData

/// Siri Shortcut for completing the highest priority task
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Next Task"
    static var description = IntentDescription("Marks your highest priority task as complete")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Ensure Core Data is initialized
        _ = PersistenceController.shared

        let todayTasks = TaskService.shared.fetchTodayTasks()
            .filter { !$0.isCompleted }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }

        guard let topTask = todayTasks.first else {
            return .result(dialog: "No tasks to complete today!")
        }

        TaskService.shared.toggleTaskCompletion(topTask)
        return .result(dialog: "Completed: \(topTask.title)")
    }
}
