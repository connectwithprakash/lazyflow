import AppIntents

/// Provides App Shortcuts that appear automatically in the Shortcuts app
struct LazyflowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Create a task in \(.applicationName)",
                "New task in \(.applicationName)",
                "Add task to \(.applicationName)",
                "Add to \(.applicationName)"
            ],
            shortTitle: "Create Task",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Complete task in \(.applicationName)",
                "Mark done in \(.applicationName)",
                "Finish task in \(.applicationName)",
                "Done in \(.applicationName)",
                "Check off in \(.applicationName)"
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle.fill"
        )

        AppShortcut(
            intent: GetTodayTasksIntent(),
            phrases: [
                "What's on my agenda in \(.applicationName)",
                "Show tasks in \(.applicationName)",
                "What do I have in \(.applicationName)",
                "Today in \(.applicationName)",
                "My tasks in \(.applicationName)"
            ],
            shortTitle: "Today's Tasks",
            systemImageName: "list.bullet"
        )
    }
}
