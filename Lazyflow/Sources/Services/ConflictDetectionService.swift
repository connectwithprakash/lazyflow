import Foundation
import EventKit
import Combine

/// Service for detecting conflicts between tasks and calendar events
final class ConflictDetectionService: ObservableObject {
    static let shared = ConflictDetectionService()

    // MARK: - Dependencies

    private let calendarService: CalendarService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published private(set) var detectedConflicts: [TaskConflict] = []
    @Published private(set) var lastScanDate: Date?

    private init(calendarService: CalendarService = .shared) {
        self.calendarService = calendarService
    }

    // MARK: - Conflict Detection

    /// Scan all tasks for calendar conflicts
    func scanForConflicts(tasks: [Task]) -> [TaskConflict] {
        guard calendarService.hasCalendarAccess else { return [] }

        var conflicts: [TaskConflict] = []
        let now = Date()

        // Only check incomplete tasks with scheduled times
        let scheduledTasks = tasks.filter { task in
            !task.isCompleted &&
            !task.isArchived &&
            task.linkedEventID != nil || (task.dueDate != nil && task.dueTime != nil)
        }

        for task in scheduledTasks {
            if let conflict = detectConflict(for: task) {
                conflicts.append(conflict)
            }
        }

        // Also check for task-to-task conflicts (overlapping scheduled times)
        let taskTaskConflicts = detectTaskToTaskConflicts(scheduledTasks)
        conflicts.append(contentsOf: taskTaskConflicts)

        // Sort by severity and time
        conflicts.sort { conflict1, conflict2 in
            if conflict1.severity != conflict2.severity {
                return conflict1.severity.rawValue > conflict2.severity.rawValue
            }
            return conflict1.conflictTime < conflict2.conflictTime
        }

        // Ensure UI updates happen on main thread to prevent UICollectionView crashes
        if Thread.isMainThread {
            detectedConflicts = conflicts
            lastScanDate = now
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.detectedConflicts = conflicts
                self?.lastScanDate = now
            }
        }

