import Foundation
import Combine

/// Service for generating daily summaries and managing productivity streaks
final class DailySummaryService: ObservableObject {
    static let shared = DailySummaryService()

    // MARK: - Published Properties

    @Published private(set) var todaySummary: DailySummaryData?
    @Published private(set) var streakData: StreakData
    @Published private(set) var isGeneratingSummary: Bool = false
    @Published private(set) var summaryHistory: [DailySummaryData] = []

    // MARK: - Dependencies

    private let taskService: TaskService
    private let llmService: LLMService

    // MARK: - UserDefaults Keys

    private static let summaryHistoryKey = "daily_summary_history"
    private static let lastSummaryDateKey = "last_summary_date"

    // MARK: - Initialization

    init(taskService: TaskService = .shared, llmService: LLMService = .shared) {
        self.taskService = taskService
        self.llmService = llmService
        self.streakData = StreakData.load()
        self.summaryHistory = Self.loadSummaryHistory()
    }

    // MARK: - Summary Generation

    /// Generate a summary for a specific date
    func generateSummary(for date: Date = Date()) async -> DailySummaryData {
        await MainActor.run { isGeneratingSummary = true }
        defer {
            _Concurrency.Task { @MainActor in
                isGeneratingSummary = false
            }
        }

        // Fetch completed tasks for the date
        let completedTasks = taskService.fetchTasksCompletedOn(date: date)
        let plannedTasks = taskService.fetchTasksDueOn(date: date)

        // Create task summaries
        let taskSummaries = completedTasks.map { CompletedTaskSummary(from: $0) }

        // Calculate top category
        let topCategory = calculateTopCategory(from: completedTasks)

        // Calculate total minutes worked
        let totalMinutes = calculateTotalMinutesWorked(from: completedTasks)

        // Calculate productivity score
        let productivityScore = calculateProductivityScore(
            completed: completedTasks.count,
            planned: plannedTasks.count
        )

        // Create initial summary without AI content
        var summary = DailySummaryData(
            date: date,
            tasksCompleted: completedTasks.count,
            totalTasksPlanned: plannedTasks.count,
            completedTasks: taskSummaries,
            topCategory: topCategory,
            totalMinutesWorked: totalMinutes,
            productivityScore: productivityScore
        )

        // Generate AI summary if LLM is available
        if llmService.isReady && !completedTasks.isEmpty {
            do {
                let (aiSummary, encouragement) = try await generateAISummary(data: summary)
                summary.aiSummary = aiSummary
                summary.encouragement = encouragement
            } catch {
                // Fall back to default encouragement
                summary.encouragement = getDefaultEncouragement(
                    streak: streakData.currentStreak,
                    score: productivityScore
                )
            }
        } else {
            summary.encouragement = getDefaultEncouragement(
                streak: streakData.currentStreak,
                score: productivityScore
            )
        }

        // Update streak
        updateStreak(for: date, wasProductive: summary.wasProductiveDay)

        // Save summary
        saveSummary(summary)

        let finalSummary = summary
        await MainActor.run {
            self.todaySummary = finalSummary
        }

        return summary
    }

    // MARK: - AI Summary Generation

    private func generateAISummary(data: DailySummaryData) async throws -> (summary: String, encouragement: String) {
        let prompt = buildSummaryPrompt(data: data)
        let systemPrompt = "You are a supportive productivity assistant. Generate encouraging, personalized summaries. Respond in JSON format only."

        let response = try await llmService.complete(prompt: prompt, systemPrompt: systemPrompt)

        return parseSummaryResponse(response)
    }

    private func buildSummaryPrompt(data: DailySummaryData) -> String {
        let taskList = data.completedTasks
            .prefix(10)
            .map { "- \($0.title) (\($0.category.displayName))" }
            .joined(separator: "\n")

        return """
        Generate a brief, encouraging daily summary for a productivity app user.

        Today's Stats:
        - Tasks completed: \(data.tasksCompleted) of \(data.totalTasksPlanned) planned
        - Top category: \(data.topCategory?.displayName ?? "Various")
        - Time worked: \(data.formattedTimeWorked)
        - Current streak: \(streakData.currentStreak) days

        Completed tasks:
        \(taskList.isEmpty ? "No tasks completed yet" : taskList)

        Provide:
        1. A 2-3 sentence natural language summary of their day (reference specific accomplishments if any)
        2. One sentence of encouragement based on their streak and progress

        Respond in JSON format only:
        {
            "summary": "<natural recap of day>",
            "encouragement": "<motivating message>"
        }

        Keep tone warm, supportive, and concise.
        """
    }

