import Foundation
import Combine

/// Service for building unified AI context from multiple sources
final class AIContextService: ObservableObject {
    static let shared = AIContextService()

    // MARK: - Dependencies

    private let learningService = AILearningService.shared

    // MARK: - Published State

    @Published private(set) var userPatterns: UserPatterns

    // MARK: - Private

    private let recentTasksLimit = 10
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        self.userPatterns = UserPatterns.load()
    }

    // MARK: - Pattern Management

    /// Reload patterns from UserDefaults (useful after external changes)
    func reloadPatterns() {
        userPatterns = UserPatterns.load()
    }

    /// Reset patterns (useful for testing)
    func resetPatterns() {
        userPatterns = UserPatterns()
        userPatterns.save()
    }

    // MARK: - Context Building

    /// Build complete AI context for task analysis
    func buildContext(for task: Task? = nil) -> AIContext {
        let recentTasks = fetchRecentTasks()
        let correctionsSummary = learningService.getCorrectionsContext() + learningService.getDurationAccuracyContext()
        let customCategories = fetchCustomCategories()
        let timeContext = AIContext.TimeContext()

        var taskContext: AIContext.TaskSpecificContext?
        if let task = task {
            taskContext = AIContext.TaskSpecificContext(
                title: task.title,
                notes: task.notes,
                dueDate: task.dueDate,
                currentPriority: task.priority.displayName
            )
        }

        return AIContext(
            recentTasks: recentTasks,
            userPatterns: userPatterns,
            correctionsSummary: correctionsSummary,
            customCategories: customCategories,
            timeContext: timeContext,
            taskContext: taskContext
        )
    }

    /// Build context string for LLM prompts (convenience method)
    func buildContextString(for task: Task? = nil) -> String {
        buildContext(for: task).toPromptString()
    }

    // MARK: - Pattern Recording

    /// Record task completion to learn patterns
    func recordTaskCompletion(_ task: Task) {
        let category: String
        if let customCategoryID = task.customCategoryID,
           let customCategory = CategoryService.shared.getCategory(byID: customCategoryID) {
            category = customCategory.name
        } else {
            category = task.category.displayName
        }
        let priority = task.priority.displayName
        let duration = task.estimatedDuration.map { Int($0 / 60) }

        userPatterns.recordCompletion(
            category: category,
            priority: priority,
            duration: duration,
            completedAt: Date()
        )

        userPatterns.save()
    }

    // MARK: - Data Fetching

    private func fetchRecentTasks() -> [AIContext.RecentTaskContext] {
        // Fetch recent completed tasks from Core Data
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.completedAt, ascending: false)]
        request.fetchLimit = recentTasksLimit

        do {
            let context = PersistenceController.shared.container.viewContext
            let entities = try context.fetch(request)

            return entities.compactMap { entity -> AIContext.RecentTaskContext? in
                guard let title = entity.title else { return nil }

                let category: String
                if let customCategoryID = entity.customCategoryID,
                   let customCategory = CategoryService.shared.getCategory(byID: customCategoryID) {
                    category = customCategory.name
                } else if let taskCategory = TaskCategory(rawValue: entity.categoryRaw) {
                    category = taskCategory.displayName
                } else {
                    category = "uncategorized"
                }

                let priority = Priority(rawValue: entity.priorityRaw)?.displayName ?? "none"
                let duration = entity.estimatedDuration > 0 ? Int(entity.estimatedDuration / 60) : nil

                return AIContext.RecentTaskContext(
                    title: title,
                    category: category,
                    priority: priority,
                    duration: duration,
                    completedAt: entity.completedAt
                )
            }
        } catch {
            print("Failed to fetch recent tasks: \(error)")
            return []
        }
    }

    private func fetchCustomCategories() -> [String] {
        CategoryService.shared.categories.map { $0.name }
    }

    // MARK: - Analytics

    /// Get context quality score (0-1) based on available data
    var contextQuality: Double {
        var score = 0.0

        // Recent tasks contribute 30%
        let recentTasks = fetchRecentTasks()
        score += min(Double(recentTasks.count) / 10.0, 1.0) * 0.3

        // Patterns contribute 40%
        let patternCount = userPatterns.categoryUsage.count +
                          userPatterns.categoryTimePatterns.count
        score += min(Double(patternCount) / 20.0, 1.0) * 0.4

        // Corrections contribute 30%
        let corrections = learningService.corrections.count
        score += min(Double(corrections) / 10.0, 1.0) * 0.3

        return score
    }

    /// Check if we have enough context for personalized suggestions
    var hasMinimalContext: Bool {
        contextQuality >= 0.2
    }
}
