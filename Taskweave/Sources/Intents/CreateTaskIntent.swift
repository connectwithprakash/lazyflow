import AppIntents
import CoreData

/// Siri Shortcut for creating a new task
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Creates a new task in Taskweave")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Priority", default: TaskPriorityAppEnum.none)
    var priority: TaskPriorityAppEnum

    @Parameter(title: "Due Today", default: false)
    var dueToday: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Ensure Core Data is initialized
        _ = PersistenceController.shared

        let dueDate = dueToday ? Date() : nil
        let task = TaskService.shared.createTask(
            title: taskTitle,
            dueDate: dueDate,
            priority: priority.toDomain()
        )
        return .result(dialog: "Created task: \(task.title)")
    }
}
