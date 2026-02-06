import SwiftUI
import UserNotifications

/// Main entry point for the Lazyflow app
@main
struct LazyflowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Set window background BEFORE window is created - prevents black flash
        // Use hardcoded RGB values matching LaunchBackground color asset (0.078, 0.329, 0.337)
        let launchBackgroundColor = UIColor(red: 0.078, green: 0.329, blue: 0.337, alpha: 1.0)
        UIWindow.appearance().backgroundColor = launchBackgroundColor
    }

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
        guard url.scheme == "lazyflow" else { return }
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
        // Set window background color to match launch screen
        let launchBackgroundColor = UIColor(red: 0.078, green: 0.329, blue: 0.337, alpha: 1.0)
        UIWindow.appearance().backgroundColor = launchBackgroundColor

        // Set notification delegate to handle actions
        UNUserNotificationCenter.current().delegate = self

        NotificationService.shared.registerNotificationCategories()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - Scene Delegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let launchColor = UIColor(red: 0.078, green: 0.329, blue: 0.337, alpha: 1.0)
        windowScene.windows.forEach { $0.backgroundColor = launchColor }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            windowScene.windows.forEach { $0.backgroundColor = .systemBackground }
        }
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
        let actionIdentifier = response.actionIdentifier

        // Handle notification action
        switch actionIdentifier {
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

        case "VIEW_SUMMARY_ACTION", UNNotificationDefaultActionIdentifier:
            // Handle tap on Daily Summary notification or its action button
            let category = response.notification.request.content.categoryIdentifier
            if actionIdentifier == "VIEW_SUMMARY_ACTION" || category == "DAILY_SUMMARY" {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .showDailySummary, object: nil)
                }
            } else if category == "MORNING_BRIEFING" {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .showMorningBriefing, object: nil)
                }
            }

        case "VIEW_BRIEFING_ACTION":
            // Handle tap on Morning Briefing action button
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .showMorningBriefing, object: nil)
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
