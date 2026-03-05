import Foundation

/// Unified context for AI suggestions combining all available signals
public struct AIContext {
    /// Recent tasks for consistency (last 5-10 tasks)
    public let recentTasks: [RecentTaskContext]

    /// User's behavioral patterns
    public let userPatterns: UserPatterns

    /// User's correction history summary
    public let correctionsSummary: String

    /// Custom categories available
    public let customCategories: [String]

    /// Current time context
    public let timeContext: TimeContext

    /// Task-specific context (if analyzing a specific task)
    public let taskContext: TaskSpecificContext?

    public init(
        recentTasks: [RecentTaskContext],
        userPatterns: UserPatterns,
        correctionsSummary: String,
        customCategories: [String],
        timeContext: TimeContext,
        taskContext: TaskSpecificContext?
    ) {
        self.recentTasks = recentTasks
        self.userPatterns = userPatterns
        self.correctionsSummary = correctionsSummary
        self.customCategories = customCategories
        self.timeContext = timeContext
        self.taskContext = taskContext
    }

    // MARK: - Nested Types

    public struct RecentTaskContext {
        public let title: String
        public let category: String
        public let priority: String
        public let duration: Int?
        public let completedAt: Date?

        public init(title: String, category: String, priority: String, duration: Int?, completedAt: Date?) {
            self.title = title
            self.category = category
            self.priority = priority
            self.duration = duration
            self.completedAt = completedAt
        }
    }

    public struct TimeContext {
        public let currentHour: Int
        public let dayOfWeek: Int
        public let isWeekend: Bool
        public let timeOfDay: String // "morning", "afternoon", "evening"

        public init(date: Date = Date()) {
            let calendar = Calendar.current
            self.currentHour = calendar.component(.hour, from: date)
            self.dayOfWeek = calendar.component(.weekday, from: date)
            self.isWeekend = dayOfWeek == 1 || dayOfWeek == 7

            switch currentHour {
            case 5..<12: self.timeOfDay = "morning"
            case 12..<17: self.timeOfDay = "afternoon"
            case 17..<21: self.timeOfDay = "evening"
            default: self.timeOfDay = "night"
            }
        }
    }

    public struct TaskSpecificContext {
        public let title: String
        public let notes: String?
        public let dueDate: Date?
        public let currentPriority: String

        public init(title: String, notes: String?, dueDate: Date?, currentPriority: String) {
            self.title = title
            self.notes = notes
            self.dueDate = dueDate
            self.currentPriority = currentPriority
        }
    }

    // MARK: - Prompt Generation

    /// Generate context string for LLM prompts
    public func toPromptString() -> String {
        var context = ""

        // Time context
        context += "Current time: \(timeContext.timeOfDay)"
        if timeContext.isWeekend {
            context += " (weekend)"
        }
        context += "\n"

        // User patterns - categories with details
        let topCategories = userPatterns.topCategories(limit: 3)
        if !topCategories.isEmpty {
            context += "Most used categories: \(topCategories.joined(separator: ", "))\n"

            // Add duration and time patterns for top categories
            for category in topCategories {
                var details: [String] = []

                if let avgDuration = userPatterns.averageDuration(for: category) {
                    details.append("avg \(avgDuration) min")
                }

                if let preferredTime = userPatterns.preferredTime(for: category) {
                    details.append("usually \(preferredTime)")
                }

                if !details.isEmpty {
                    context += "  - \(category): \(details.joined(separator: ", "))\n"
                }
            }
        }

        // Task-specific keyword matching
        if let taskContext = taskContext {
            let keywords = AICorrection.extractKeywords(from: taskContext.title)
            for keyword in keywords {
                if let preferredTime = userPatterns.preferredTime(for: keyword) {
                    context += "Tasks with '\(keyword)' usually done in: \(preferredTime)\n"
                    break
                }
            }
        }

        // Recent tasks for consistency
        if !recentTasks.isEmpty {
            context += "\nRecent tasks for consistency:\n"
            for task in recentTasks.prefix(3) {
                context += "- \"\(task.title)\" -> \(task.category)"
                if let duration = task.duration {
                    context += ", \(duration) min"
                }
                context += "\n"
            }
        }

        // Corrections summary
        if !correctionsSummary.isEmpty && correctionsSummary != "No user preferences learned yet." {
            context += "\n\(correctionsSummary)"
        }

        // Custom categories
        if !customCategories.isEmpty {
            context += "\nUser's custom categories: \(customCategories.joined(separator: ", "))\n"
        }

        return context.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Default Context

extension AIContext {
    /// Create empty context when no data available
    public static var empty: AIContext {
        AIContext(
            recentTasks: [],
            userPatterns: UserPatterns(),
            correctionsSummary: "",
            customCategories: [],
            timeContext: TimeContext(),
            taskContext: nil
        )
    }
}
