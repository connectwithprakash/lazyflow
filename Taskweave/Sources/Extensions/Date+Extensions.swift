import Foundation

extension Date {
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is in the past (before today)
    var isPast: Bool {
        self < Calendar.current.startOfDay(for: Date())
    }

    /// Check if date is within the current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is within the next 7 days
    var isWithinNextWeek: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        return self >= today && self <= weekFromNow
    }

    /// Start of the day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the day (23:59:59)
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }

    /// Formatted relative date string
    var relativeFormatted: String {
        if isToday {
            return "Today"
        } else if isTomorrow {
            return "Tomorrow"
        } else if isYesterday {
            return "Yesterday"
        } else if isThisWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Full day name
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: self)
        }
    }

    /// Short formatted date (e.g., "Dec 29")
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    /// Full formatted date (e.g., "December 29, 2025")
    var fullFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: self)
    }

    /// Time only formatted (e.g., "3:30 PM")
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Date and time formatted (e.g., "Dec 29, 3:30 PM")
    var dateTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: self)
    }

    /// Add days to date
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Add hours to date
    func addingHours(_ hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    /// Add minutes to date
    func addingMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    /// Get the weekday (1 = Sunday, 7 = Saturday)
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// Get the weekday name
    var weekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    /// Get short weekday name (e.g., "Mon")
    var shortWeekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    /// Days until this date from today
    var daysFromToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: self)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    /// Create date from components
    static func from(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }

    /// Combine date with time from another date
    func withTime(from time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second

        return calendar.date(from: combined) ?? self
    }
}

// MARK: - Date Range Helpers

extension Date {
    /// Get dates for the current week
    static var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!

        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }

    /// Get dates for the next N days
    static func nextDays(_ count: Int) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<count).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: today)
        }
    }
}
