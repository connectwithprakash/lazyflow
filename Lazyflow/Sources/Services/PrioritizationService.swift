import Foundation
import Combine

/// Service for intelligent task prioritization and suggestions
@MainActor
final class PrioritizationService: ObservableObject {
    static let shared = PrioritizationService()

    // MARK: - Published Properties

    @Published private(set) var suggestedNextTask: Task?
    @Published private(set) var prioritizedTasks: [Task] = []
    @Published private(set) var topThreeSuggestions: [Task] = []
    @Published private(set) var cachedSuggestions: [TaskSuggestion] = []
    @Published private(set) var isAnalyzing = false

    // MARK: - Dependencies

    private let taskService: TaskService
    private let llmService: LLMService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Pattern Learning Storage

    @Published private(set) var completionPatterns: CompletionPatterns
    private(set) var suggestionFeedback: SuggestionFeedback

    private init(
        taskService: TaskService = .shared,
        llmService: LLMService = .shared
    ) {
        self.taskService = taskService
        self.llmService = llmService
        self.completionPatterns = CompletionPatterns.load()
        self.suggestionFeedback = SuggestionFeedback.load()

        // Apply decay on load
        self.suggestionFeedback.applyDecayIfNeeded()
        self.suggestionFeedback.cleanExpiredSnoozes()

        setupObservers()
    }

    private func setupObservers() {
        // Re-analyze when tasks change
        taskService.$tasks
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.analyzeAndPrioritize(tasks)
            }
            .store(in: &cancellables)

