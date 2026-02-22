import Foundation
import EventKit
import Combine

/// Orchestrates two-way sync between tasks and calendar events.
/// Forward: eligible tasks → Lazyflow calendar events.
/// Reverse: external event changes → task updates.
final class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()

    private let calendarService: CalendarService
    private let taskService: TaskService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Loop Prevention

    /// Tasks recently pushed to calendar — skip reverse sync for 10 seconds
    private var recentlyPushedTaskIDs: [UUID: Date] = [:]
    private let pushCooldown: TimeInterval = 10

    /// Whether a sync operation is in progress
    private(set) var isSyncing = false

    /// Guard against re-syncing tasks that were just reverse-synced (3s window)
    private let reverseSyncGuard: TimeInterval = 3

    // MARK: - Completion Policy

    enum CompletionPolicy: String {
        case keepEvent = "keep"
        case deleteEvent = "delete"
    }

    // MARK: - Settings Keys

    private var isAutoSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "calendarAutoSync")
    }

    private var completionPolicy: CompletionPolicy {
        let raw = UserDefaults.standard.string(forKey: "calendarCompletionPolicy") ?? "keep"
        return CompletionPolicy(rawValue: raw) ?? .keepEvent
    }

    private var isBusyOnly: Bool {
        UserDefaults.standard.bool(forKey: "calendarBusyOnly")
    }

    // MARK: - Init

    init(
        calendarService: CalendarService = .shared,
        taskService: TaskService = .shared
    ) {
        self.calendarService = calendarService
        self.taskService = taskService
    }

    // MARK: - Lifecycle

    /// Start observing task changes and calendar changes
    func startObserving() {
        guard isAutoSyncEnabled else { return }
        stopObserving()

        // Forward sync: debounced task changes → push to calendar
        taskService.$tasks
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] tasks in
                guard let self, self.isAutoSyncEnabled, !self.isSyncing else { return }
                self.performForwardSync(tasks: tasks)
            }
            .store(in: &cancellables)

        // Reverse sync: debounced calendar store changes → pull to tasks
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isAutoSyncEnabled, !self.isSyncing else { return }
                self.performReverseSync()
            }
            .store(in: &cancellables)
    }

    /// Stop all observation
    func stopObserving() {
        cancellables.removeAll()
    }

    // MARK: - Forward Sync (Task → Event)

    private func performForwardSync(tasks: [Task]) {
        guard calendarService.hasCalendarAccess else { return }

        isSyncing = true
        defer { isSyncing = false }

        for task in tasks {
            // Skip tasks that were just reverse-synced
            if let lastSynced = task.lastSyncedAt,
               Date().timeIntervalSince(lastSynced) < reverseSyncGuard {
                continue
            }

            if task.isEligibleForAutoSync {
                if task.linkedEventID == nil {
                    // Create new event
                    createEventForTask(task)
                } else {
                    // Push updates to existing event
                    pushUpdatesToEvent(for: task)
                }
            } else if task.isCompleted, task.linkedEventID != nil {
                handleCompletedTask(task)
            }
        }

        pruneExpiredCooldowns()
    }

    /// Create a calendar event for an eligible task
    private func createEventForTask(_ task: Task) {
        guard let calendar = calendarService.syncCalendar(),
              let dueDate = task.dueDate,
              let dueTime = task.dueTime,
              let duration = task.estimatedDuration else { return }

        // Combine dueDate and dueTime into start time
        let cal = Calendar.current
        let dateComponents = cal.dateComponents([.year, .month, .day], from: dueDate)
        let timeComponents = cal.dateComponents([.hour, .minute], from: dueTime)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        guard let startDate = cal.date(from: combined) else { return }
        let endDate = startDate.addingTimeInterval(duration)

        let title = isBusyOnly ? "Focus Block" : task.title
        let notes = isBusyOnly ? nil : task.notes

        do {
            let event = try calendarService.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                notes: notes,
                calendar: calendar
            )

            // Update task with linked event info
            var updatedTask = task
            updatedTask.linkedEventID = event.eventIdentifier
            updatedTask.calendarItemExternalIdentifier = event.calendarItemExternalIdentifier
            updatedTask.lastSyncedAt = Date()
            updatedTask.scheduledStartTime = startDate
            updatedTask.scheduledEndTime = endDate
            taskService.updateTask(updatedTask)

            recentlyPushedTaskIDs[task.id] = Date()
        } catch {
            print("CalendarSyncService: Failed to create event for task '\(task.title)': \(error)")
        }
    }

    /// Push task changes to its linked event
    private func pushUpdatesToEvent(for task: Task) {
        guard let eventID = task.linkedEventID,
              let event = calendarService.event(withIdentifier: eventID) else { return }

        let title = isBusyOnly ? "Focus Block" : task.title
        let notes = isBusyOnly ? nil : task.notes

        var changed = false

        if event.title != title {
            event.title = title
            changed = true
        }
        if event.notes != notes {
            event.notes = notes
            changed = true
        }

        // Update times — prefer scheduled times, fall back to dueDate/dueTime
        if let start = task.scheduledStartTime, event.startDate != start {
            event.startDate = start
            changed = true
        } else if task.scheduledStartTime == nil,
                  let dueDate = task.dueDate,
                  let dueTime = task.dueTime {
            let cal = Calendar.current
            let dateComps = cal.dateComponents([.year, .month, .day], from: dueDate)
            let timeComps = cal.dateComponents([.hour, .minute], from: dueTime)
            var combined = DateComponents()
            combined.year = dateComps.year
            combined.month = dateComps.month
            combined.day = dateComps.day
            combined.hour = timeComps.hour
            combined.minute = timeComps.minute
            if let start = cal.date(from: combined), event.startDate != start {
                event.startDate = start
                let duration = task.estimatedDuration ?? event.endDate.timeIntervalSince(event.startDate)
                event.endDate = start.addingTimeInterval(duration)
                changed = true
            }
        }
        if let end = task.scheduledEndTime, event.endDate != end {
            event.endDate = end
            changed = true
        }

        guard changed else { return }

        do {
            try calendarService.updateEvent(event)

            var updatedTask = task
            updatedTask.lastSyncedAt = Date()
            updatedTask.calendarItemExternalIdentifier = event.calendarItemExternalIdentifier
            taskService.updateTask(updatedTask)

            recentlyPushedTaskIDs[task.id] = Date()
        } catch {
            print("CalendarSyncService: Failed to push updates for task '\(task.title)': \(error)")
        }
    }

    /// Handle completed task based on completion policy
    private func handleCompletedTask(_ task: Task) {
        switch completionPolicy {
        case .keepEvent:
            // Prefix event title with checkmark
            guard let eventID = task.linkedEventID,
                  let event = calendarService.event(withIdentifier: eventID) else { return }

            let checkPrefix = "\u{2713} "
            if let title = event.title, !title.hasPrefix(checkPrefix) {
                event.title = checkPrefix + title
                try? calendarService.updateEvent(event)
                recentlyPushedTaskIDs[task.id] = Date()
            }

        case .deleteEvent:
            guard let eventID = task.linkedEventID,
                  let event = calendarService.event(withIdentifier: eventID) else { return }

            do {
                try calendarService.deleteEvent(event)

                var updatedTask = task
                updatedTask.linkedEventID = nil
                updatedTask.calendarItemExternalIdentifier = nil
                updatedTask.scheduledStartTime = nil
                updatedTask.scheduledEndTime = nil
                updatedTask.lastSyncedAt = Date()
                taskService.updateTask(updatedTask)

                recentlyPushedTaskIDs[task.id] = Date()
            } catch {
                print("CalendarSyncService: Failed to delete event for completed task '\(task.title)': \(error)")
            }
        }
    }

    // MARK: - Reverse Sync (Event → Task)

    private func performReverseSync() {
        guard calendarService.hasCalendarAccess else { return }

        isSyncing = true
        defer { isSyncing = false }

        let linkedTasks = taskService.tasks.filter { $0.linkedEventID != nil }

        for task in linkedTasks {
            // Skip if recently pushed
            if let pushDate = recentlyPushedTaskIDs[task.id],
               Date().timeIntervalSince(pushDate) < pushCooldown {
                continue
            }

            guard let eventID = task.linkedEventID else { continue }

            if let event = calendarService.event(withIdentifier: eventID) {
                // Event exists — check for changes
                syncEventChangesToTask(event: event, task: task)
            } else if let extID = task.calendarItemExternalIdentifier,
                      let event = calendarService.event(withExternalIdentifier: extID) {
                // eventIdentifier changed (EK store churn) — update link and sync
                var relinkTask = task
                relinkTask.linkedEventID = event.eventIdentifier
                relinkTask.calendarItemExternalIdentifier = event.calendarItemExternalIdentifier
                relinkTask.lastSyncedAt = Date()
                taskService.updateTask(relinkTask)
                syncEventChangesToTask(event: event, task: relinkTask)
            } else {
                // Event was deleted externally
                handleExternallyDeletedEvent(for: task)
            }
        }

        pruneExpiredCooldowns()
    }

    /// Apply event changes back to the task
    private func syncEventChangesToTask(event: EKEvent, task: Task) {
        var updatedTask = task
        var changed = false

        // Update scheduled times if changed
        if let start = event.startDate, task.scheduledStartTime != start {
            updatedTask.scheduledStartTime = start
            updatedTask.dueDate = start
            updatedTask.dueTime = start
            changed = true
        }
        if let end = event.endDate, task.scheduledEndTime != end {
            updatedTask.scheduledEndTime = end
            changed = true
        }

        // Update title (only if not in busy-only mode)
        if !isBusyOnly, let eventTitle = event.title,
           eventTitle != task.title,
           !eventTitle.hasPrefix("\u{2713} ") {
            updatedTask.title = eventTitle
            changed = true
        }

        // Update notes (only if not in busy-only mode)
        if !isBusyOnly, event.notes != task.notes {
            updatedTask.notes = event.notes
            changed = true
        }

        guard changed else { return }

        updatedTask.lastSyncedAt = Date()
        updatedTask.calendarItemExternalIdentifier = event.calendarItemExternalIdentifier
        taskService.updateTask(updatedTask)
    }

    /// Handle an event that was deleted externally
    private func handleExternallyDeletedEvent(for task: Task) {
        var updatedTask = task
        updatedTask.linkedEventID = nil
        updatedTask.calendarItemExternalIdentifier = nil
        updatedTask.scheduledStartTime = nil
        updatedTask.scheduledEndTime = nil
        updatedTask.lastSyncedAt = Date()
        taskService.updateTask(updatedTask)

        // Post notification for UI to show a notice
        NotificationCenter.default.post(
            name: .linkedEventDeletedExternally,
            object: nil,
            userInfo: ["taskTitle": task.title]
        )
    }

    // MARK: - Helpers

    private func pruneExpiredCooldowns() {
        let now = Date()
        recentlyPushedTaskIDs = recentlyPushedTaskIDs.filter { _, date in
            now.timeIntervalSince(date) < pushCooldown
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let linkedEventDeletedExternally = Notification.Name("linkedEventDeletedExternally")
}
