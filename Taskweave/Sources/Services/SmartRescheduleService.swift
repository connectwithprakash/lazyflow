import Foundation
import EventKit
import Combine

/// Service for intelligent task rescheduling suggestions
final class SmartRescheduleService: ObservableObject {
    static let shared = SmartRescheduleService()

    // MARK: - Dependencies

    private let calendarService: CalendarService
    private let conflictService: ConflictDetectionService
    private let prioritizationService: PrioritizationService

    // MARK: - Published Properties

    @Published private(set) var pendingReschedules: [RescheduleRequest] = []

    private init(
        calendarService: CalendarService = .shared,
        conflictService: ConflictDetectionService = .shared,
        prioritizationService: PrioritizationService = .shared
    ) {
        self.calendarService = calendarService
        self.conflictService = conflictService
        self.prioritizationService = prioritizationService
    }

    // MARK: - Reschedule Suggestions

    /// Generate reschedule suggestions for a conflicting task
    func suggestReschedule(for conflict: TaskConflict) -> RescheduleSuggestion {
        let task = conflict.task
        let duration = task.estimatedDuration ?? 1800

        var options: [RescheduleOption] = []

        // Option 1: Right after the conflicting event
        if let event = conflict.conflictingEvent {
            let afterEventTime = event.endDate.addingTimeInterval(900) // 15 min buffer
            if isSlotAvailable(start: afterEventTime, duration: duration) {
                options.append(RescheduleOption(
                    id: UUID(),
                    suggestedTime: afterEventTime,
                    type: .afterConflict,
                    reason: "Right after \"\(event.title)\" ends",
                    score: calculateOptionScore(time: afterEventTime, task: task, type: .afterConflict)
                ))
            }
        }

        // Option 2: Earlier today (before conflict)
        if let earlierSlot = findEarlierSlot(before: conflict.conflictTime, duration: duration) {
            options.append(RescheduleOption(
                id: UUID(),
                suggestedTime: earlierSlot,
                type: .earlierToday,
                reason: "Earlier today before the conflict",
                score: calculateOptionScore(time: earlierSlot, task: task, type: .earlierToday)
            ))
        }

        // Option 3: Next available slot today
        if let nextSlot = findNextAvailableSlot(after: Date(), duration: duration, sameDay: true) {
            if !options.contains(where: { isSameTimeSlot($0.suggestedTime, nextSlot) }) {
                options.append(RescheduleOption(
                    id: UUID(),
                    suggestedTime: nextSlot,
                    type: .nextAvailable,
                    reason: "Next available time today",
                    score: calculateOptionScore(time: nextSlot, task: task, type: .nextAvailable)
                ))
            }
        }

        // Option 4: Push to tomorrow (same time)
        if let tomorrowSameTime = pushToTomorrow(from: conflict.conflictTime) {
            let adjustedTime = adjustForCalendarConflicts(tomorrowSameTime, duration: duration)
            options.append(RescheduleOption(
                id: UUID(),
                suggestedTime: adjustedTime,
                type: .tomorrow,
                reason: "Tomorrow at \(formatTime(adjustedTime))",
                score: calculateOptionScore(time: adjustedTime, task: task, type: .tomorrow)
            ))
        }

        // Option 5: Next free slot in the week
        if let weekSlot = findNextAvailableSlot(after: Date(), duration: duration, sameDay: false) {
            if !options.contains(where: { isSameTimeSlot($0.suggestedTime, weekSlot) }) {
                options.append(RescheduleOption(
                    id: UUID(),
                    suggestedTime: weekSlot,
                    type: .nextAvailable,
                    reason: "Next free slot: \(formatDateTime(weekSlot))",
                    score: calculateOptionScore(time: weekSlot, task: task, type: .nextAvailable)
                ))
            }
        }

        // Sort by score (higher is better)
        options.sort { $0.score > $1.score }

        // Determine best option
        let bestOption = options.first

        return RescheduleSuggestion(
            conflict: conflict,
            options: options,
            recommendedOption: bestOption,
            urgency: determineUrgency(conflict: conflict, task: task)
        )
    }

