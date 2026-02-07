import Foundation
import SwiftUI
import Combine

/// Service for calculating productivity analytics and insights
/// Part of Issue #130 - Category and List Analytics
@MainActor
class AnalyticsService: ObservableObject {
    private let taskService: TaskService
    private let taskListService: TaskListService
    private var cancellables = Set<AnyCancellable>()

    /// Triggers view updates when underlying data changes
    @Published private(set) var lastUpdated = Date()

    init(taskService: TaskService = .shared, taskListService: TaskListService = TaskListService()) {
        self.taskService = taskService
        self.taskListService = taskListService

        // Observe task changes to trigger analytics refresh
        // Subscribe to $tasks (not objectWillChange) to ensure data is updated before refresh
        taskService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.lastUpdated = Date()
            }
            .store(in: &cancellables)
    }

    // MARK: - Category Analytics

    /// Calculate completion rate for a specific category within a time period
    func calculateCompletionRate(for category: TaskCategory, in period: AnalyticsPeriod) -> Double {
        let tasks = fetchTasks(for: period).filter { $0.category == category }
        guard !tasks.isEmpty else { return 0 }

        let completed = tasks.filter { $0.isCompleted }.count
        return (Double(completed) / Double(tasks.count)) * 100
    }

    /// Get stats for all categories within a time period
    func getCategoryStats(for period: AnalyticsPeriod) -> [CategoryStats] {
        let tasks = fetchTasks(for: period)
        var statsByCategory: [TaskCategory: CategoryStats] = [:]

        for task in tasks {
            let category = task.category
            var stats = statsByCategory[category] ?? CategoryStats(category: category)
            stats.totalCount += 1
            if task.isCompleted {
                stats.completedCount += 1
            }
            if let duration = task.estimatedDuration {
                stats.totalEstimatedMinutes += Int(duration / 60)
            }
            statsByCategory[category] = stats
        }

        return Array(statsByCategory.values).sorted { $0.totalCount > $1.totalCount }
    }

    // MARK: - Work-Life Balance

    /// Calculate work-life balance ratio
    func calculateWorkLifeBalance(for period: AnalyticsPeriod, targetWorkRatio: Double = 0.6) -> WorkLifeBalance {
        let tasks = fetchTasks(for: period)
        guard !tasks.isEmpty else {
            return WorkLifeBalance(
                workPercentage: 50,
                lifePercentage: 50,
                score: 100,
                targetRatio: targetWorkRatio
            )
        }

        let workCategories: Set<TaskCategory> = [.work, .finance, .learning]
        let workTasks = tasks.filter { workCategories.contains($0.category) }
        let lifeTasks = tasks.filter { !workCategories.contains($0.category) }

        let workPercentage = (Double(workTasks.count) / Double(tasks.count)) * 100
        let lifePercentage = (Double(lifeTasks.count) / Double(tasks.count)) * 100

        // Calculate score: 100 = perfect match to target, decreases with deviation
        let actualRatio = workPercentage / 100
        let deviation = abs(actualRatio - targetWorkRatio)
        let score = max(0, 100 - (deviation * 100))

        return WorkLifeBalance(
            workPercentage: workPercentage,
            lifePercentage: lifePercentage,
            score: score,
            targetRatio: targetWorkRatio
        )
    }

    // MARK: - List Analytics

    /// Calculate health score for a specific list
    func calculateListHealth(for listID: UUID) -> ListHealth? {
        let allTasks = taskService.tasks.filter { $0.listID == listID }

        guard !allTasks.isEmpty else {
            return ListHealth(
                listID: listID,
                healthScore: 50,
                completionRate: 0,
                overdueCount: 0,
                lastActivityDate: nil,
                velocity: 0
            )
        }

        let completedTasks = allTasks.filter { $0.isCompleted }
        let completionRate = (Double(completedTasks.count) / Double(allTasks.count)) * 100

        let now = Date()
        let overdueTasks = allTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < now
        }

        let lastActivity = allTasks.compactMap { $0.updatedAt }.max()

        // Calculate velocity (tasks completed per week in last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let recentCompleted = completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= thirtyDaysAgo
        }
        let velocity = Double(recentCompleted.count) / 4.0 // 4 weeks in 30 days

        // Health score calculation
        // Weights: completion 35%, overdue penalty 25%, recency 20%, velocity stability 20%
        var healthScore: Double = 0

        // Completion rate contribution (0-35 points)
        healthScore += (completionRate / 100) * 35

        // Overdue penalty (0-25 points, less overdue = more points)
        let overdueRatio = Double(overdueTasks.count) / Double(allTasks.count)
        healthScore += (1 - overdueRatio) * 25

        // Recency contribution (0-20 points)
        if let lastActivity = lastActivity {
            let daysSinceActivity = Calendar.current.dateComponents([.day], from: lastActivity, to: now).day ?? 30
            let recencyScore = max(0, 1 - (Double(daysSinceActivity) / 30))
            healthScore += recencyScore * 20
        }

        // Velocity contribution (0-20 points) - having some activity is good
        let velocityScore = min(1, velocity / 5) // Cap at 5 tasks/week for max score
        healthScore += velocityScore * 20

        return ListHealth(
            listID: listID,
            healthScore: healthScore,
            completionRate: completionRate,
            overdueCount: overdueTasks.count,
            lastActivityDate: lastActivity,
            velocity: velocity
        )
    }

    /// Detect stale lists (inactive for 14+ days with incomplete tasks)
    func getStaleLists() -> [TaskList] {
        let now = Date()
        let staleThreshold = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        return taskListService.lists.filter { list in
            let listTasks = taskService.tasks.filter { $0.listID == list.id }
            guard !listTasks.isEmpty else { return false }

            // Has incomplete tasks
            let hasIncompleteTasks = listTasks.contains { !$0.isCompleted }
            guard hasIncompleteTasks else { return false }

            // Check last activity
            let lastActivity = listTasks.compactMap { $0.updatedAt }.max()
            guard let lastActivity = lastActivity else { return true }

            return lastActivity < staleThreshold
        }
    }

    // MARK: - Overview Stats

    /// Get overview statistics for a time period
    func getOverviewStats(for period: AnalyticsPeriod) -> OverviewStats {
        let tasks = fetchTasks(for: period)
        let completedTasks = tasks.filter { $0.isCompleted }

        let completionRate = tasks.isEmpty ? 0 : (Double(completedTasks.count) / Double(tasks.count)) * 100

        let overdueCount = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < Date()
        }.count

        return OverviewStats(
            totalTasks: tasks.count,
            completedTasks: completedTasks.count,
            completionRate: completionRate,
            overdueCount: overdueCount
        )
    }

    // MARK: - Private Helpers

    private func fetchTasks(for period: AnalyticsPeriod) -> [Task] {
        let startDate = period.startDate
        let endDate = period.endDate

        return taskService.tasks.filter { task in
            // Include tasks created in period OR completed in period
            // Use < endDate since endDate is the start of the next period
            let createdInPeriod = task.createdAt >= startDate && task.createdAt < endDate
            let completedInPeriod: Bool
            if let completedAt = task.completedAt {
                completedInPeriod = completedAt >= startDate && completedAt < endDate
            } else {
                completedInPeriod = false
            }
            let dueInPeriod: Bool
            if let dueDate = task.dueDate {
                dueInPeriod = dueDate >= startDate && dueDate < endDate
            } else {
                dueInPeriod = false
            }

            return createdInPeriod || completedInPeriod || dueInPeriod
        }
    }
}