        // Periodically check for expired snoozes (every 60 seconds)
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let countBefore = self.suggestionFeedback.snoozedUntil.count
                self.suggestionFeedback.cleanExpiredSnoozes()
                if countBefore > self.suggestionFeedback.snoozedUntil.count {
                    // Snoozes expired — re-analyze to restore tasks
                    self.analyzeAndPrioritize(self.taskService.tasks)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Auto-Prioritization Algorithm

    /// Analyze tasks and calculate priority scores
    func analyzeAndPrioritize(_ tasks: [Task]) {
        let incompleteTasks = tasks.filter { !$0.isCompleted && !$0.isArchived }

        // Prune feedback for deleted tasks to prevent unbounded UserDefaults growth
        let activeIDs = Set(tasks.map(\.id))
        suggestionFeedback.pruneDeletedTasks(activeTaskIDs: activeIDs)

        // Calculate scores using effectiveScore (base + feedback adjustments)
        var scoredTasks: [(task: Task, score: Double)] = incompleteTasks.map { task in
            let score = effectiveScore(for: task)
            return (task, score)
        }

        // Sort by score (highest first)
        scoredTasks.sort { $0.score > $1.score }

        // Filter snoozed tasks for all suggestion outputs
        let unsnoozed = scoredTasks.filter { !suggestionFeedback.isSnoozed($0.task.id) }

        prioritizedTasks = scoredTasks.map { $0.task }
        suggestedNextTask = unsnoozed.first?.task

        // Compute top 3 suggestions (apply diversity)
        topThreeSuggestions = selectDiverseTopThree(from: unsnoozed)

        // Cache fully-built TaskSuggestion objects to avoid recomputing per render
        // Use unsnoozed scores for confidence — snoozed tasks shouldn't inflate the curve
        let allScores = unsnoozed.map(\.score)
        cachedSuggestions = topThreeSuggestions.map { task in
            let score = effectiveScore(for: task)
            let reasons = generateReasons(for: task, score: score)
            let confidence = confidenceLevel(score: score, allScores: allScores)
            return TaskSuggestion(
                task: task,
                score: score,
                reasons: reasons,
                aiInsight: nil,
                confidence: confidence
            )
        }
    }

    /// Canonical effective score: base priority + feedback adjustment, clamped 0-100
    func effectiveScore(for task: Task) -> Double {
        let base = calculatePriorityScore(for: task)
        let adj = suggestionFeedback.getAdjustment(for: task.id)
        return max(0, min(100, base + adj))
    }

    /// Select top 3 with soft diversity: primary = top score, alternatives prefer different categories unless score gap > 10
    private func selectDiverseTopThree(from scored: [(task: Task, score: Double)]) -> [Task] {
        guard !scored.isEmpty else { return [] }

        var result: [Task] = []
        let primary = scored[0]
        result.append(primary.task)

        let remaining = scored.dropFirst()
        var usedCategories: Set<TaskCategory> = [primary.task.category]

        // Pick alternatives preferring different categories
        for item in remaining where result.count < 3 {
            let scoreGap = primary.score - item.score
            if scoreGap > 10 || !usedCategories.contains(item.task.category) {
                result.append(item.task)
                usedCategories.insert(item.task.category)
            }
        }

        // Fill remaining slots if we didn't find diverse enough options
        for item in remaining where result.count < 3 {
            if !result.contains(where: { $0.id == item.task.id }) {
                result.append(item.task)
            }
        }

        return result
    }

    /// Calculate priority score for a task (0-100)
    func calculatePriorityScore(for task: Task) -> Double {
        var score: Double = 0

        // 1. Due Date Urgency (0-40 points)
        score += calculateDueDateScore(task)

        // 2. Explicit Priority (0-25 points)
        score += calculateExplicitPriorityScore(task)

        // 3. Task Age (0-10 points) - older incomplete tasks get higher priority
        score += calculateAgeScore(task)

        // 4. Quick Win Bonus (0-10 points) - short tasks get bonus
        score += calculateQuickWinScore(task)

        // 5. Time of Day Fit (0-10 points) - based on pattern learning
        score += calculateTimeOfDayScore(task)

        // 6. Category Momentum (0-5 points) - if you've been doing similar tasks
        score += calculateMomentumScore(task)

        return min(100, max(0, score))
    }

    // MARK: - Score Components

    private func calculateDueDateScore(_ task: Task) -> Double {
        guard let dueDate = task.dueDate else { return 5 } // No due date = low urgency

        let now = Date()
        let hoursUntilDue = dueDate.timeIntervalSince(now) / 3600

        if hoursUntilDue < 0 {
            // Overdue - maximum urgency
            return 40
        } else if hoursUntilDue < 2 {
            // Due within 2 hours
            return 38
        } else if hoursUntilDue < 24 {
            // Due today
            return 30 + (24 - hoursUntilDue) / 24 * 8
        } else if hoursUntilDue < 48 {
            // Due tomorrow
            return 20 + (48 - hoursUntilDue) / 24 * 10
        } else if hoursUntilDue < 168 {
            // Due within a week
            return 10 + (168 - hoursUntilDue) / 168 * 10
        } else {
            // Due later
            return 5
        }
    }

    private func calculateExplicitPriorityScore(_ task: Task) -> Double {
        switch task.priority {
        case .urgent: return 25
        case .high: return 20
        case .medium: return 12
        case .low: return 5
        case .none: return 0
        }
    }

    private func calculateAgeScore(_ task: Task) -> Double {
        let daysSinceCreation = Date().timeIntervalSince(task.createdAt) / 86400

        if daysSinceCreation > 14 {
            return 10 // Old task - needs attention
        } else if daysSinceCreation > 7 {
            return 7
        } else if daysSinceCreation > 3 {
            return 4
        } else {
            return 2
        }
    }

    private func calculateQuickWinScore(_ task: Task) -> Double {
        guard let duration = task.estimatedDuration else { return 3 }

        let minutes = duration / 60

        if minutes <= 5 {
            return 10 // Very quick win
        } else if minutes <= 15 {
            return 8
        } else if minutes <= 30 {
            return 5
        } else if minutes <= 60 {
            return 2
        } else {
            return 0
        }
    }

    private func calculateTimeOfDayScore(_ task: Task) -> Double {
        let hour = Calendar.current.component(.hour, from: Date())

        // Morning (6-12): Focus work
        // Afternoon (12-17): Meetings, collaborative work
        // Evening (17-22): Light tasks, personal

        switch task.category {
        case .work:
            if hour >= 6 && hour < 12 {
                return 10 // Best time for focus work
            } else if hour >= 12 && hour < 17 {
                return 6
            } else {
                return 2
            }

        case .personal, .health:
            if hour >= 17 {
                return 10 // Evening is good for personal
            } else if hour >= 12 {
                return 5
            } else {
                return 2
            }

        case .errands, .shopping:
            if hour >= 10 && hour < 18 {
                return 8 // Business hours
            } else {
                return 2
            }

        case .learning:
            // Learning is good in morning or evening
            if hour >= 6 && hour < 10 || hour >= 19 && hour < 22 {
                return 8
            } else {
                return 4
            }

        default:
            return 5
        }
    }

    private func calculateMomentumScore(_ task: Task) -> Double {
        // Check what category of task was last completed
        guard let lastCategory = completionPatterns.lastCompletedCategory else { return 0 }

        if task.category == lastCategory {
            return 5 // Bonus for continuing same type of work
        }
        return 0
    }

    // MARK: - "What Should I Do Next?" Feature

    /// Get the next suggested task with reasoning
    func getNextTaskSuggestion() async -> TaskSuggestion? {
        guard let nextTask = suggestedNextTask else { return nil }

        let score = effectiveScore(for: nextTask)
        let reasons = generateReasons(for: nextTask, score: score)
        let allScores = taskService.tasks
            .filter { !$0.isCompleted && !$0.isArchived }
            .map { effectiveScore(for: $0) }
        let confidence = confidenceLevel(score: score, allScores: allScores)

        // Optionally get AI-enhanced reasoning
        if llmService.isReady {
            var suggestion = await getAIEnhancedSuggestion(task: nextTask, reasons: reasons)
            suggestion.confidence = confidence
            return suggestion
        }

        return TaskSuggestion(
            task: nextTask,
            score: score,
            reasons: reasons,
            aiInsight: nil,
            confidence: confidence
        )
    }

    /// Get a suggestion for a specific task with AI-enhanced reasoning
    func getSuggestion(for task: Task) async -> TaskSuggestion {
        let score = effectiveScore(for: task)
        let reasons = generateReasons(for: task, score: score)
        let allScores = taskService.tasks
            .filter { !$0.isCompleted && !$0.isArchived }
            .map { effectiveScore(for: $0) }
        let confidence = confidenceLevel(score: score, allScores: allScores)

        if llmService.isReady {
            var suggestion = await getAIEnhancedSuggestion(task: task, reasons: reasons)
            suggestion.confidence = confidence
            return suggestion
        }

        return TaskSuggestion(
            task: task,
            score: score,
            reasons: reasons,
            aiInsight: nil,
            confidence: confidence
        )
    }

    /// Get top 3 task suggestions with scores and reasons
    func getTopThreeSuggestions() -> [TaskSuggestion] {
        let allScored = taskService.tasks
            .filter { !$0.isCompleted && !$0.isArchived }
            .map { (task: $0, score: effectiveScore(for: $0)) }
            .sorted { $0.score > $1.score }

        return topThreeSuggestions.map { task in
            let score = effectiveScore(for: task)
            let reasons = generateReasons(for: task, score: score)
            let confidence = confidenceLevel(score: score, allScores: allScored.map(\.score))
            return TaskSuggestion(
                task: task,
                score: score,
                reasons: reasons,
                aiInsight: nil,
                confidence: confidence
            )
        }
    }

    /// Record user feedback on a suggestion and re-analyze
    func recordSuggestionFeedback(task: Task, action: FeedbackAction, score: Double) {
        suggestionFeedback.recordFeedback(
            taskID: task.id,
            action: action,
            originalScore: score,
            taskCategory: task.category
        )
        // Re-analyze to update suggestions
        analyzeAndPrioritize(taskService.tasks)
    }

    /// Determine confidence level relative to current batch
    private func confidenceLevel(score: Double, allScores: [Double]) -> ConfidenceLevel {
        guard !allScores.isEmpty else { return .consider }

        let sortedScores = allScores.sorted(by: >)
        let rank = sortedScores.firstIndex(where: { $0 <= score }) ?? sortedScores.count
        let percentile = Double(rank) / Double(sortedScores.count)

        if percentile <= 0.1 {
            return .recommended
        } else if percentile <= 0.3 {
            return .goodFit
        } else {
            return .consider
        }
    }

    private func generateReasons(for task: Task, score: Double) -> [String] {
        var reasons: [String] = []

        // Due date reason
        if let dueDate = task.dueDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relativeTime = formatter.localizedString(for: dueDate, relativeTo: Date())

            if dueDate < Date() {
                reasons.append("This task is overdue")
            } else if Calendar.current.isDateInToday(dueDate) {
                reasons.append("Due today")
            } else if Calendar.current.isDateInTomorrow(dueDate) {
                reasons.append("Due tomorrow")
            } else {
                reasons.append("Due \(relativeTime)")
            }
        }

        // Priority reason
        if task.priority == .urgent {
            reasons.append("Marked as urgent")
        } else if task.priority == .high {
            reasons.append("High priority")
        }

        // Quick win reason
        if let duration = task.estimatedDuration, duration <= 900 {
            let minutes = Int(duration / 60)
            reasons.append("Quick \(minutes) minute task")
        }

        // Time of day reason
        let hour = Calendar.current.component(.hour, from: Date())
        if task.category == .work && hour >= 6 && hour < 12 {
            reasons.append("Morning is ideal for focused work")
        }

        // Age reason
        let daysSinceCreation = Date().timeIntervalSince(task.createdAt) / 86400
        if daysSinceCreation > 7 {
            reasons.append("Been on your list for over a week")
        }

        return reasons
    }