        return conflicts
    }

    /// Detect conflict for a specific task
    func detectConflict(for task: Task) -> TaskConflict? {
        guard let taskStartTime = getTaskStartTime(task) else { return nil }

        let duration = task.estimatedDuration ?? 1800 // Default 30 min
        let taskEndTime = taskStartTime.addingTimeInterval(duration)

        // Check if task time is in the past
        if taskEndTime < Date() {
            return nil // Don't flag past conflicts
        }

        // Fetch calendar events around the task time
        let windowStart = Calendar.current.date(byAdding: .hour, value: -1, to: taskStartTime) ?? taskStartTime
        let windowEnd = Calendar.current.date(byAdding: .hour, value: 1, to: taskEndTime) ?? taskEndTime

        let events = calendarService.fetchEvents(from: windowStart, to: windowEnd)

        for event in events {
            // Skip the task's own linked event
            if let linkedID = task.linkedEventID, event.eventIdentifier == linkedID {
                continue
            }

            // Skip all-day events
            if event.isAllDay {
                continue
            }

            // Check for overlap
            let overlap = calculateOverlap(
                start1: taskStartTime, end1: taskEndTime,
                start2: event.startDate, end2: event.endDate
            )

            if overlap > 0 {
                let severity = calculateSeverity(overlap: overlap, taskDuration: duration, event: event)

                return TaskConflict(
                    id: UUID(),
                    task: task,
                    conflictingEvent: CalendarEvent(from: event),
                    conflictTime: max(taskStartTime, event.startDate),
                    overlapDuration: overlap,
                    severity: severity,
                    type: .calendarEvent
                )
            }
        }

        return nil
    }

    /// Detect conflicts between tasks themselves
    private func detectTaskToTaskConflicts(_ tasks: [Task]) -> [TaskConflict] {
        var conflicts: [TaskConflict] = []

        for i in 0..<tasks.count {
            for j in (i + 1)..<tasks.count {
                let task1 = tasks[i]
                let task2 = tasks[j]

                guard let start1 = getTaskStartTime(task1),
                      let start2 = getTaskStartTime(task2) else { continue }

                let duration1 = task1.estimatedDuration ?? 1800
                let duration2 = task2.estimatedDuration ?? 1800

                let end1 = start1.addingTimeInterval(duration1)
                let end2 = start2.addingTimeInterval(duration2)

                let overlap = calculateOverlap(start1: start1, end1: end1, start2: start2, end2: end2)

                if overlap > 0 {
                    let severity: ConflictSeverity = overlap > min(duration1, duration2) / 2 ? .high : .medium

                    conflicts.append(TaskConflict(
                        id: UUID(),
                        task: task1,
                        conflictingTask: task2,
                        conflictTime: max(start1, start2),
                        overlapDuration: overlap,
                        severity: severity,
                        type: .taskOverlap
                    ))
                }
            }
        }

        return conflicts
    }

    // MARK: - Meeting Detection

    /// Detect if a new meeting was added that conflicts with existing tasks
    func detectNewMeetingConflicts(event: EKEvent, tasks: [Task]) -> [TaskConflict] {
        var conflicts: [TaskConflict] = []

        for task in tasks where !task.isCompleted && !task.isArchived {
            guard let taskStart = getTaskStartTime(task) else { continue }

            let taskDuration = task.estimatedDuration ?? 1800
            let taskEnd = taskStart.addingTimeInterval(taskDuration)

            let overlap = calculateOverlap(
                start1: taskStart, end1: taskEnd,
                start2: event.startDate, end2: event.endDate
            )

            if overlap > 0 {
                let severity = calculateSeverity(overlap: overlap, taskDuration: taskDuration, event: event)

                conflicts.append(TaskConflict(
                    id: UUID(),
                    task: task,
                    conflictingEvent: CalendarEvent(from: event),
                    conflictTime: max(taskStart, event.startDate),
                    overlapDuration: overlap,
                    severity: severity,
                    type: .newMeeting
                ))
            }
        }

        return conflicts
    }

    // MARK: - Helpers

    private func getTaskStartTime(_ task: Task) -> Date? {
        // If task has a linked event, use that event's time
        if let linkedID = task.linkedEventID,
           let event = calendarService.event(withIdentifier: linkedID) {
            return event.startDate
        }

        // If task has both due date and time, combine them
        if let dueDate = task.dueDate, let dueTime = task.dueTime {
            return combineDateAndTime(date: dueDate, time: dueTime)
        }

        // If task only has due date, use it (but this is less precise)
        return task.dueDate
    }

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

    private func calculateOverlap(start1: Date, end1: Date, start2: Date, end2: Date) -> TimeInterval {
        let overlapStart = max(start1, start2)
        let overlapEnd = min(end1, end2)

        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }

    private func calculateSeverity(overlap: TimeInterval, taskDuration: TimeInterval, event: EKEvent) -> ConflictSeverity {
        let overlapPercentage = overlap / taskDuration

        // High severity: significant overlap or with important meetings
        if overlapPercentage > 0.5 {
            return .high
        }

        // Check if event might be important (has attendees, is recurring, etc.)
        if event.hasAttendees || event.hasRecurrenceRules {
            return overlapPercentage > 0.25 ? .high : .medium
        }

        if overlapPercentage > 0.25 {
            return .medium
        }

        return .low
    }

    // MARK: - Real-time Monitoring

    /// Start monitoring for calendar changes
    func startMonitoring(tasks: [Task]) {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                _ = self?.scanForConflicts(tasks: tasks)
            }
            .store(in: &cancellables)
    }

    /// Stop monitoring
    func stopMonitoring() {
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

struct TaskConflict: Identifiable {
    let id: UUID
    let task: Task
    var conflictingEvent: CalendarEvent?
    var conflictingTask: Task?
    let conflictTime: Date
    let overlapDuration: TimeInterval
    let severity: ConflictSeverity
    let type: ConflictType

    var formattedOverlap: String {
        let minutes = Int(overlapDuration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m overlap"
            }
            return "\(hours)h overlap"
        }
        return "\(minutes)m overlap"
    }

    var conflictDescription: String {
        switch type {
        case .calendarEvent:
            return "Conflicts with \"\(conflictingEvent?.title ?? "calendar event")\""
        case .taskOverlap:
            return "Overlaps with \"\(conflictingTask?.title ?? "another task")\""
        case .newMeeting:
            return "New meeting \"\(conflictingEvent?.title ?? "")\" conflicts"
        }
    }
}

enum ConflictSeverity: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: ConflictSeverity, rhs: ConflictSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        }
    }

    var systemImage: String {
        switch self {
        case .low: return "exclamationmark.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        }
    }
}

enum ConflictType {
    case calendarEvent   // Task conflicts with existing calendar event
    case taskOverlap     // Two tasks overlap
    case newMeeting      // New meeting added that conflicts with task
}
