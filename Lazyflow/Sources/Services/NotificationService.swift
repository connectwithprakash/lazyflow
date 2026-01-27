import Foundation
import UserNotifications

/// Service responsible for managing local notifications for task reminders
final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Schedule Notifications

    /// Schedule a reminder notification for a task
    /// Automatically requests permission if not yet determined
    func scheduleTaskReminder(taskID: UUID, title: String, reminderDate: Date) {
        // Don't schedule if the date is in the past
        guard reminderDate > Date() else { return }

        // Check permission and request if needed before scheduling
        _Concurrency.Task {
            let status = await checkPermissionStatus()

            switch status {
            case .notDetermined:
                // Request permission first
                let granted = await requestPermission()
                if granted {
                    await scheduleNotification(taskID: taskID, title: title, reminderDate: reminderDate)
                } else {
                    print("Notification permission denied by user")
                }
            case .authorized, .provisional, .ephemeral:
                await scheduleNotification(taskID: taskID, title: title, reminderDate: reminderDate)
            case .denied:
                print("Notification permission denied. User needs to enable in Settings.")
            @unknown default:
                break
            }
        }
    }

    /// Internal method to actually schedule the notification
    private func scheduleNotification(taskID: UUID, title: String, reminderDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = title
        content.sound = .default
        content.badge = 1
        content.userInfo = ["taskID": taskID.uuidString]
        content.categoryIdentifier = "TASK_REMINDER"

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: taskID.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    /// Schedule a smart reminder (e.g., morning reminder for tasks without time)
    func scheduleSmartReminder(taskID: UUID, title: String, dueDate: Date) {
        let calendar = Calendar.current

        // Schedule for 9 AM on the due date
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        guard let reminderDate = calendar.date(from: components),
              reminderDate > Date() else { return }

        scheduleTaskReminder(taskID: taskID, title: title, reminderDate: reminderDate)
    }

    /// Schedule a reminder before the task time (e.g., 15 minutes before)
    /// Automatically requests permission if not yet determined
    func scheduleBeforeReminder(taskID: UUID, title: String, taskTime: Date, minutesBefore: Int = 15) {
        guard let reminderDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: taskTime),
              reminderDate > Date() else { return }

        // Check permission and request if needed before scheduling
        _Concurrency.Task {
            let status = await checkPermissionStatus()

            switch status {
            case .notDetermined:
                let granted = await requestPermission()
                if granted {
                    await scheduleBeforeNotification(
                        taskID: taskID,
                        title: title,
                        minutesBefore: minutesBefore,
                        reminderDate: reminderDate
                    )
                }
            case .authorized, .provisional, .ephemeral:
                await scheduleBeforeNotification(
                    taskID: taskID,
                    title: title,
                    minutesBefore: minutesBefore,
                    reminderDate: reminderDate
                )
            case .denied:
                print("Notification permission denied. User needs to enable in Settings.")
            @unknown default:
                break
            }
        }
    }

    /// Internal method to schedule the before notification
    private func scheduleBeforeNotification(taskID: UUID, title: String, minutesBefore: Int, reminderDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Task"
        content.body = "\(title) starts in \(minutesBefore) minutes"
        content.sound = .default
        content.userInfo = ["taskID": taskID.uuidString]
        content.categoryIdentifier = "TASK_UPCOMING"

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "\(taskID.uuidString)-before",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule before notification: \(error)")
        }
    }

    // MARK: - Intraday Notifications

    /// Maximum notifications per intraday task (to leave budget for other tasks)
    private static let maxIntradayNotificationsPerTask = 10

    /// Schedule intraday reminders for a task with an intraday recurring rule
    /// Uses a rolling 24-hour window and respects iOS notification budget
    func scheduleIntradayReminders(for task: Task) {
        guard let rule = task.recurringRule, rule.isIntraday else { return }

        // Cancel existing intraday notifications for this task
        cancelIntradayReminders(for: task.id)

        _Concurrency.Task {
            let status = await checkPermissionStatus()

            switch status {
            case .notDetermined:
                let granted = await requestPermission()
                if granted {
                    await scheduleIntradayNotifications(for: task, rule: rule)
                }
            case .authorized, .provisional, .ephemeral:
                await scheduleIntradayNotifications(for: task, rule: rule)
            case .denied:
                print("Notification permission denied for intraday reminders")
            @unknown default:
                break
            }
        }
    }

    /// Internal method to schedule intraday notifications
    private func scheduleIntradayNotifications(for task: Task, rule: RecurringRule) async {
        let calendar = Calendar.current
        let now = Date()

        // Calculate times for today and tomorrow (rolling 24-hour window)
        let todayTimes = rule.calculateIntradayTimes(for: now)
        let tomorrowTimes = rule.calculateIntradayTimes(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)

        // Combine and filter to future times only
        var allTimes = todayTimes.filter { $0 > now }
        allTimes.append(contentsOf: tomorrowTimes)

        // Limit to budget
        let timesToSchedule = Array(allTimes.prefix(Self.maxIntradayNotificationsPerTask))

        for (index, time) in timesToSchedule.enumerated() {
            await scheduleIntradayNotification(
                taskID: task.id,
                title: task.title,
                reminderTime: time,
                index: index,
                rule: rule
            )
        }

        if !timesToSchedule.isEmpty {
            print("Scheduled \(timesToSchedule.count) intraday notifications for task: \(task.title)")
        }
    }

    /// Schedule a single intraday notification
    private func scheduleIntradayNotification(
        taskID: UUID,
        title: String,
        reminderTime: Date,
        index: Int,
        rule: RecurringRule
    ) async {
        let content = UNMutableNotificationContent()
        content.title = intradayNotificationTitle(for: rule)
        content.body = title
        content.sound = .default
        content.userInfo = [
            "taskID": taskID.uuidString,
            "isIntraday": true,
            "intradayIndex": index
        ]
        content.categoryIdentifier = "INTRADAY_REMINDER"

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let identifier = "\(taskID.uuidString)-intraday-\(index)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule intraday notification: \(error)")
        }
    }

    /// Generate appropriate notification title based on intraday rule
    private func intradayNotificationTitle(for rule: RecurringRule) -> String {
        switch rule.frequency {
        case .hourly:
            let hours = rule.hourInterval ?? 2
            return hours == 1 ? "Hourly Reminder" : "Every \(hours) Hours"
        case .timesPerDay:
            let count = rule.timesPerDay ?? 3
            return "Daily Reminder (\(count)x/day)"
        default:
            return "Task Reminder"
        }
    }

    /// Cancel all intraday reminders for a specific task
    func cancelIntradayReminders(for taskID: UUID) {
        // Cancel up to maxIntradayNotificationsPerTask notifications
        var identifiers: [String] = []
        for i in 0..<Self.maxIntradayNotificationsPerTask {
            identifiers.append("\(taskID.uuidString)-intraday-\(i)")
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Cancel the next upcoming intraday notification for a task (called when user completes an instance)
    func cancelNextIntradayReminder(for taskID: UUID) {
        let taskIDString = taskID.uuidString

        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            // Find all intraday notifications for this task
            let intradayRequests = requests.filter { request in
                request.identifier.hasPrefix("\(taskIDString)-intraday-")
            }

            guard !intradayRequests.isEmpty else { return }

            // Sort by trigger date to find the next one
            let sortedRequests = intradayRequests.sorted { req1, req2 in
                guard let trigger1 = req1.trigger as? UNCalendarNotificationTrigger,
                      let trigger2 = req2.trigger as? UNCalendarNotificationTrigger,
                      let date1 = trigger1.nextTriggerDate(),
                      let date2 = trigger2.nextTriggerDate() else {
                    return false
                }
                return date1 < date2
            }

            // Cancel the next (earliest) one
            if let nextRequest = sortedRequests.first {
                self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: [nextRequest.identifier])
                print("Cancelled next intraday notification for task: \(taskIDString)")
            }
        }
    }

    /// Reschedule all intraday notifications (call on app wake/background refresh)
    func rescheduleAllIntradayReminders(tasks: [Task]) {
        for task in tasks {
            if let rule = task.recurringRule, rule.isIntraday, !task.isCompleted {
                scheduleIntradayReminders(for: task)
            }
        }
    }

    // MARK: - Cancel Notifications

    /// Cancel a specific task reminder (including intraday)
    func cancelTaskReminder(taskID: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            taskID.uuidString,
            "\(taskID.uuidString)-before"
        ])
        // Also cancel any intraday reminders
        cancelIntradayReminders(for: taskID)
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Daily Summary Notifications

    private static let dailySummaryIdentifier = "daily_summary_reminder"

    /// Schedule daily evening summary reminder
    /// - Parameters:
    ///   - hour: Hour to send reminder (0-23)
    ///   - minute: Minute to send reminder (0-59)
    func scheduleDailySummaryReminder(hour: Int, minute: Int) {
        _Concurrency.Task {
            let status = await checkPermissionStatus()

            switch status {
            case .authorized, .provisional, .ephemeral:
                await scheduleDailySummaryNotification(hour: hour, minute: minute)
            case .notDetermined:
                let granted = await requestPermission()
                if granted {
                    await scheduleDailySummaryNotification(hour: hour, minute: minute)
                }
            case .denied:
                print("Notification permission denied for daily summary")
            @unknown default:
                break
            }
        }
    }

    private func scheduleDailySummaryNotification(hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Daily Summary Ready"
        content.body = "See how productive you were today!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.dailySummaryIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("Scheduled daily summary reminder at \(hour):\(minute)")
        } catch {
            print("Failed to schedule daily summary reminder: \(error)")
        }
    }

    /// Cancel the daily summary reminder
    func cancelDailySummaryReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.dailySummaryIdentifier])
    }

    // MARK: - Morning Briefing Notifications

    private static let morningBriefingIdentifier = "morning_briefing_reminder"

    /// Schedule daily morning briefing notification
    /// - Parameters:
    ///   - hour: Hour to send briefing (0-23), typically 6-9 AM
    ///   - minute: Minute to send briefing (0-59)
    func scheduleMorningBriefing(hour: Int, minute: Int) {
        _Concurrency.Task {
            let status = await checkPermissionStatus()

            switch status {
            case .authorized, .provisional, .ephemeral:
                await scheduleMorningBriefingNotification(hour: hour, minute: minute)
            case .notDetermined:
                let granted = await requestPermission()
                if granted {
                    await scheduleMorningBriefingNotification(hour: hour, minute: minute)
                }
            case .denied:
                print("Notification permission denied for morning briefing")
            @unknown default:
                break
            }
        }
    }

    private func scheduleMorningBriefingNotification(hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"
        content.body = "Your daily briefing is ready. See what's planned for today."
        content.sound = .default
        content.categoryIdentifier = "MORNING_BRIEFING"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.morningBriefingIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("Scheduled morning briefing at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("Failed to schedule morning briefing: \(error)")
        }
    }

    /// Cancel the morning briefing reminder
    func cancelMorningBriefing() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.morningBriefingIdentifier])
    }

    // MARK: - Badge Management

    /// Clear the notification badge
    func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    /// Update badge count to reflect pending tasks
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    // MARK: - Notification Categories

    /// Register notification categories with actions
    func registerNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.authenticationRequired]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze (1 hour)",
            options: []
        )

        let taskReminderCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let taskUpcomingCategory = UNNotificationCategory(
            identifier: "TASK_UPCOMING",
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )

        let viewSummaryAction = UNNotificationAction(
            identifier: "VIEW_SUMMARY_ACTION",
            title: "View Summary",
            options: [.foreground]
        )

        let dailySummaryCategory = UNNotificationCategory(
            identifier: "DAILY_SUMMARY",
            actions: [viewSummaryAction],
            intentIdentifiers: [],
            options: []
        )

        let viewBriefingAction = UNNotificationAction(
            identifier: "VIEW_BRIEFING_ACTION",
            title: "Start My Day",
            options: [.foreground]
        )

        let morningBriefingCategory = UNNotificationCategory(
            identifier: "MORNING_BRIEFING",
            actions: [viewBriefingAction],
            intentIdentifiers: [],
            options: []
        )

        // Intraday reminder category with complete and snooze actions
        let intradayReminderCategory = UNNotificationCategory(
            identifier: "INTRADAY_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        notificationCenter.setNotificationCategories([
            taskReminderCategory,
            taskUpcomingCategory,
            dailySummaryCategory,
            morningBriefingCategory,
            intradayReminderCategory
        ])
    }
}