    private func getAIEnhancedSuggestion(task: Task, reasons: [String]) async -> TaskSuggestion {
        let score = effectiveScore(for: task)

        do {
            let prompt = """
            Given this task and its context, provide a brief, motivating insight (1-2 sentences) about why the user should tackle it now.

            Task: \(task.title)
            Priority: \(task.priority.displayName)
            Category: \(task.category.displayName)
            Due: \(task.dueDate?.formatted() ?? "No due date")
            Current reasons: \(reasons.joined(separator: ", "))

            Respond with just the insight, no explanation.
            """

            let insight = try await llmService.complete(
                prompt: prompt,
                systemPrompt: "You are a productivity coach. Be encouraging but concise."
            )

            return TaskSuggestion(
                task: task,
                score: score,
                reasons: reasons,
                aiInsight: insight.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            return TaskSuggestion(
                task: task,
                score: score,
                reasons: reasons,
                aiInsight: nil
            )
        }
    }

    // MARK: - Batch Prioritization with AI

    /// Use AI to suggest optimal task order
    func getAITaskOrder() async -> [TaskOrderSuggestion]? {
        guard llmService.isReady else { return nil }

        let incompleteTasks = taskService.tasks.filter { !$0.isCompleted && !$0.isArchived }
        guard !incompleteTasks.isEmpty else { return nil }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            return try await llmService.suggestTaskOrder(tasks: Array(incompleteTasks.prefix(10)))
        } catch {
            print("Failed to get AI task order: \(error)")
            return nil
        }
    }

