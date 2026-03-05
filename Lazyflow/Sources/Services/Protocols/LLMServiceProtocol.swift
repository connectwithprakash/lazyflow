import Foundation
import LazyflowCore

/// Protocol defining the public API surface of LLMService consumed by ViewModels.
protocol LLMServiceProtocol: AnyObject {
    var isProcessing: Bool { get }
    var errorMessage: String? { get set }
    var selectedProvider: LLMProviderType { get set }
    var availableProviders: [LLMProviderType] { get }
    var isReady: Bool { get }

    // MARK: - Provider Management

    func configureOpenResponses(config: OpenResponsesConfig, providerType: LLMProviderType)
    func removeOpenResponsesProvider(type: LLMProviderType)
    func getOpenResponsesConfig(for providerType: LLMProviderType) -> OpenResponsesConfig?
    func testConnection(config: OpenResponsesConfig) async throws -> Bool
    func setAPIKey(_ key: String, for provider: LLMProviderType)
    func hasAPIKey(for provider: LLMProviderType) -> Bool

    // MARK: - Task Analysis

    func estimateTaskDuration(title: String, notes: String?) async throws -> TaskEstimate
    func suggestPriority(title: String, notes: String?, dueDate: Date?) async throws -> PrioritySuggestion
    func suggestTaskOrder(tasks: [Task], behaviorContext: String?) async throws -> [TaskOrderSuggestion]
    func analyzeTask(_ task: Task) async throws -> TaskAnalysis

    // MARK: - Raw Completion

    func complete(prompt: String, systemPrompt: String?) async throws -> String
}

// MARK: - Default Parameter Values

extension LLMServiceProtocol {
    func suggestTaskOrder(tasks: [Task], behaviorContext: String? = nil) async throws -> [TaskOrderSuggestion] {
        try await suggestTaskOrder(tasks: tasks, behaviorContext: behaviorContext)
    }

    func complete(prompt: String, systemPrompt: String? = nil) async throws -> String {
        try await complete(prompt: prompt, systemPrompt: systemPrompt)
    }
}
