import Foundation
import EventKit

// MARK: - Plan Event Item

/// Wraps a calendar event with selection state for the Plan Your Day flow
struct PlanEventItem: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarColor: CGColor?
    let eventIdentifier: String
    var isSelected: Bool

    /// Duration in seconds
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// Duration in minutes
    var durationMinutes: Int {
        Int(duration / 60)
    }

    /// Formatted time range (e.g., "9:00 AM - 10:30 AM" or "All day")
    var formattedTimeRange: String {
        if isAllDay {
            return "All day"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    /// Formatted start time
    var formattedStartTime: String {
        if isAllDay {
            return "All day"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    /// Formatted duration string (e.g., "30m", "1h 30m")
    var formattedDuration: String {
        if isAllDay { return "All day" }
        let minutes = durationMinutes
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
    }

    /// Heuristic: likely a non-actionable event (all-day, recurring holidays, etc.)
    var isLikelyNonTask: Bool {
        if isAllDay { return true }
        let lowercasedTitle = title.lowercased()
        let nonTaskPatterns = [
            "lunch", "break", "out of office", "ooo",
            "holiday", "vacation", "pto", "birthday",
            "block", "focus time", "do not disturb"
        ]
        return nonTaskPatterns.contains { lowercasedTitle.contains($0) }
    }

    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.location = ekEvent.location
        self.calendarColor = ekEvent.calendar?.cgColor
        self.eventIdentifier = ekEvent.eventIdentifier ?? ""
        // Pre-select timed events that look actionable; deselect all-day and non-task events
        let isTimedEvent = !ekEvent.isAllDay
        let lowercasedTitle = self.title.lowercased()
        let nonTaskPatterns = [
            "lunch", "break", "out of office", "ooo",
            "holiday", "vacation", "pto", "birthday",
            "block", "focus time", "do not disturb"
        ]
        let looksLikeNonTask = self.isAllDay || nonTaskPatterns.contains { lowercasedTitle.contains($0) }
        self.isSelected = isTimedEvent && !looksLikeNonTask
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        calendarColor: CGColor? = nil,
        eventIdentifier: String = "",
        isSelected: Bool = true
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.calendarColor = calendarColor
        self.eventIdentifier = eventIdentifier
        self.isSelected = isSelected
    }
}

// MARK: - Plan Your Day Result

/// Summary of tasks created during the Plan Your Day flow
struct PlanYourDayResult {
    let tasksCreated: Int
    let totalEstimatedMinutes: Int
    let createdAt: Date

    /// Formatted total time (e.g., "2h 30m")
    var formattedTotalTime: String {
        if totalEstimatedMinutes < 60 {
            return "\(totalEstimatedMinutes)m"
        }
        let hours = totalEstimatedMinutes / 60
        let minutes = totalEstimatedMinutes % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    /// Summary text for the completion screen
    var summaryText: String {
        if tasksCreated == 1 {
            return "1 task added to your day"
        }
        return "\(tasksCreated) tasks added to your day"
    }
}
