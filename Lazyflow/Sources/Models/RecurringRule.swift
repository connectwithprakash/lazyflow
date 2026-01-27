import Foundation

/// Frequency options for recurring tasks
enum RecurringFrequency: Int16, CaseIterable, Codable, Identifiable {
    case daily = 0
    case weekly = 1
    case biweekly = 2
    case monthly = 3
    case yearly = 4
    case custom = 5
    case hourly = 6      // Every N hours within active hours
    case timesPerDay = 7 // X times per day (auto-distributed or specific times)

    var id: Int16 { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        case .hourly: return "Hourly"
        case .timesPerDay: return "Times Per Day"
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
        case .hourly: return 2
        case .timesPerDay: return 3
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

    // Intraday recurring fields
    var hourInterval: Int?        // For .hourly: every N hours (1-12)
    var timesPerDay: Int?         // For .timesPerDay: X times (2-12)
    var specificTimes: [Date]?    // Optional: specific times for timesPerDay
    var activeHoursStart: Date?   // Default: 8:00 AM when used
    var activeHoursEnd: Date?     // Default: 10:00 PM when used

    init(
        id: UUID = UUID(),
        frequency: RecurringFrequency,
        interval: Int = 1,
        daysOfWeek: [Int]? = nil,
        endDate: Date? = nil,
        hourInterval: Int? = nil,
        timesPerDay: Int? = nil,
        specificTimes: [Date]? = nil,
        activeHoursStart: Date? = nil,
        activeHoursEnd: Date? = nil
    ) {
        self.id = id
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.endDate = endDate
        self.hourInterval = hourInterval
        self.timesPerDay = timesPerDay
        self.specificTimes = specificTimes
        self.activeHoursStart = activeHoursStart
        self.activeHoursEnd = activeHoursEnd
    }

    /// Whether this is an intraday recurring rule (hourly or times per day)
    var isIntraday: Bool {
        frequency == .hourly || frequency == .timesPerDay
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

        case .hourly:
            nextDate = nextHourlyOccurrence(from: date, calendar: calendar)

        case .timesPerDay:
            nextDate = nextTimesPerDayOccurrence(from: date, calendar: calendar)
        }

        // Verify the next date doesn't exceed end date
        if let next = nextDate, let endDate = endDate, next > endDate {
            return nil
        }

        return nextDate
    }

    /// Calculate next occurrence for hourly frequency
    private func nextHourlyOccurrence(from date: Date, calendar: Calendar) -> Date? {
        let hours = hourInterval ?? 2

        // If no active hours set, just add hours
        guard let startTime = activeHoursStart, let endTime = activeHoursEnd else {
            return calendar.date(byAdding: .hour, value: hours, to: date)
        }

        let startHour = calendar.component(.hour, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)

        // Calculate next time by adding hours
        guard let candidateDate = calendar.date(byAdding: .hour, value: hours, to: date) else {
            return nil
        }

        let candidateHour = calendar.component(.hour, from: candidateDate)

        // Check if candidate is within active hours
        if candidateHour >= startHour && candidateHour <= endHour {
            return candidateDate
        }

        // If outside active hours, wrap to next day at start time
        var nextDayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        nextDayComponents.day! += 1
        nextDayComponents.hour = startHour
        nextDayComponents.minute = 0
        nextDayComponents.second = 0

        return calendar.date(from: nextDayComponents)
    }

    /// Calculate next occurrence for times-per-day frequency
    private func nextTimesPerDayOccurrence(from date: Date, calendar: Calendar) -> Date? {
        // If specific times are set, find the next one
        if let times = specificTimes, !times.isEmpty {
            return nextSpecificTime(from: date, times: times, calendar: calendar)
        }

        // Auto-distribute times across active hours
        let count = timesPerDay ?? 3

        // Get active hours (default to 8 AM - 8 PM if not set)
        let startHour = activeHoursStart.map { calendar.component(.hour, from: $0) } ?? 8
        let endHour = activeHoursEnd.map { calendar.component(.hour, from: $0) } ?? 20

        let totalHours = endHour - startHour
        let intervalHours = totalHours / count

        // Calculate scheduled hours for today
        var scheduledHours: [Int] = []
        for i in 0..<count {
            scheduledHours.append(startHour + (i * intervalHours))
        }

        let currentHour = calendar.component(.hour, from: date)

        // Find next scheduled hour
        for hour in scheduledHours where hour > currentHour {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = 0
            components.second = 0
            return calendar.date(from: components)
        }

        // All today's times passed, schedule first time tomorrow
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: date)
        tomorrowComponents.day! += 1
        tomorrowComponents.hour = scheduledHours.first ?? startHour
        tomorrowComponents.minute = 0
        tomorrowComponents.second = 0