    /// Generate reschedule suggestions for multiple conflicts (batch)
    func suggestBatchReschedule(for conflicts: [TaskConflict]) -> BatchRescheduleSuggestion {
        var suggestions: [RescheduleSuggestion] = []
        var totalConflicts = conflicts.count

        // Sort conflicts by priority of the task (higher priority first)
        let sortedConflicts = conflicts.sorted { conflict1, conflict2 in
            let score1 = prioritizationService.calculatePriorityScore(for: conflict1.task)
            let score2 = prioritizationService.calculatePriorityScore(for: conflict2.task)
            return score1 > score2
        }

        for conflict in sortedConflicts {
            let suggestion = suggestReschedule(for: conflict)
            suggestions.append(suggestion)
        }

        return BatchRescheduleSuggestion(
            suggestions: suggestions,
            totalConflicts: totalConflicts,
            canAutoResolve: suggestions.allSatisfy { $0.recommendedOption != nil }
        )
    }

    // MARK: - Apply Reschedule

    /// Apply a reschedule option to a task
    func applyReschedule(option: RescheduleOption, to task: Task, taskService: TaskService) -> Task {
        var updatedTask = task

        // Update due date/time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: option.suggestedTime)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: option.suggestedTime)

        updatedTask.dueDate = calendar.date(from: dateComponents)
        updatedTask.dueTime = calendar.date(from: DateComponents(
            hour: timeComponents.hour,
            minute: timeComponents.minute
        ))

        // Update linked calendar event if exists
        if let linkedID = task.linkedEventID,
           let event = calendarService.event(withIdentifier: linkedID) {
            event.startDate = option.suggestedTime
            event.endDate = option.suggestedTime.addingTimeInterval(task.estimatedDuration ?? 1800)
            try? calendarService.updateEvent(event)
        }

        taskService.updateTask(updatedTask)

        // Remove from pending
        pendingReschedules.removeAll { $0.task.id == task.id }

        return updatedTask
    }

    /// Apply batch reschedule (auto-resolve all)
    func applyBatchReschedule(batch: BatchRescheduleSuggestion, taskService: TaskService) -> [Task] {
        var updatedTasks: [Task] = []

        for suggestion in batch.suggestions {
            if let option = suggestion.recommendedOption {
                let updated = applyReschedule(option: option, to: suggestion.conflict.task, taskService: taskService)
                updatedTasks.append(updated)
            }
        }

        return updatedTasks
    }

    // MARK: - Push to Tomorrow

