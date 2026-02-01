import Foundation
import Combine

/// Unified service for LLM-powered task analysis
/// Uses Apple Intelligence for on-device AI processing
final class LLMService: ObservableObject {
    static let shared = LLMService()

    // MARK: - Published Properties

    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?
    @Published var selectedProvider: LLMProviderType {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "llm_provider")
        }
    }

    // MARK: - Providers

    private let appleProvider = AppleFoundationModelsProvider()

    private var currentProvider: LLMProvider {
        return appleProvider
    }

    // MARK: - Initialization

    private init() {
        // Always use Apple Intelligence (only provider)
        self.selectedProvider = .apple

        // Clean up old API keys from removed providers
        UserDefaults.standard.removeObject(forKey: "anthropic_api_key")
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
        UserDefaults.standard.set("apple", forKey: "llm_provider")
    }

    // MARK: - Provider Management

    /// Get all available providers
    var availableProviders: [LLMProviderType] {
        return appleProvider.isAvailable ? [.apple] : []
    }

    /// Check if current provider is ready to use
    var isReady: Bool {
        return appleProvider.isAvailable
    }

    /// Set API key for a provider (Apple Intelligence doesn't need API key)
    func setAPIKey(_ key: String, for provider: LLMProviderType) {
        // No-op: Apple Intelligence doesn't require API keys
    }

    /// Check if provider has API key configured (Apple Intelligence always ready)
    func hasAPIKey(for provider: LLMProviderType) -> Bool {
        return true // Apple Intelligence doesn't require API keys
    }

    // MARK: - Task Analysis

    /// Estimate duration for a task
    func estimateTaskDuration(title: String, notes: String?) async throws -> TaskEstimate {
        let prompt = buildEstimationPrompt(title: title, notes: notes)
        let response = try await sendRequest(prompt: prompt)
        return parseEstimationResponse(response)
    }

    /// Suggest priority level for a task
    func suggestPriority(title: String, notes: String?, dueDate: Date?) async throws -> PrioritySuggestion {
        let prompt = buildPriorityPrompt(title: title, notes: notes, dueDate: dueDate)
        let response = try await sendRequest(prompt: prompt)
        return parsePriorityResponse(response)
    }

    /// Analyze multiple tasks and suggest optimal order
    func suggestTaskOrder(tasks: [Task]) async throws -> [TaskOrderSuggestion] {
        guard !tasks.isEmpty else { return [] }

        let prompt = buildOrderingPrompt(tasks: tasks)
        let response = try await sendRequest(prompt: prompt)
        return parseOrderingResponse(response, tasks: tasks)
    }

    /// Get complete analysis for a task
    func analyzeTask(_ task: Task) async throws -> TaskAnalysis {
        let prompt = buildFullAnalysisPrompt(task: task)
        let response = try await sendRequest(prompt: prompt)
        return parseFullAnalysisResponse(response)
    }

    // MARK: - Raw Completion

    /// Send a raw prompt to the current provider
    func complete(prompt: String, systemPrompt: String? = nil) async throws -> String {
        try await sendRequest(prompt: prompt, systemPrompt: systemPrompt)
    }

    // MARK: - Private Methods

    private func sendRequest(prompt: String, systemPrompt: String? = nil) async throws -> String {
        await MainActor.run { isProcessing = true }
        defer {
            _Concurrency.Task { @MainActor in
                isProcessing = false
            }
        }

        do {
            let response = try await currentProvider.complete(
                prompt: prompt,
                systemPrompt: systemPrompt ?? PromptTemplates.taskAnalysisSystemPrompt
            )
            return response
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            throw error
        }
    }

    // MARK: - Prompt Building

    private func buildEstimationPrompt(title: String, notes: String?) -> String {
        return PromptTemplates.buildDurationEstimationPrompt(title: title, notes: notes)
    }

    private func buildPriorityPrompt(title: String, notes: String?, dueDate: Date?) -> String {
        return PromptTemplates.buildPrioritySuggestionPrompt(title: title, notes: notes, dueDate: dueDate)
    }

    private func buildOrderingPrompt(tasks: [Task]) -> String {
        let taskData = tasks.enumerated().map { index, task in
            (index: index + 1, title: task.title, dueDate: task.dueDate, priority: task.priority.displayName)
        }
        return PromptTemplates.buildTaskOrderingPrompt(tasks: taskData)
    }

    private func buildFullAnalysisPrompt(task: Task) -> String {
        // Get unified context from AIContextService
        let context = AIContextService.shared.buildContext(for: task)

        return PromptTemplates.buildFullAnalysisPrompt(
            task: task,
            learningContext: context.toPromptString(),
            customCategories: context.customCategories
        )
    }

    // MARK: - Response Parsing

    private func parseEstimationResponse(_ response: String) -> TaskEstimate {
        return PromptTemplates.parseDurationResponse(response)
    }

    private func parsePriorityResponse(_ response: String) -> PrioritySuggestion {
        return PromptTemplates.parsePriorityResponse(response)
    }

    private func parseOrderingResponse(_ response: String, tasks: [Task]) -> [TaskOrderSuggestion] {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let order = json["order"] as? [Int] else {
            return tasks.enumerated().map { TaskOrderSuggestion(task: $1, suggestedPosition: $0 + 1) }
        }

        return order.enumerated().compactMap { position, taskNumber in
            guard taskNumber > 0, taskNumber <= tasks.count else { return nil }
            return TaskOrderSuggestion(task: tasks[taskNumber - 1], suggestedPosition: position + 1)
        }
    }

    private func parseFullAnalysisResponse(_ response: String) -> TaskAnalysis {
        return PromptTemplates.parseFullAnalysisResponse(response)
    }

    /// Extract JSON from response that might contain extra text
    private func extractJSON(from response: String) -> Data? {
        // Try direct parsing first
        if let data = response.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        // Try to find JSON in the response
        let pattern = "\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range, in: response) {
            let jsonString = String(response[range])
            return jsonString.data(using: .utf8)
        }

        return nil
    }
}

