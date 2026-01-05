import Foundation

// MARK: - Daily Summary Data

/// Represents a summary of tasks completed on a specific day
struct DailySummaryData: Codable, Identifiable {
    let id: UUID
    let date: Date
    let tasksCompleted: Int
    let totalTasksPlanned: Int
    let completedTasks: [CompletedTaskSummary]
    let topCategory: TaskCategory?
    let totalMinutesWorked: Int
    let productivityScore: Double // 0-100
    var aiSummary: String?
    var encouragement: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        tasksCompleted: Int,
        totalTasksPlanned: Int,
        completedTasks: [CompletedTaskSummary],
        topCategory: TaskCategory?,
        totalMinutesWorked: Int,
        productivityScore: Double,
        aiSummary: String? = nil,
        encouragement: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.tasksCompleted = tasksCompleted
        self.totalTasksPlanned = totalTasksPlanned
        self.completedTasks = completedTasks
        self.topCategory = topCategory
        self.totalMinutesWorked = totalMinutesWorked
        self.productivityScore = productivityScore
        self.aiSummary = aiSummary
        self.encouragement = encouragement
        self.createdAt = createdAt
    }

    /// Completion percentage (0-100)
    var completionPercentage: Int {
        guard totalTasksPlanned > 0 else { return tasksCompleted > 0 ? 100 : 0 }
        return Int((Double(tasksCompleted) / Double(totalTasksPlanned)) * 100)
    }

    /// Formatted time worked string
    var formattedTimeWorked: String {
        if totalMinutesWorked < 60 {
            return "\(totalMinutesWorked)m"
        }
        let hours = totalMinutesWorked / 60
        let minutes = totalMinutesWorked % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    /// Check if this was a productive day
    var wasProductiveDay: Bool {
        guard tasksCompleted > 0 else { return false }
        if totalTasksPlanned > 0 {
            return Double(tasksCompleted) / Double(totalTasksPlanned) >= 0.5
        }
        return true
    }
}

// MARK: - Completed Task Summary

/// Lightweight summary of a completed task for display
struct CompletedTaskSummary: Codable, Identifiable {
    let id: UUID
    let title: String
    let category: TaskCategory
    let priority: Priority
    let estimatedDuration: TimeInterval?
    let completedAt: Date

    init(from task: Task) {
        self.id = task.id
        self.title = task.title
        self.category = task.category
        self.priority = task.priority
        self.estimatedDuration = task.estimatedDuration
        self.completedAt = task.completedAt ?? Date()
    }

    init(
        id: UUID,
        title: String,
        category: TaskCategory,
        priority: Priority,
        estimatedDuration: TimeInterval?,
        completedAt: Date
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.completedAt = completedAt
    }
}

// MARK: - Streak Data

/// Tracks user's productivity streak
struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastProductiveDate: Date?
    var totalProductiveDays: Int

    private static let userDefaultsKey = "streak_data"

    init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastProductiveDate: Date? = nil,
        totalProductiveDays: Int = 0
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastProductiveDate = lastProductiveDate
        self.totalProductiveDays = totalProductiveDays
    }

    // MARK: - Persistence

    /// Load streak data from UserDefaults
    static func load() -> StreakData {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let streakData = try? JSONDecoder().decode(StreakData.self, from: data) else {
            return StreakData()
        }
        return streakData
    }

    /// Save streak data to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: StreakData.userDefaultsKey)
        }
    }

    // MARK: - Streak Logic

    /// Record a day's productivity and update streak
    mutating func recordDay(date: Date, wasProductive: Bool) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if wasProductive {
            totalProductiveDays += 1

            if let lastDate = lastProductiveDate {
                let lastDay = calendar.startOfDay(for: lastDate)
                let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

                if daysDiff == 1 {
                    // Consecutive day - extend streak
                    currentStreak += 1
                } else if daysDiff > 1 {
                    // Gap in days - reset streak
                    currentStreak = 1
                }
                // daysDiff == 0 means same day - don't change streak
            } else {
                // First productive day ever
                currentStreak = 1
            }

            lastProductiveDate = today
            longestStreak = max(longestStreak, currentStreak)
        } else {
            // Non-productive day - check if streak should be reset
            if let lastDate = lastProductiveDate {
                let lastDay = calendar.startOfDay(for: lastDate)
                let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
                if daysDiff > 0 {
                    currentStreak = 0
                }
            }
        }

        save()
    }

    /// Check if streak is at a milestone (7, 14, 30, 60, 90, 100, 365 days)
    var isAtMilestone: Bool {
        let milestones = [7, 14, 30, 60, 90, 100, 365]
        return milestones.contains(currentStreak)
    }

    /// Get next milestone to reach
    var nextMilestone: Int? {
        let milestones = [7, 14, 30, 60, 90, 100, 365]
        return milestones.first { $0 > currentStreak }
    }

    /// Days until next milestone
    var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next - currentStreak
    }
}

// MARK: - Morning Briefing Data

/// Represents the morning briefing content with yesterday's recap and today's plan
struct MorningBriefingData: Codable, Identifiable {
    let id: UUID
    let date: Date

    // Yesterday's recap
    let yesterdayCompleted: Int
    let yesterdayPlanned: Int
    let yesterdayTopCategory: TaskCategory?

