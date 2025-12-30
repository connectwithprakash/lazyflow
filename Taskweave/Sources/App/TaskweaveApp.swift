import SwiftUI
import UserNotifications

/// Main entry point for the Taskweave app
@main
struct TaskweaveApp: App {
    let persistenceController = PersistenceController.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Configure appearance
        configureAppearance()

        // Create default lists if needed
        persistenceController.createDefaultListsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }

    private func configureAppearance() {
        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance

        // Navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
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
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Handle remote notification registration for CloudKit
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
