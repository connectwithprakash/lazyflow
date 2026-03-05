import SwiftUI
import LazyflowCore
import LazyflowUI

// MARK: - Morning Briefing Prompt Toggle

struct MorningBriefingPromptToggle: View {
    @AppStorage(AppConstants.StorageKey.morningBriefingEnabled) private var isEnabled = true

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "sun.horizon")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                Text("Show Prompt on Today")
            }
        }
        .accessibilityIdentifier("Morning Briefing Prompt Toggle")
    }
}

// MARK: - Morning Briefing Notification Toggle

struct MorningBriefingNotificationToggle: View {
    @AppStorage(AppConstants.StorageKey.morningBriefingNotificationEnabled) private var isEnabled = false
    @AppStorage(AppConstants.StorageKey.morningBriefingNotificationHour) private var notificationHour = AppConstants.Defaults.morningBriefingNotificationHour

    private let notificationService = NotificationService.shared

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning Reminder")
                    if isEnabled {
                        Text(formattedTime)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                notificationService.scheduleMorningBriefing(hour: notificationHour, minute: 0)
            } else {
                notificationService.cancelMorningBriefing()
            }
        }

        if isEnabled {
            Picker("Reminder Time", selection: $notificationHour) {
                ForEach(5..<12, id: \.self) { hour in
                    Text(formatHour(hour)).tag(hour)
                }
            }
            .onChange(of: notificationHour) { _, newHour in
                notificationService.scheduleMorningBriefing(hour: newHour, minute: 0)
            }
        }
    }

    private var formattedTime: String {
        formatHour(notificationHour)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Daily Summary Notification Toggle

struct DailySummaryNotificationToggle: View {
    @AppStorage(AppConstants.StorageKey.dailySummaryNotificationEnabled) private var isEnabled = false
    @AppStorage(AppConstants.StorageKey.dailySummaryNotificationHour) private var notificationHour = AppConstants.Defaults.dailySummaryNotificationHour
    @State private var showTimePicker = false

    private let notificationService = NotificationService.shared

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(Color.Lazyflow.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evening Reminder")
                    if isEnabled {
                        Text(formattedTime)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("Evening Reminder Toggle")
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                notificationService.scheduleDailySummaryReminder(hour: notificationHour, minute: 0)
            } else {
                notificationService.cancelDailySummaryReminder()
            }
        }

        if isEnabled {
            Picker("Reminder Time", selection: $notificationHour) {
                ForEach(17..<23, id: \.self) { hour in
                    Text(formatHour(hour)).tag(hour)
                }
            }
            .onChange(of: notificationHour) { _, newHour in
                notificationService.scheduleDailySummaryReminder(hour: newHour, minute: 0)
            }
        }
    }

    private var formattedTime: String {
        formatHour(notificationHour)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Live Activity Toggle

struct LiveActivityToggle: View {
    private var liveActivityManager = LiveActivityManager.shared
    @State private var isEnabled = false

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: "rectangle.badge.checkmark")
                    .foregroundColor(Color.Lazyflow.accent)
                    .frame(width: 24)
                Text("Track Today's Progress")
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            _Concurrency.Task {
                if newValue {
                    await startLiveActivity()
                } else {
                    await liveActivityManager.stopTracking()
                }
            }
        }
        .onAppear {
            isEnabled = liveActivityManager.isTrackingActive
        }
    }

    private func startLiveActivity() async {
        let tasks = TaskService.shared.tasks
        let todayTasks = tasks.filter { $0.isDueToday || $0.isOverdue }
        let completedCount = todayTasks.filter { $0.isCompleted }.count
        let totalCount = todayTasks.count

        guard totalCount > 0 else { return }

        // Find in-progress task
        let inProgressTask = todayTasks.first { $0.isInProgress }

        let incompleteTasks = todayTasks.filter { !$0.isCompleted && !$0.isInProgress }
            .sorted { task1, task2 in
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

        await liveActivityManager.startTracking(
            completedCount: completedCount,
            totalCount: totalCount,
            currentTask: currentTask?.title,
            currentPriority: currentTask?.priority.rawValue ?? 0,
            nextTask: nextTask?.title,
            nextPriority: nextTask?.priority.rawValue ?? 0,
            inProgressTask: inProgressTask?.title,
            inProgressStartedAt: inProgressTask?.updatedAt,
            inProgressPriority: inProgressTask?.priority.rawValue ?? 0,
            inProgressEstimatedDuration: inProgressTask?.estimatedDuration
        )
    }
}

// MARK: - Calendar Sync Toggle

struct CalendarSyncToggle: View {
    @AppStorage(AppConstants.StorageKey.calendarAutoSync) private var calendarAutoSync = false
    @AppStorage(AppConstants.StorageKey.calendarCompletionPolicy) private var completionPolicy = "keep"
    @AppStorage(AppConstants.StorageKey.calendarBusyOnly) private var busyOnly = false
    @State private var isRequestingAccess = false

    var body: some View {
        Toggle(isOn: $calendarAutoSync) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color.Lazyflow.accent)
                    .frame(width: 24)
                Text("Auto-Sync to Calendar")
            }
        }
        .onChange(of: calendarAutoSync) { _, enabled in
            if enabled {
                enableSync()
            } else {
                CalendarSyncService.shared.stopObserving()
            }
        }

        if calendarAutoSync {
            Picker("On Task Completion", selection: $completionPolicy) {
                Text("Keep Event").tag("keep")
                Text("Delete Event").tag("delete")
            }

            Toggle(isOn: $busyOnly) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Busy-Only Privacy Mode")
                    Text("Events show \"Focus Block\" instead of task title")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }
            }
        }
    }

    private func enableSync() {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true

        _Concurrency.Task {
            let granted = await CalendarService.shared.requestAccess()
            await MainActor.run {
                isRequestingAccess = false
                if granted {
                    _ = CalendarService.shared.getOrCreateLazyflowCalendar()
                    CalendarSyncService.shared.startObserving()
                } else {
                    calendarAutoSync = false
                }
            }
        }
    }
}