    /// Quick action to push task to tomorrow
    func pushTaskToTomorrow(_ task: Task, taskService: TaskService) -> Task {
        var updatedTask = task
        let calendar = Calendar.current

        let currentDate = task.dueDate ?? Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate

        // Preserve the time if set
        if let currentTime = task.dueTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: currentTime)
            if let tomorrowWithTime = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                                      minute: timeComponents.minute ?? 0,
                                                      second: 0,
                                                      of: tomorrow) {
                updatedTask.dueDate = calendar.startOfDay(for: tomorrow)
                updatedTask.dueTime = tomorrowWithTime
            }
        } else {
            updatedTask.dueDate = calendar.startOfDay(for: tomorrow)
        }

        // Update linked calendar event
        if let linkedID = task.linkedEventID,
           let event = calendarService.event(withIdentifier: linkedID) {
            let duration = task.estimatedDuration ?? event.endDate.timeIntervalSince(event.startDate)
            let newStart = updatedTask.dueTime ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
            event.startDate = newStart
            event.endDate = newStart.addingTimeInterval(duration)
            try? calendarService.updateEvent(event)
        }

        taskService.updateTask(updatedTask)
        return updatedTask
    }

    // MARK: - Private Helpers

    private func findEarlierSlot(before time: Date, duration: TimeInterval) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: time)

        // Start from 7 AM
        guard let workStart = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay) else {
            return nil
        }

        let slots = calendarService.findAvailableSlots(on: time, duration: duration, workingHoursStart: 7, workingHoursEnd: 22)

        // Find a slot that ends before the conflict time
        for slot in slots {
            let potentialEnd = slot.start.addingTimeInterval(duration)
            if potentialEnd <= time && slot.start >= Date() {
                return slot.start
            }
        }

        return nil
    }

    private func findNextAvailableSlot(after time: Date, duration: TimeInterval, sameDay: Bool) -> Date? {
        let calendar = Calendar.current
        let maxDays = sameDay ? 0 : 7

        for dayOffset in 0...maxDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: time) else { continue }

            let searchStart = dayOffset == 0 ? max(time, Date()) : calendar.startOfDay(for: date)
            let slots = calendarService.findAvailableSlots(on: date, duration: duration, workingHoursStart: 7, workingHoursEnd: 22)

            for slot in slots {
                if slot.start >= searchStart {
                    return slot.start
                }
            }
        }

        return nil
    }

    private func pushToTomorrow(from time: Date) -> Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: time)
    }

    private func adjustForCalendarConflicts(_ time: Date, duration: TimeInterval) -> Date {
        let events = calendarService.fetchEvents(for: time)

        for event in events {
            if time >= event.startDate && time < event.endDate {
                // Conflict - move to after the event
                return event.endDate.addingTimeInterval(900)
            }
        }

        return time
    }

    private func isSlotAvailable(start: Date, duration: TimeInterval) -> Bool {
        guard start >= Date() else { return false }

        let end = start.addingTimeInterval(duration)
        let events = calendarService.fetchEvents(from: start, to: end)

        return events.isEmpty
    }

    private func isSameTimeSlot(_ time1: Date, _ time2: Date) -> Bool {
        abs(time1.timeIntervalSince(time2)) < 300 // Within 5 minutes
    }

    private func calculateOptionScore(time: Date, task: Task, type: RescheduleType) -> Double {
        var score: Double = 50.0

        // Prefer sooner times (but not too soon)
        let hoursFromNow = time.timeIntervalSince(Date()) / 3600
        if hoursFromNow >= 0.5 && hoursFromNow <= 4 {
            score += 20 // Sweet spot
        } else if hoursFromNow > 4 && hoursFromNow <= 24 {
            score += 10
        }

        // Type preferences
        switch type {
        case .afterConflict:
            score += 15 // Minimal disruption
        case .earlierToday:
            score += 10
        case .nextAvailable:
            score += 5
        case .tomorrow:
            // Penalize if task has urgent/high priority
            if task.priority == .urgent {
                score -= 20
            } else if task.priority == .high {
                score -= 10
            } else {
                score += 5
            }
        }

        // Prefer times during productive hours (9-17)
        let hour = Calendar.current.component(.hour, from: time)
        if hour >= 9 && hour <= 17 {
            score += 10
        }

        // Check if time aligns with learned patterns
        let categoryKey = "\(task.category.rawValue)_\(hour)"
        let patterns = prioritizationService.completionPatterns
        if let patternCount = patterns.categoryTimePatterns[categoryKey], patternCount > 0 {
            score += Double(min(patternCount, 10)) // Bonus for matching patterns
        }

        return score
    }

    private func determineUrgency(conflict: TaskConflict, task: Task) -> RescheduleUrgency {
        // High urgency if conflict is imminent
        let minutesUntilConflict = conflict.conflictTime.timeIntervalSince(Date()) / 60

        if minutesUntilConflict < 30 {
            return .immediate
        }

        if minutesUntilConflict < 120 || task.priority == .urgent {
            return .high
        }

        if task.priority == .high || conflict.severity == .high {
            return .medium
        }

        return .low
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct RescheduleSuggestion {
    let conflict: TaskConflict
    let options: [RescheduleOption]
    let recommendedOption: RescheduleOption?
    let urgency: RescheduleUrgency
}

struct RescheduleOption: Identifiable {
    let id: UUID
    let suggestedTime: Date
    let type: RescheduleType
    let reason: String
    let score: Double

    var formattedTime: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(suggestedTime) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: suggestedTime))"
        } else if calendar.isDateInTomorrow(suggestedTime) {
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: suggestedTime))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: suggestedTime)
        }
    }
}

enum RescheduleType {
    case afterConflict  // Right after the conflicting event
    case earlierToday   // Earlier slot today
    case nextAvailable  // Next available slot
    case tomorrow       // Push to tomorrow
}

enum RescheduleUrgency {
    case immediate  // Conflict in < 30 min
    case high       // Conflict in < 2 hours or urgent task
    case medium     // High priority task or severe conflict
    case low        // Normal

    var displayName: String {
        switch self {
        case .immediate: return "Act Now"
        case .high: return "Soon"
        case .medium: return "When Convenient"
        case .low: return "Optional"
        }
    }

    var color: String {
        switch self {
        case .immediate: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "gray"
        }
    }
}

struct BatchRescheduleSuggestion {
    let suggestions: [RescheduleSuggestion]
    let totalConflicts: Int
    let canAutoResolve: Bool

    var resolvedCount: Int {
        suggestions.filter { $0.recommendedOption != nil }.count
    }
}

struct RescheduleRequest: Identifiable {
    let id: UUID
    let task: Task
    let suggestion: RescheduleSuggestion
    let createdAt: Date
}
