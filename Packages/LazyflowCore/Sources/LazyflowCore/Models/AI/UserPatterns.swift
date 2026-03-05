import Foundation

/// User behavior patterns learned from task history
public struct UserPatterns: Codable, Sendable {
    /// Category usage frequency (category -> count)
    public var categoryUsage: [String: Int] = [:]

    /// Time-of-day patterns for categories ("category_hour" -> count)
    public var categoryTimePatterns: [String: Int] = [:]

    /// Day-of-week patterns for categories ("category_dayOfWeek" -> count)
    public var categoryDayPatterns: [String: Int] = [:]

    /// Average duration by category (category -> average minutes)
    public var averageDurations: [String: Int] = [:]

    /// Priority patterns by category (category -> most common priority)
    public var categoryPriorityPatterns: [String: String] = [:]

    /// Last updated timestamp
    public var lastUpdated: Date = Date()

    public init(
        categoryUsage: [String: Int] = [:],
        categoryTimePatterns: [String: Int] = [:],
        categoryDayPatterns: [String: Int] = [:],
        averageDurations: [String: Int] = [:],
        categoryPriorityPatterns: [String: String] = [:],
        lastUpdated: Date = Date()
    ) {
        self.categoryUsage = categoryUsage
        self.categoryTimePatterns = categoryTimePatterns
        self.categoryDayPatterns = categoryDayPatterns
        self.averageDurations = averageDurations
        self.categoryPriorityPatterns = categoryPriorityPatterns
        self.lastUpdated = lastUpdated
    }

    // MARK: - Persistence

    private static let key = "user_patterns"

    public static func load() -> UserPatterns {
        guard let data = UserDefaults.standard.data(forKey: key),
              let patterns = try? JSONDecoder().decode(UserPatterns.self, from: data) else {
            return UserPatterns()
        }
        return patterns
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    // MARK: - Analysis Helpers

    /// Get preferred time of day for a category
    public func preferredTime(for category: String) -> String? {
        let prefix = "\(category.lowercased())_"
        let matching = categoryTimePatterns.filter { $0.key.hasPrefix(prefix) }

        guard let (key, count) = matching.max(by: { $0.value < $1.value }),
              count >= 3 else {
            return nil
        }

        // Extract hour from key (e.g., "work_14" -> 14)
        let hourStr = key.replacingOccurrences(of: prefix, with: "")
        guard let hour = Int(hourStr) else { return nil }

        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "anytime"
        }
    }

    /// Get most used categories (top N)
    public func topCategories(limit: Int = 5) -> [String] {
        categoryUsage
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    /// Get average duration for a category
    public func averageDuration(for category: String) -> Int? {
        averageDurations[category.lowercased()]
    }
}

// MARK: - Pattern Recording

extension UserPatterns {
    /// Record a completed task to learn patterns
    public mutating func recordCompletion(
        category: String,
        priority: String,
        duration: Int?,
        completedAt: Date = Date()
    ) {
        let categoryKey = category.lowercased()

        // Update category usage
        categoryUsage[categoryKey, default: 0] += 1

        // Update time pattern
        let hour = Calendar.current.component(.hour, from: completedAt)
        let timeKey = "\(categoryKey)_\(hour)"
        categoryTimePatterns[timeKey, default: 0] += 1

        // Update day pattern
        let weekday = Calendar.current.component(.weekday, from: completedAt)
        let dayKey = "\(categoryKey)_\(weekday)"
        categoryDayPatterns[dayKey, default: 0] += 1

        // Update priority pattern
        categoryPriorityPatterns[categoryKey] = priority

        // Update average duration
        if let duration = duration, duration > 0 {
            let existing = averageDurations[categoryKey] ?? duration
            averageDurations[categoryKey] = (existing + duration) / 2
        }

        lastUpdated = Date()
    }
}
