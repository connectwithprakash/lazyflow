import Foundation

/// Unified context for AI suggestions combining all available signals
struct AIContext {
    /// Recent tasks for consistency (last 5-10 tasks)
    let recentTasks: [RecentTaskContext]

    /// User's behavioral patterns
    let userPatterns: UserPatterns

    /// User's correction history summary
    let correctionsSummary: String

    /// Custom categories available
    let customCategories: [String]

    /// Current time context
    let timeContext: TimeContext

    /// Task-specific context (if analyzing a specific task)
    let taskContext: TaskSpecificContext?

    // MARK: - Nested Types

    struct RecentTaskContext {
        let title: String
        let category: String
        let priority: String
        let duration: Int?
        let completedAt: Date?
    }

    struct TimeContext {
        let currentHour: Int
        let dayOfWeek: Int
        let isWeekend: Bool
        let timeOfDay: String // "morning", "afternoon", "evening"

        init(date: Date = Date()) {
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

    struct TaskSpecificContext {
        let title: String
        let notes: String?
        let dueDate: Date?
        let currentPriority: String
    }

    // MARK: - Prompt Generation

    /// Generate context string for LLM prompts
    func toPromptString() -> String {
        var context = ""

        // Time context
        context += "Current time: \(timeContext.timeOfDay)"
        if timeContext.isWeekend {
            context += " (weekend)"
        }
        context += "\n"

        // User patterns
        let topCategories = userPatterns.topCategories(limit: 3)
        if !topCategories.isEmpty {
            context += "Most used categories: \(topCategories.joined(separator: ", "))\n"
        }

        // Time preferences
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
    static var empty: AIContext {
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
