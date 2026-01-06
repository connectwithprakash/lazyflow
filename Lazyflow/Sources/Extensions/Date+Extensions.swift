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
        guard let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today) else {
            return false
        }
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
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
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

// MARK: - Natural Language Date Parsing

extension Date {
    /// Result of parsing natural language date text
    struct ParsedDateResult {
        let date: Date
        let time: Date?
        let matchedRange: Range<String.Index>
        let matchedText: String

        /// The task title with the date portion removed
        func cleanedTitle(from original: String) -> String {
            var cleaned = original
            cleaned.removeSubrange(matchedRange)
            // Clean up extra whitespace
            return cleaned.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "  ", with: " ")
        }
    }

    /// Parse natural language date from text using NSDataDetector
    /// Supports: "tomorrow", "next Friday", "3pm", "January 15", etc.
    static func parse(from text: String) -> ParsedDateResult? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        // Find the best match (prefer ones with actual dates over just times)
        for match in matches {
            guard let matchRange = Range(match.range, in: text),
                  let date = match.date else { continue }

            let matchedText = String(text[matchRange])
            let calendar = Calendar.current

            // Check if this is a time-only match (hours/minutes but same date as now)
            let now = Date()
            let isSameDay = calendar.isDate(date, inSameDayAs: now)
            let hasTimeInfo = calendar.component(.hour, from: date) != 0 ||
                              calendar.component(.minute, from: date) != 0

            // If it's today with specific time, treat as time-only
            if isSameDay && hasTimeInfo {
                return ParsedDateResult(
                    date: now,
                    time: date,
                    matchedRange: matchRange,
                    matchedText: matchedText
                )
            }

            // Has date info - return full result
            return ParsedDateResult(
                date: date,
                time: hasTimeInfo ? date : nil,
                matchedRange: matchRange,
                matchedText: matchedText
            )
        }

        // Try manual parsing for common phrases not caught by NSDataDetector
        return parseCommonPhrases(from: text)
    }

    /// Parse common natural language phrases manually
    private static func parseCommonPhrases(from text: String) -> ParsedDateResult? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let today = Date()

        // Patterns to check with their date offsets
        let patterns: [(pattern: String, dayOffset: Int)] = [
            ("today", 0),
            ("tonight", 0),
            ("tomorrow", 1),
            ("day after tomorrow", 2),
            ("next week", 7),
            ("in a week", 7),
            ("end of week", calendar.component(.weekday, from: today) == 1 ? 0 :
                           (8 - calendar.component(.weekday, from: today)))
        ]

        for (pattern, offset) in patterns {
            if let range = lowercased.range(of: pattern) {
                guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

                // Convert range to original string's range
                let start = text.index(text.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.lowerBound))
                let end = text.index(text.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.upperBound))
                let originalRange = start..<end

                return ParsedDateResult(
                    date: date,
                    time: pattern == "tonight" ? calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date) : nil,
                    matchedRange: originalRange,
                    matchedText: String(text[originalRange])
                )
            }
        }

        // Check for "next [weekday]" pattern
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, weekday) in weekdays.enumerated() {
            if let range = lowercased.range(of: "next \(weekday)") {
                let targetWeekday = index + 1 // Calendar weekdays are 1-indexed
                let currentWeekday = calendar.component(.weekday, from: today)
                var daysToAdd = targetWeekday - currentWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                daysToAdd += 7 // "next" means next week's occurrence

                guard let date = calendar.date(byAdding: .day, value: daysToAdd, to: today) else { continue }

                let start = text.index(text.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.lowerBound))
                let end = text.index(text.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.upperBound))

                return ParsedDateResult(
                    date: date,
                    time: nil,
                    matchedRange: start..<end,
                    matchedText: String(text[start..<end])
                )
            }
        }

        return nil
    }
}

// MARK: - Date Range Helpers

extension Date {
    /// Get dates for the current week
    static var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) else {
            return [today]
        }

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