        return calendar.date(from: tomorrowComponents)
    }

    /// Find the next specific time from the list
    private func nextSpecificTime(from date: Date, times: [Date], calendar: Calendar) -> Date? {
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)

        // Sort times by hour/minute
        let sortedTimes = times.sorted { t1, t2 in
            let h1 = calendar.component(.hour, from: t1)
            let h2 = calendar.component(.hour, from: t2)
            if h1 != h2 { return h1 < h2 }
            return calendar.component(.minute, from: t1) < calendar.component(.minute, from: t2)
        }

        // Find next time today
        for time in sortedTimes {
            let hour = calendar.component(.hour, from: time)
            let minute = calendar.component(.minute, from: time)

            if hour > currentHour || (hour == currentHour && minute > currentMinute) {
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute
                components.second = 0
                return calendar.date(from: components)
            }
        }

        // All times passed today, return first time tomorrow
        if let firstTime = sortedTimes.first {
            var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: date)
            tomorrowComponents.day! += 1
            tomorrowComponents.hour = calendar.component(.hour, from: firstTime)
            tomorrowComponents.minute = calendar.component(.minute, from: firstTime)
            tomorrowComponents.second = 0
            return calendar.date(from: tomorrowComponents)
        }

        return nil
    }

    /// Calculate all intraday times for a given date
    func calculateIntradayTimes(for date: Date) -> [Date] {
        let calendar = Calendar.current
        var times: [Date] = []

        switch frequency {
        case .hourly:
            let hours = hourInterval ?? 2
            let startHour = activeHoursStart.map { calendar.component(.hour, from: $0) } ?? 8
            let endHour = activeHoursEnd.map { calendar.component(.hour, from: $0) } ?? 20

            var currentHour = startHour
            while currentHour <= endHour {
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = currentHour
                components.minute = 0
                components.second = 0
                if let time = calendar.date(from: components) {
                    times.append(time)
                }
                currentHour += hours
            }

        case .timesPerDay:
            if let specificTimes = specificTimes, !specificTimes.isEmpty {
                // Use specific times
                for time in specificTimes {
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    components.hour = calendar.component(.hour, from: time)
                    components.minute = calendar.component(.minute, from: time)
                    components.second = 0
                    if let adjustedTime = calendar.date(from: components) {
                        times.append(adjustedTime)
                    }
                }
            } else {
                // Auto-distribute
                let count = timesPerDay ?? 3
                let startHour = activeHoursStart.map { calendar.component(.hour, from: $0) } ?? 8
                let endHour = activeHoursEnd.map { calendar.component(.hour, from: $0) } ?? 20
                let totalHours = endHour - startHour
                let intervalHours = max(1, totalHours / count)

                for i in 0..<count {
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    components.hour = startHour + (i * intervalHours)
                    components.minute = 0
                    components.second = 0
                    if let time = calendar.date(from: components) {
                        times.append(time)
                    }
                }
            }

        default:
            break
        }

        return times.sorted()
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
        var description: String

        switch frequency {
        case .hourly:
            let hours = hourInterval ?? 2
            description = "Every \(hours) hour\(hours == 1 ? "" : "s")"
        case .timesPerDay:
            let count = timesPerDay ?? 3
            description = "\(count) time\(count == 1 ? "" : "s") per day"
        default:
            description = frequency.displayName
            if interval > 1 && frequency != .biweekly {
                description = "Every \(interval) \(frequencyUnit)"
            }
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

    /// Compact format for display in task cards (e.g., "1d", "1w", "3/wk", "2h", "3x/day")
    var compactDisplayFormat: String {
        switch frequency {
        case .daily:
            return interval == 1 ? "1d" : "\(interval)d"
        case .weekly:
            if let days = daysOfWeek, !days.isEmpty {
                return "\(days.count)/wk"
            }
            return interval == 1 ? "1w" : "\(interval)w"
        case .biweekly:
            return "2w"
        case .monthly:
            return interval == 1 ? "1mo" : "\(interval)mo"
        case .yearly:
            return interval == 1 ? "1y" : "\(interval)y"
        case .custom:
            return "\(interval)d"
        case .hourly:
            let hours = hourInterval ?? 2
            return "\(hours)h"
        case .timesPerDay:
            let count = timesPerDay ?? 3
            return "\(count)x/day"
        }
    }

    private var frequencyUnit: String {
        switch frequency {
        case .daily: return interval == 1 ? "day" : "days"
        case .weekly, .biweekly: return interval == 1 ? "week" : "weeks"
        case .monthly: return interval == 1 ? "month" : "months"
        case .yearly: return interval == 1 ? "year" : "years"
        case .custom: return interval == 1 ? "day" : "days"
        case .hourly: return (hourInterval ?? 2) == 1 ? "hour" : "hours"
        case .timesPerDay: return "day"
        }
    }

    private func weekdayName(for weekday: Int) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        guard weekday >= 1 && weekday <= 7 else { return nil }
        return formatter.shortWeekdaySymbols[weekday - 1]
    }
}
