import Foundation

// MARK: - Daily Summary Data

/// Represents a summary of tasks completed on a specific day
public struct DailySummaryData: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let tasksCompleted: Int
    public let totalTasksPlanned: Int
    public let completedTasks: [CompletedTaskSummary]
    public let topCategory: TaskCategory?
    public let totalMinutesWorked: Int
    public let productivityScore: Double // 0-100
    public var aiSummary: String?
    public var encouragement: String?
    public let createdAt: Date

    // Carryover: unfinished tasks due today or overdue
    public var carryoverTasks: [CarryoverTaskSummary]
    public var suggestedPriorities: [String]

    public init(
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
        carryoverTasks: [CarryoverTaskSummary] = [],
        suggestedPriorities: [String] = [],
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
        self.carryoverTasks = carryoverTasks
        self.suggestedPriorities = suggestedPriorities
        self.createdAt = createdAt
    }


    /// Completion percentage (0-100)
    public var completionPercentage: Int {
        guard totalTasksPlanned > 0 else { return tasksCompleted > 0 ? 100 : 0 }
        return Int((Double(tasksCompleted) / Double(totalTasksPlanned)) * 100)
    }

    /// Formatted time worked string
    public var formattedTimeWorked: String {
        if totalMinutesWorked < 60 {
            return "\(totalMinutesWorked)m"
        }
        let hours = totalMinutesWorked / 60
        let minutes = totalMinutesWorked % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    /// Whether there are unfinished tasks to carry over
    public var hasCarryover: Bool {
        !carryoverTasks.isEmpty
    }

    /// Check if this was a productive day
    public var wasProductiveDay: Bool {
        guard tasksCompleted > 0 else { return false }
        if totalTasksPlanned > 0 {
            return Double(tasksCompleted) / Double(totalTasksPlanned) >= 0.5
        }
        return true
    }
}

// MARK: - Completed Task Summary

/// Lightweight summary of a completed task for display
public struct CompletedTaskSummary: Codable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let category: TaskCategory
    public let priority: Priority
    public let estimatedDuration: TimeInterval?
    public let completedAt: Date

    public init(from task: Task) {
        self.id = task.id
        self.title = task.title
        self.category = task.category
        self.priority = task.priority
        self.estimatedDuration = task.estimatedDuration
        self.completedAt = task.completedAt ?? Date()
    }

    public init(
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

// MARK: - Carryover Task Summary

/// Lightweight summary of an unfinished task for carryover display
public struct CarryoverTaskSummary: Codable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let category: TaskCategory
    public let priority: Priority
    public let dueDate: Date?
    public let isOverdue: Bool

    public init(from task: Task) {
        self.id = task.id
        self.title = task.title
        self.category = task.category
        self.priority = task.priority
        self.dueDate = task.dueDate
        self.isOverdue = task.isOverdue
    }

    public init(
        id: UUID,
        title: String,
        category: TaskCategory,
        priority: Priority,
        dueDate: Date?,
        isOverdue: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.priority = priority
        self.dueDate = dueDate
        self.isOverdue = isOverdue
    }
}

// MARK: - Streak Data

/// Tracks user's productivity streak
public struct StreakData: Codable, Sendable {
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastProductiveDate: Date?
    public var totalProductiveDays: Int

    private static let userDefaultsKey = "streak_data"

    public init(
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
    public static func load() -> StreakData {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let streakData = try? JSONDecoder().decode(StreakData.self, from: data) else {
            return StreakData()
        }
        return streakData
    }

    /// Save streak data to UserDefaults
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: StreakData.userDefaultsKey)
        }
    }

    // MARK: - Streak Logic

    /// Record a day's productivity and update streak
    public mutating func recordDay(date: Date, wasProductive: Bool) {
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
    public var isAtMilestone: Bool {
        let milestones = [7, 14, 30, 60, 90, 100, 365]
        return milestones.contains(currentStreak)
    }

    /// Get next milestone to reach
    public var nextMilestone: Int? {
        let milestones = [7, 14, 30, 60, 90, 100, 365]
        return milestones.first { $0 > currentStreak }
    }

    /// Days until next milestone
    public var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next - currentStreak
    }
}

// MARK: - Calendar Event Summary