    private func parseSummaryResponse(_ response: String) -> (summary: String, encouragement: String) {
        // Try to extract JSON from response
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (
                summary: "Great job staying productive today!",
                encouragement: getDefaultEncouragement(streak: streakData.currentStreak, score: 50)
            )
        }

        let summary = json["summary"] as? String ?? "Great job staying productive today!"
        let encouragement = json["encouragement"] as? String ?? getDefaultEncouragement(streak: streakData.currentStreak, score: 50)

        return (summary: summary, encouragement: encouragement)
    }

    private func extractJSON(from response: String) -> Data? {
        // Try direct parsing first
        if let data = response.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        // Try to extract JSON object from response text
        let pattern = "\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            return nil
        }

        return String(response[range]).data(using: .utf8)
    }

    // MARK: - Calculations

    private func calculateTopCategory(from tasks: [Task]) -> TaskCategory? {
        guard !tasks.isEmpty else { return nil }

        let categoryCounts = Dictionary(grouping: tasks, by: { $0.category })
            .mapValues { $0.count }

        return categoryCounts.max(by: { $0.value < $1.value })?.key
    }

    private func calculateTotalMinutesWorked(from tasks: [Task]) -> Int {
        let totalSeconds = tasks.compactMap { $0.estimatedDuration }.reduce(0, +)
        return Int(totalSeconds / 60)
    }

    func calculateProductivityScore(completed: Int, planned: Int) -> Double {
        guard completed > 0 else { return 0 }

        // Base score from completion rate
        var score: Double
        if planned > 0 {
            score = min(100, (Double(completed) / Double(planned)) * 100)
        } else {
            // Bonus for completing tasks when none were planned
            score = min(100, Double(completed) * 20)
        }

        return score
    }

    // MARK: - Streak Management

    func updateStreak(for date: Date, wasProductive: Bool) {
        streakData.recordDay(date: date, wasProductive: wasProductive)
    }

    // MARK: - Encouragement Messages

    func getDefaultEncouragement(streak: Int, score: Double) -> String {
        if streak >= 30 {
            return "Incredible! \(streak) days strong. You're unstoppable!"
        } else if streak >= 14 {
            return "Two weeks of consistency! Your dedication is inspiring."
        } else if streak >= 7 {
            return "A full week streak! You're building great habits."
        } else if streak >= 3 {
            return "Keep the momentum going! \(streak) days and counting."
        } else if streak == 1 {
            return "Great start! Every journey begins with a single step."
        } else if score >= 80 {
            return "Excellent productivity today! Well done."
        } else if score >= 50 {
            return "Solid progress! Keep up the good work."
        } else if score > 0 {
            return "Every completed task counts. Tomorrow is a fresh start!"
        } else {
            return "Ready to tackle some tasks? You've got this!"
        }
    }

    // MARK: - Persistence

    private func saveSummary(_ summary: DailySummaryData) {
        // Add to history (keep last 30 days)
        var history = Self.loadSummaryHistory()

        // Remove any existing summary for the same date
        let calendar = Calendar.current
        history.removeAll { calendar.isDate($0.date, inSameDayAs: summary.date) }

        // Add new summary
        history.append(summary)

        // Keep only last 30 days
        history = Array(history.suffix(30))

        // Sort by date descending
        history.sort { $0.date > $1.date }

        // Save
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Self.summaryHistoryKey)
        }

        // Update last summary date
        UserDefaults.standard.set(summary.date, forKey: Self.lastSummaryDateKey)

        _Concurrency.Task { @MainActor in
            self.summaryHistory = history
        }
    }

    static func loadSummaryHistory() -> [DailySummaryData] {
        guard let data = UserDefaults.standard.data(forKey: summaryHistoryKey),
              let history = try? JSONDecoder().decode([DailySummaryData].self, from: data) else {
            return []
        }
        return history
    }

    /// Check if summary was already generated today
    var hasTodaySummary: Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: Self.lastSummaryDateKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastDate)
    }

    /// Get summary for a specific date from history
    func getSummary(for date: Date) -> DailySummaryData? {
        let calendar = Calendar.current
        return summaryHistory.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Check if summary needs refresh (task counts changed since last generation)
    func needsRefresh(for date: Date) -> Bool {
        guard let cached = getSummary(for: date) else { return true }

        let currentCompleted = taskService.fetchTasksCompletedOn(date: date).count
        let currentPlanned = taskService.fetchTasksDueOn(date: date).count

        return cached.tasksCompleted != currentCompleted || cached.totalTasksPlanned != currentPlanned
    }
}