    // Today's plan
    let todayTasks: [TaskBriefingSummary]
    let todayHighPriority: Int
    let todayOverdue: Int
    let todayEstimatedMinutes: Int

    // Weekly insights
    let weeklyStats: WeeklyStats

    // AI content
    var aiSummary: String?
    var todayFocus: String?
    var motivationalMessage: String?

    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        yesterdayCompleted: Int,
        yesterdayPlanned: Int,
        yesterdayTopCategory: TaskCategory?,
        todayTasks: [TaskBriefingSummary],
        todayHighPriority: Int,
        todayOverdue: Int,
        todayEstimatedMinutes: Int,
        weeklyStats: WeeklyStats,
        aiSummary: String? = nil,
        todayFocus: String? = nil,
        motivationalMessage: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.yesterdayCompleted = yesterdayCompleted
        self.yesterdayPlanned = yesterdayPlanned
        self.yesterdayTopCategory = yesterdayTopCategory
        self.todayTasks = todayTasks
        self.todayHighPriority = todayHighPriority
        self.todayOverdue = todayOverdue
        self.todayEstimatedMinutes = todayEstimatedMinutes
        self.weeklyStats = weeklyStats
        self.aiSummary = aiSummary
        self.todayFocus = todayFocus
        self.motivationalMessage = motivationalMessage
        self.createdAt = createdAt
    }

    /// Formatted estimated time for today
    var formattedTodayTime: String {
        if todayEstimatedMinutes < 60 {
            return "\(todayEstimatedMinutes)m"
        }
        let hours = todayEstimatedMinutes / 60
        let minutes = todayEstimatedMinutes % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    /// Yesterday's completion percentage
    var yesterdayCompletionPercentage: Int {
        guard yesterdayPlanned > 0 else { return yesterdayCompleted > 0 ? 100 : 0 }
        return Int((Double(yesterdayCompleted) / Double(yesterdayPlanned)) * 100)
    }

    /// Check if there are any tasks for today
    var hasTodayTasks: Bool {
        !todayTasks.isEmpty
    }

    /// Check if yesterday was productive
    var wasYesterdayProductive: Bool {
        guard yesterdayCompleted > 0 else { return false }
        if yesterdayPlanned > 0 {
            return Double(yesterdayCompleted) / Double(yesterdayPlanned) >= 0.5
        }
        return true
    }
}

// MARK: - Weekly Stats

/// Weekly productivity statistics for morning briefing
struct WeeklyStats: Codable {
    let tasksCompletedThisWeek: Int
    let totalTasksPlannedThisWeek: Int
    let averageCompletionRate: Double // 0-100
    let mostProductiveDay: String?
    let currentStreak: Int
    let daysUntilWeekEnd: Int

    init(
        tasksCompletedThisWeek: Int = 0,
        totalTasksPlannedThisWeek: Int = 0,
        averageCompletionRate: Double = 0,
        mostProductiveDay: String? = nil,
        currentStreak: Int = 0,
        daysUntilWeekEnd: Int = 0
    ) {
        self.tasksCompletedThisWeek = tasksCompletedThisWeek
        self.totalTasksPlannedThisWeek = totalTasksPlannedThisWeek
        self.averageCompletionRate = averageCompletionRate
        self.mostProductiveDay = mostProductiveDay
        self.currentStreak = currentStreak
        self.daysUntilWeekEnd = daysUntilWeekEnd
    }

    /// Formatted completion rate
    var formattedCompletionRate: String {
        "\(Int(averageCompletionRate))%"
    }

    /// Check if user is on a streak
    var hasStreak: Bool {
        currentStreak > 0
    }

    /// Motivational text based on weekly performance
    var weeklyInsight: String {
        if averageCompletionRate >= 80 {
            return "Excellent week so far!"
        } else if averageCompletionRate >= 60 {
            return "Good progress this week!"
        } else if averageCompletionRate >= 40 {
            return "Keep pushing forward!"
        } else if tasksCompletedThisWeek > 0 {
            return "Every task counts!"
        } else {
            return "Let's make this week count!"
        }
    }
}

// MARK: - Task Briefing Summary

/// Lightweight summary of a task for morning briefing display
struct TaskBriefingSummary: Codable, Identifiable {
    let id: UUID
    let title: String
    let priority: Priority
    let category: TaskCategory
    let dueTime: Date?
    let estimatedDuration: TimeInterval?
    let isOverdue: Bool

    init(from task: Task) {
        self.id = task.id
        self.title = task.title
        self.priority = task.priority
        self.category = task.category
        self.dueTime = task.dueTime
        self.estimatedDuration = task.estimatedDuration
        self.isOverdue = task.isOverdue
    }

    init(
        id: UUID,
        title: String,
        priority: Priority,
        category: TaskCategory,
        dueTime: Date?,
        estimatedDuration: TimeInterval?,
        isOverdue: Bool = false
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.category = category
        self.dueTime = dueTime
        self.estimatedDuration = estimatedDuration
        self.isOverdue = isOverdue
    }

    /// Formatted due time
    var formattedDueTime: String? {
        guard let dueTime = dueTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dueTime)
    }

    /// Formatted duration
    var formattedDuration: String? {
        guard let duration = estimatedDuration, duration > 0 else { return nil }
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
    }
}
