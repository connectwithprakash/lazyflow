import Foundation

/// Frequency options for recurring tasks
enum RecurringFrequency: Int16, CaseIterable, Codable, Identifiable {
    case daily = 0
    case weekly = 1
    case biweekly = 2
    case monthly = 3
    case yearly = 4
    case custom = 5

    var id: Int16 { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }

    var defaultInterval: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 1
        case .biweekly: return 2
        case .monthly: return 1
        case .yearly: return 1
        case .custom: return 1
        }
    }
}

/// Model representing a recurring rule for tasks
struct RecurringRule: Codable, Equatable, Hashable {
    let id: UUID
    var frequency: RecurringFrequency
    var interval: Int
    var daysOfWeek: [Int]?
    var endDate: Date?

    init(
        id: UUID = UUID(),
        frequency: RecurringFrequency,
        interval: Int = 1,
        daysOfWeek: [Int]? = nil,
        endDate: Date? = nil
    ) {
        self.id = id
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.endDate = endDate
    }

    /// Calculate the next occurrence date from a given date
    func nextOccurrence(from date: Date) -> Date? {
        let calendar = Calendar.current

        // Check if we've passed the end date
        if let endDate = endDate, date > endDate {
            return nil
        }

        var nextDate: Date?

        switch frequency {
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: interval, to: date)

        case .weekly:
            if let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty {
                // Find next matching day of week
                nextDate = findNextWeekday(from: date, weekdays: daysOfWeek, calendar: calendar)
            } else {
                nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            }

        case .biweekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 2 * interval, to: date)

        case .monthly:
            nextDate = calendar.date(byAdding: .month, value: interval, to: date)

        case .yearly:
            nextDate = calendar.date(byAdding: .year, value: interval, to: date)

        case .custom:
            nextDate = calendar.date(byAdding: .day, value: interval, to: date)
        }

        // Verify the next date doesn't exceed end date
        if let next = nextDate, let endDate = endDate, next > endDate {
            return nil
        }

        return nextDate
    }

    private func findNextWeekday(from date: Date, weekdays: [Int], calendar: Calendar) -> Date? {
        var currentDate = date

        for _ in 0..<14 { // Check up to 2 weeks ahead
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            let weekday = calendar.component(.weekday, from: currentDate)

            if weekdays.contains(weekday) {
                return currentDate
            }
        }

        return nil
    }

    var displayDescription: String {
        var description = frequency.displayName

        if interval > 1 && frequency != .biweekly {
            description = "Every \(interval) \(frequencyUnit)"
        }

        if let days = daysOfWeek, !days.isEmpty {
            let dayNames = days.compactMap { weekdayName(for: $0) }
            description += " on \(dayNames.joined(separator: ", "))"
        }

        if let endDate = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            description += " until \(formatter.string(from: endDate))"
        }

        return description
    }

    private var frequencyUnit: String {
        switch frequency {
        case .daily: return interval == 1 ? "day" : "days"
        case .weekly, .biweekly: return interval == 1 ? "week" : "weeks"
        case .monthly: return interval == 1 ? "month" : "months"
        case .yearly: return interval == 1 ? "year" : "years"
        case .custom: return interval == 1 ? "day" : "days"
        }
    }

    private func weekdayName(for weekday: Int) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        guard weekday >= 1 && weekday <= 7 else { return nil }
        return formatter.shortWeekdaySymbols[weekday - 1]
    }
}