    // MARK: - Pattern Learning

    /// Record task completion for pattern learning
    func recordCompletion(task: Task) {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let dayOfWeek = Calendar.current.component(.weekday, from: now)

        // Update last completed category
        completionPatterns.lastCompletedCategory = task.category
        completionPatterns.lastCompletedTime = now

        // Update completion time patterns
        let key = "\(task.category.rawValue)_\(hour)"
        completionPatterns.categoryTimePatterns[key, default: 0] += 1

        // Update day of week patterns
        let dayKey = "\(task.category.rawValue)_\(dayOfWeek)"
        completionPatterns.categoryDayPatterns[dayKey, default: 0] += 1

        // Calculate average completion time if we have duration
        if let estimatedDuration = task.estimatedDuration,
           let completedAt = task.completedAt {
            let actualDuration = completedAt.timeIntervalSince(task.createdAt)

            // Update rolling average
            let categoryKey = String(task.category.rawValue)
            let current = completionPatterns.averageCompletionTimes[categoryKey] ?? estimatedDuration
            completionPatterns.averageCompletionTimes[categoryKey] = (current + actualDuration) / 2
        }

        completionPatterns.save()
    }

    /// Get productivity insights based on patterns
    func getProductivityInsights() -> [ProductivityInsight] {
        var insights: [ProductivityInsight] = []

        // Most productive time
        if let (time, count) = completionPatterns.categoryTimePatterns.max(by: { $0.value < $1.value }), count > 3 {
            let hour = Int(time.split(separator: "_").last ?? "9") ?? 9
            let timeStr = hour < 12 ? "\(hour) AM" : hour == 12 ? "12 PM" : "\(hour - 12) PM"
            insights.append(ProductivityInsight(
                title: "Peak Productivity",
                description: "You're most productive around \(timeStr)",
                iconName: "chart.line.uptrend.xyaxis"
            ))
        }

        // Most active day
        if let (day, count) = completionPatterns.categoryDayPatterns.max(by: { $0.value < $1.value }), count > 3 {
            let dayNum = Int(day.split(separator: "_").last ?? "1") ?? 1
            let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            if dayNum > 0 && dayNum < dayNames.count {
                insights.append(ProductivityInsight(
                    title: "Most Active Day",
                    description: "\(dayNames[dayNum]) is your most productive day",
                    iconName: "calendar.badge.checkmark"
                ))
            }
        }

        return insights
    }
}

// MARK: - Supporting Types

enum ConfidenceLevel: String {
    case recommended = "Top Pick"
    case goodFit = "Strong"
    case consider = "Good Fit"
}

struct TaskSuggestion: Identifiable {
    var id: UUID { task.id }
    let task: Task
    let score: Double
    let reasons: [String]
    let aiInsight: String?
    var confidence: ConfidenceLevel = .consider

    var scorePercentage: Int {
        Int(score)
    }
}

struct ProductivityInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}

// MARK: - Completion Patterns (Persistence)

struct CompletionPatterns: Codable {
    var lastCompletedCategory: TaskCategory?
    var lastCompletedTime: Date?
    var categoryTimePatterns: [String: Int] = [:] // "category_hour" -> count
    var categoryDayPatterns: [String: Int] = [:]  // "category_dayOfWeek" -> count
    var averageCompletionTimes: [String: TimeInterval] = [:] // category -> avg time

    private static let key = "completion_patterns"

    static func load() -> CompletionPatterns {
        guard let data = UserDefaults.standard.data(forKey: key),
              let patterns = try? JSONDecoder().decode(CompletionPatterns.self, from: data) else {
            return CompletionPatterns()
        }
        return patterns
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