// MARK: - Analytics Data Models

/// Time period for analytics queries
enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "Week"
    case thisMonth = "Month"
    case thisQuarter = "Quarter"

    var id: String { rawValue }

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .thisWeek:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .thisMonth:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            return calendar.date(from: components) ?? now
        }
    }

    var endDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        case .thisWeek:
            return calendar.date(byAdding: .day, value: 7, to: startDate) ?? now
        case .thisMonth:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? now
        case .thisQuarter:
            return calendar.date(byAdding: .month, value: 3, to: startDate) ?? now
        }
    }
}

/// Statistics for a single category
struct CategoryStats: Identifiable {
    let id = UUID()
    let category: TaskCategory
    var totalCount: Int = 0
    var completedCount: Int = 0
    var totalEstimatedMinutes: Int = 0

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return (Double(completedCount) / Double(totalCount)) * 100
    }
}

/// Work-life balance metrics
struct WorkLifeBalance {
    let workPercentage: Double
    let lifePercentage: Double
    let score: Double // 0-100, 100 = perfect balance
    let targetRatio: Double

    var isBalanced: Bool {
        score >= 80
    }

    var statusText: String {
        if score >= 90 { return "Well balanced" }
        if score >= 70 { return "Slightly imbalanced" }
        if score >= 50 { return "Needs attention" }
        return "Significantly imbalanced"
    }
}

/// Health metrics for a task list
struct ListHealth {
    let listID: UUID
    let healthScore: Double // 0-100
    let completionRate: Double
    let overdueCount: Int
    let lastActivityDate: Date?
    let velocity: Double // tasks per week

    var healthLevel: HealthLevel {
        switch healthScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }

    enum HealthLevel: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .yellow
            case .poor: return .orange
            case .critical: return .red
            }
        }
    }
}

/// Overview statistics for dashboard
struct OverviewStats {
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double
    let overdueCount: Int

    var pendingTasks: Int {
        totalTasks - completedTasks
    }
}
