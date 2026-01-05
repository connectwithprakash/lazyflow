import SwiftUI
import UserNotifications

/// Main entry point for the Taskweave app
@main
struct TaskweaveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .commands {
            // Keyboard shortcuts for iPad
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .newTaskShortcut, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Navigate") {
                Button("Today") {
                    NotificationCenter.default.post(name: .navigateToTab, object: "today")
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Calendar") {
                    NotificationCenter.default.post(name: .navigateToTab, object: "calendar")
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Upcoming") {
                    NotificationCenter.default.post(name: .navigateToTab, object: "upcoming")
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Lists") {
                    NotificationCenter.default.post(name: .navigateToTab, object: "lists")
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Settings") {
                    NotificationCenter.default.post(name: .navigateToTab, object: "settings")
                }
                .keyboardShortcut("5", modifiers: .command)

                Divider()

                Button("Search") {
                    NotificationCenter.default.post(name: .searchShortcut, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "taskweave" else { return }
        if url.host == "view", let path = url.pathComponents.last {
            NotificationCenter.default.post(name: .navigateToTab, object: path)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Note: Notification permission will be requested when user creates a task with reminder
        // This provides a better UX than asking immediately on launch

        // Register notification categories
        NotificationService.shared.registerNotificationCategories()

        return true
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
}

// MARK: - Notification Handling

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification action
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            if let taskIDString = userInfo["taskID"] as? String,
               let taskID = UUID(uuidString: taskIDString) {
                completeTask(withID: taskID)
            }

        case "SNOOZE_ACTION":
            if let taskIDString = userInfo["taskID"] as? String,
               let taskID = UUID(uuidString: taskIDString) {
                snoozeTask(withID: taskID)
            }

        default:
            break
        }

        completionHandler()
    }

    private func completeTask(withID taskID: UUID) {
        let taskService = TaskService()
        if let task = taskService.tasks.first(where: { $0.id == taskID }) {
            taskService.toggleTaskCompletion(task)
        }
    }

    private func snoozeTask(withID taskID: UUID) {
        let taskService = TaskService()
        if let task = taskService.tasks.first(where: { $0.id == taskID }) {
            // Reschedule reminder for 1 hour later
            let newReminderDate = Date().addingHours(1)
            NotificationService.shared.scheduleTaskReminder(
                taskID: taskID,
                title: task.title,
                reminderDate: newReminderDate
            )
        }
    }
}