/// Lightweight summary of a calendar event for display in briefings
public struct CalendarEventSummary: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
    }

    /// Duration in minutes
    public var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Formatted time range (e.g., "9:00 AM - 10:30 AM")
    public var formattedTimeRange: String {
        if isAllDay {
            return "All day"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    /// Formatted start time only
    public var formattedStartTime: String {
        if isAllDay {
            return "All day"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
}

// MARK: - Schedule Summary

/// Summary of today's calendar schedule for morning briefing
public struct ScheduleSummary: Codable, Sendable {
    public let totalMeetingMinutes: Int
    public let meetingCount: Int
    public let nextEvent: CalendarEventSummary?
    public let largestFreeBlockMinutes: Int
    public let allDayEvents: [CalendarEventSummary]

    public init(
        totalMeetingMinutes: Int,
        meetingCount: Int,
        nextEvent: CalendarEventSummary? = nil,
        largestFreeBlockMinutes: Int,
        allDayEvents: [CalendarEventSummary] = []
    ) {
        self.totalMeetingMinutes = totalMeetingMinutes
        self.meetingCount = meetingCount
        self.nextEvent = nextEvent
        self.largestFreeBlockMinutes = largestFreeBlockMinutes
        self.allDayEvents = allDayEvents
    }

    /// Formatted total meeting time
    public var formattedMeetingTime: String {
        if totalMeetingMinutes < 60 {
            return "\(totalMeetingMinutes)m"
        }
        let hours = totalMeetingMinutes / 60
        let minutes = totalMeetingMinutes % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    /// Formatted largest free block
    public var formattedFreeBlock: String {
        if largestFreeBlockMinutes < 60 {
            return "\(largestFreeBlockMinutes)m"
        }
        let hours = largestFreeBlockMinutes / 60
        let minutes = largestFreeBlockMinutes % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    /// Check if there are any meetings today
    public var hasMeetings: Bool {
        meetingCount > 0
    }

    /// Check if there's meaningful free time
    public var hasSignificantFreeBlock: Bool {
        largestFreeBlockMinutes >= 30
    }
}

// MARK: - Morning Briefing Data

/// Represents the morning briefing content with yesterday's recap and today's plan
public struct MorningBriefingData: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date

    // Yesterday's recap
    public let yesterdayCompleted: Int
    public let yesterdayPlanned: Int
    public let yesterdayTopCategory: TaskCategory?

    // Today's plan
    public let todayTasks: [TaskBriefingSummary]
    public let todayHighPriority: Int
    public let todayOverdue: Int
    public let todayEstimatedMinutes: Int

    // Weekly insights
    public let weeklyStats: WeeklyStats

    // Calendar schedule (optional - nil if no calendar access)
    public let scheduleSummary: ScheduleSummary?

    // AI content
    public var aiSummary: String?
    public var todayFocus: String?
    public var motivationalMessage: String?

    public let createdAt: Date

    public init(
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
        scheduleSummary: ScheduleSummary? = nil,
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
        self.scheduleSummary = scheduleSummary
        self.aiSummary = aiSummary
        self.todayFocus = todayFocus
        self.motivationalMessage = motivationalMessage
        self.createdAt = createdAt
    }

    /// Formatted estimated time for today
    public var formattedTodayTime: String {
        if todayEstimatedMinutes < 60 {
            return "\(todayEstimatedMinutes)m"
        }
        let hours = todayEstimatedMinutes / 60
        let minutes = todayEstimatedMinutes % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    /// Yesterday's completion percentage
    public var yesterdayCompletionPercentage: Int {
        guard yesterdayPlanned > 0 else { return yesterdayCompleted > 0 ? 100 : 0 }
        return Int((Double(yesterdayCompleted) / Double(yesterdayPlanned)) * 100)
    }

    /// Check if there are any tasks for today
    public var hasTodayTasks: Bool {
        !todayTasks.isEmpty
    }

    /// Check if yesterday was productive
    public var wasYesterdayProductive: Bool {
        guard yesterdayCompleted > 0 else { return false }
        if yesterdayPlanned > 0 {
            return Double(yesterdayCompleted) / Double(yesterdayPlanned) >= 0.5
        }
        return true
    }

    /// Check if calendar data is available
    public var hasCalendarData: Bool {
        scheduleSummary != nil
    }
}

// MARK: - Weekly Stats

/// Weekly productivity statistics for morning briefing
public struct WeeklyStats: Codable, Sendable {
    public let tasksCompletedThisWeek: Int
    public let totalTasksPlannedThisWeek: Int
    public let averageCompletionRate: Double // 0-100
    public let mostProductiveDay: String?
    public let currentStreak: Int
    public let daysUntilWeekEnd: Int

    public init(
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
    public var formattedCompletionRate: String {
        "\(Int(averageCompletionRate))%"
    }

    /// Check if user is on a streak
    public var hasStreak: Bool {
        currentStreak > 0
    }

    /// Motivational text based on weekly performance
    public var weeklyInsight: String {
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
public struct TaskBriefingSummary: Codable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let priority: Priority
    public let category: TaskCategory
    public let dueTime: Date?
    public let estimatedDuration: TimeInterval?
    public let isOverdue: Bool

    public init(from task: Task) {
        self.id = task.id
        self.title = task.title
        self.priority = task.priority
        self.category = task.category
        self.dueTime = task.dueTime
        self.estimatedDuration = task.estimatedDuration
        self.isOverdue = task.isOverdue
    }

    public init(
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
    public var formattedDueTime: String? {
        guard let dueTime = dueTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dueTime)
    }

    /// Formatted duration
    public var formattedDuration: String? {
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
