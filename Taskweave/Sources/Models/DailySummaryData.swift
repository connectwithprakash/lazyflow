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