// MARK: - LLM Response Models

struct TaskEstimate {
    let estimatedMinutes: Int
    let confidence: Confidence
    let reasoning: String

    enum Confidence {
        case low, medium, high
    }

    var estimatedDuration: TimeInterval {
        TimeInterval(estimatedMinutes * 60)
    }
}

struct PrioritySuggestion {
    let priority: Priority
    let reasoning: String
}

struct TaskOrderSuggestion {
    let task: Task
    let suggestedPosition: Int
}

/// Represents a proposed new category that the AI suggests creating
struct ProposedCategory {
    let name: String
    let colorHex: String
    let iconName: String

    /// Default color for proposed categories
    static let defaultColorHex = "#808080"
    /// Default icon for proposed categories
    static let defaultIconName = "tag.fill"
}

struct TaskAnalysis {
    let estimatedMinutes: Int
    let suggestedPriority: Priority
    let bestTime: BestTime
    let suggestedCategory: TaskCategory
    let suggestedCustomCategoryID: UUID?  // When AI suggests a custom category
    let proposedNewCategory: ProposedCategory?  // When AI proposes creating a new category
    let subtasks: [String]
    let tips: String
    let refinedTitle: String?
    let suggestedDescription: String?

    enum BestTime: String {
        case morning = "Morning"
        case afternoon = "Afternoon"
        case evening = "Evening"
        case anytime = "Anytime"
    }

    static var `default`: TaskAnalysis {
        TaskAnalysis(
            estimatedMinutes: 30,
            suggestedPriority: .medium,
            bestTime: .anytime,
            suggestedCategory: .uncategorized,
            suggestedCustomCategoryID: nil,
            proposedNewCategory: nil,
            subtasks: [],
            tips: "",
            refinedTitle: nil,
            suggestedDescription: nil
        )
    }
}
