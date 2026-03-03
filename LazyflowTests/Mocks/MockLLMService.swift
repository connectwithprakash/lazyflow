import Foundation
@testable import Lazyflow

/// Mock LLMService returning canned responses for testing.
final class MockLLMService: LLMServiceProtocol {
    private(set) var isProcessing: Bool = false
    var errorMessage: String?
    var selectedProvider: LLMProviderType = .apple
    var availableProviders: [LLMProviderType] = [.apple]
    var isReady: Bool = true

    private(set) var calls: [String] = []

    // MARK: - Canned Responses

    var stubbedEstimate = TaskEstimate(estimatedMinutes: 30, confidence: .medium, reasoning: "Mock estimate")
    var stubbedPriority = PrioritySuggestion(priority: .medium, reasoning: "Mock suggestion")
    var stubbedAnalysis: TaskAnalysis?
    var stubbedCompletion = "Mock completion response"

    // MARK: - Provider Management

    func configureOpenResponses(config: OpenResponsesConfig, providerType: LLMProviderType) {
        calls.append("configureOpenResponses")
    }

    func removeOpenResponsesProvider(type: LLMProviderType) {
        calls.append("removeOpenResponsesProvider")
    }

    func getOpenResponsesConfig(for providerType: LLMProviderType) -> OpenResponsesConfig? {
        calls.append("getOpenResponsesConfig")
        return nil
    }

    func testConnection(config: OpenResponsesConfig) async throws -> Bool {
        calls.append("testConnection")
        return true
    }

    func setAPIKey(_ key: String, for provider: LLMProviderType) {
        calls.append("setAPIKey")
    }

    func hasAPIKey(for provider: LLMProviderType) -> Bool {
        calls.append("hasAPIKey")
        return false
    }

    // MARK: - Task Analysis

    func estimateTaskDuration(title: String, notes: String?) async throws -> TaskEstimate {
        calls.append("estimateTaskDuration")
        return stubbedEstimate
    }

    func suggestPriority(title: String, notes: String?, dueDate: Date?) async throws -> PrioritySuggestion {
        calls.append("suggestPriority")
        return stubbedPriority
    }

    func suggestTaskOrder(tasks: [Task], behaviorContext: String?) async throws -> [TaskOrderSuggestion] {
        calls.append("suggestTaskOrder")
        return []
    }

    func analyzeTask(_ task: Task) async throws -> TaskAnalysis {
        calls.append("analyzeTask")
        if let analysis = stubbedAnalysis {
            return analysis
        }
        throw LLMError.notAvailable
    }

    // MARK: - Raw Completion

    func complete(prompt: String, systemPrompt: String?) async throws -> String {
        calls.append("complete")
        return stubbedCompletion
    }
}

private enum LLMError: Error {
    case notAvailable
}
