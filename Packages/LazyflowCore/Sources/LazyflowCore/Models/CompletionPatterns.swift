import Foundation

public struct CompletionPatterns: Codable, Sendable {
    public var lastCompletedCategory: TaskCategory?
    public var lastCompletedTime: Date?
    public var categoryTimePatterns: [String: Int] = [:] // "category_hour" -> count
    public var categoryDayPatterns: [String: Int] = [:]  // "category_dayOfWeek" -> count
    public var averageCompletionTimes: [String: TimeInterval] = [:] // category -> avg time

    private static let key = "completion_patterns"

    public init(
        lastCompletedCategory: TaskCategory? = nil,
        lastCompletedTime: Date? = nil,
        categoryTimePatterns: [String: Int] = [:],
        categoryDayPatterns: [String: Int] = [:],
        averageCompletionTimes: [String: TimeInterval] = [:]
    ) {
        self.lastCompletedCategory = lastCompletedCategory
        self.lastCompletedTime = lastCompletedTime
        self.categoryTimePatterns = categoryTimePatterns
        self.categoryDayPatterns = categoryDayPatterns
        self.averageCompletionTimes = averageCompletionTimes
    }

    public static func load() -> CompletionPatterns {
        guard let data = UserDefaults.standard.data(forKey: key),
              let patterns = try? JSONDecoder().decode(CompletionPatterns.self, from: data) else {
            return CompletionPatterns()
        }
        return patterns
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
