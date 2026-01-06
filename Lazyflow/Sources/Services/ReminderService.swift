import Foundation
import Combine

/// Service that handles smart reminder logic and scheduling
final class ReminderService: ObservableObject {
    private let notificationService: NotificationService
    private let taskService: TaskService

    private var cancellables = Set<AnyCancellable>()

    init(
        notificationService: NotificationService = .shared,
        taskService: TaskService
    ) {
        self.notificationService = notificationService
        self.taskService = taskService

        setupNotificationCategories()
        observeTaskChanges()
    }

    // MARK: - Setup

    private func setupNotificationCategories() {
        notificationService.registerNotificationCategories()
    }

    private func observeTaskChanges() {
        taskService.$tasks
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.scheduleRemindersForTasks(tasks)
            }
            .store(in: &cancellables)
    }

    // MARK: - Reminder Scheduling

    /// Schedule reminders for all tasks with due dates
    func scheduleRemindersForTasks(_ tasks: [Task]) {
        for task in tasks where !task.isCompleted && !task.isArchived {
            scheduleReminder(for: task)
        }
    }

    /// Schedule a reminder for a specific task
    func scheduleReminder(for task: Task) {
        // Cancel existing reminders first
        notificationService.cancelTaskReminder(taskID: task.id)

        // If task has explicit reminder, use that
        if let reminderDate = task.reminderDate {
            notificationService.scheduleTaskReminder(
                taskID: task.id,
                title: task.title,
                reminderDate: reminderDate
            )
            return
        }

        // Apply smart reminder logic
        if let dueDate = task.dueDate {
            if let dueTime = task.dueTime {
                // Task has specific time - remind 30 minutes before
                notificationService.scheduleBeforeReminder(
                    taskID: task.id,
                    title: task.title,
                    taskTime: combineDateAndTime(date: dueDate, time: dueTime),
                    minutesBefore: 30
                )
            } else {
                // Task has only date - remind in the morning
                notificationService.scheduleSmartReminder(
                    taskID: task.id,
                    title: task.title,
                    dueDate: dueDate
                )
            }
        }
    }

    /// Cancel reminder for a task
    func cancelReminder(for task: Task) {
        notificationService.cancelTaskReminder(taskID: task.id)
    }

    // MARK: - Badge Management

    /// Update the app badge to show overdue and due today count
    func updateBadge() {
        let overdueTasks = taskService.fetchOverdueTasks()
        let todayTasks = taskService.fetchTodayTasks().filter { !$0.isCompleted }

        let badgeCount = overdueTasks.count + todayTasks.count
        notificationService.updateBadgeCount(badgeCount)
    }

    // MARK: - Helpers

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}

// MARK: - Reminder Options

enum ReminderOption: CaseIterable, Identifiable {
    case none
    case atTime
    case fiveMinutesBefore
    case fifteenMinutesBefore
    case thirtyMinutesBefore
    case oneHourBefore
    case oneDayBefore
    case custom

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .atTime: return "At time of event"
        case .fiveMinutesBefore: return "5 minutes before"
        case .fifteenMinutesBefore: return "15 minutes before"
        case .thirtyMinutesBefore: return "30 minutes before"
        case .oneHourBefore: return "1 hour before"
        case .oneDayBefore: return "1 day before"
        case .custom: return "Custom"
        }
    }

    var minutesBefore: Int? {
        switch self {
        case .none, .custom: return nil
        case .atTime: return 0
        case .fiveMinutesBefore: return 5
        case .fifteenMinutesBefore: return 15
        case .thirtyMinutesBefore: return 30
        case .oneHourBefore: return 60
        case .oneDayBefore: return 1440
        }
    }

    func reminderDate(from dueDate: Date) -> Date? {
        guard let minutes = minutesBefore else { return nil }
        return Calendar.current.date(byAdding: .minute, value: -minutes, to: dueDate)
    }
}
