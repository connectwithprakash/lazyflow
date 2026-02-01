import Foundation
import Combine

/// Unified service for LLM-powered task analysis
/// Supports Apple Intelligence (default) and Open Responses compatible providers
final class LLMService: ObservableObject {
    static let shared = LLMService()

    // MARK: - Published Properties

    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?
    @Published var selectedProvider: LLMProviderType {
        didSet {
            // Only save if provider is available
            if availableProviders.contains(selectedProvider) {
                UserDefaults.standard.set(selectedProvider.rawValue, forKey: "llm_provider")
            } else {
                // Fall back to Apple if selected provider is not available
                selectedProvider = .apple
            }
        }
    }

    // MARK: - Providers

    private let appleProvider = AppleFoundationModelsProvider()
    private var openResponsesProviders: [LLMProviderType: OpenResponsesProvider] = [:]

    private var currentProvider: LLMProvider {
        switch selectedProvider {
        case .apple:
            return appleProvider
        case .ollama, .custom:
            return openResponsesProviders[selectedProvider] ?? appleProvider
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: "llm_provider"),
           let providerType = LLMProviderType(rawValue: savedProvider) {
            self.selectedProvider = providerType
        } else {
            self.selectedProvider = .apple
        }

        // Load any configured Open Responses providers
        loadConfiguredProviders()

        // Clean up old API keys from removed providers (pre-v1.4)
        UserDefaults.standard.removeObject(forKey: "anthropic_api_key")
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
    }

    /// Load configured Open Responses providers from storage
    private func loadConfiguredProviders() {
        for providerType in [LLMProviderType.ollama, .custom] {
            if let config = OpenResponsesConfig.load(for: providerType) {
                openResponsesProviders[providerType] = OpenResponsesProvider(config: config)
            }
        }
    }

    // MARK: - Provider Management

    /// Get all available providers
    var availableProviders: [LLMProviderType] {
        var providers: [LLMProviderType] = []

        // Apple Intelligence is always first if available
        if appleProvider.isAvailable {
            providers.append(.apple)
        }

        // Add configured Open Responses providers
        for (type, provider) in openResponsesProviders {
            if provider.isAvailable {
                providers.append(type)
            }
        }

        return providers
    }

    /// Check if current provider is ready to use
    var isReady: Bool {
        return currentProvider.isAvailable
    }

    /// Configure an Open Responses provider
    func configureOpenResponses(config: OpenResponsesConfig, providerType: LLMProviderType) {
        guard providerType != .apple else { return }

        // Save configuration
        config.save(for: providerType)

        // Create and store provider
        openResponsesProviders[providerType] = OpenResponsesProvider(config: config)
    }

    /// Remove an Open Responses provider configuration
    func removeOpenResponsesProvider(type: LLMProviderType) {
        guard type != .apple else { return }

        OpenResponsesConfig.delete(for: type)
        openResponsesProviders.removeValue(forKey: type)

        // If this was the selected provider, fall back to Apple
        if selectedProvider == type {
            selectedProvider = .apple
        }
    }

    /// Get configuration for an Open Responses provider
    func getOpenResponsesConfig(for providerType: LLMProviderType) -> OpenResponsesConfig? {
        return OpenResponsesConfig.load(for: providerType)
    }

    /// Test connection to an Open Responses provider
    func testConnection(config: OpenResponsesConfig) async throws -> Bool {
        let provider = OpenResponsesProvider(config: config)
        _ = try await provider.complete(prompt: "Hello", systemPrompt: nil)
        return true
    }

    /// Set API key for a provider
    func setAPIKey(_ key: String, for provider: LLMProviderType) {
        guard provider != .apple else { return }

        if var config = OpenResponsesConfig.load(for: provider) {
            config.apiKey = key
            config.save(for: provider)
            openResponsesProviders[provider] = OpenResponsesProvider(config: config)
        }
    }

    /// Check if provider has API key configured
    func hasAPIKey(for provider: LLMProviderType) -> Bool {
        switch provider {
        case .apple:
            return true // Doesn't need API key
        case .ollama:
            return true // Local, doesn't need API key
        case .custom:
            if let config = OpenResponsesConfig.load(for: provider) {
                return config.apiKey != nil && !config.apiKey!.isEmpty
            }
            return false
        }
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
