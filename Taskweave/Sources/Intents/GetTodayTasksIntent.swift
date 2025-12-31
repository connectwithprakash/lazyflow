import AppIntents
import CoreData

/// Siri Shortcut for listing today's tasks
struct GetTodayTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Tasks"
    static var description = IntentDescription("Lists your tasks for today")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Ensure Core Data is initialized
        _ = PersistenceController.shared

        let tasks = TaskService.shared.fetchTodayTasks()
            .filter { !$0.isCompleted }

        if tasks.isEmpty {
            return .result(dialog: "You have no tasks for today. Enjoy your free time!")
        }

        let count = tasks.count
        let topTasks = tasks.prefix(3).map { "- \($0.title)" }.joined(separator: "\n")
        let summary = count > 3 ? "\n...and \(count - 3) more" : ""

        return .result(dialog: "You have \(count) task\(count == 1 ? "" : "s") today:\n\(topTasks)\(summary)")
    }
}
