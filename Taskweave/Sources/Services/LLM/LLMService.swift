import Foundation
import Combine

/// Unified service for LLM-powered task analysis
/// Supports multiple providers: Apple Intelligence, Anthropic, OpenAI
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
    private let anthropicProvider = AnthropicProvider()
    private let openaiProvider = OpenAIProvider()

    private var currentProvider: LLMProvider {
        switch selectedProvider {
        case .apple: return appleProvider
        case .anthropic: return anthropicProvider
        case .openai: return openaiProvider
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: "llm_provider"),
           let provider = LLMProviderType(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            // Default to Apple if available, otherwise Anthropic
            self.selectedProvider = appleProvider.isAvailable ? .apple : .anthropic
        }
    }

    // MARK: - Provider Management

    /// Get all available providers
    var availableProviders: [LLMProviderType] {
        LLMProviderType.allCases.filter { type in
            switch type {
            case .apple: return appleProvider.isAvailable
            case .anthropic: return true
            case .openai: return true
            }
        }
    }

    /// Check if current provider is ready to use
    var isReady: Bool {
        switch selectedProvider {
        case .apple:
            return appleProvider.isAvailable
        case .anthropic:
            return anthropicProvider.hasAPIKey
        case .openai:
            return openaiProvider.hasAPIKey
        }
    }

    /// Set API key for a provider
    func setAPIKey(_ key: String, for provider: LLMProviderType) {
        switch provider {
        case .apple:
            break // No API key needed
        case .anthropic:
            anthropicProvider.setAPIKey(key)
        case .openai:
            openaiProvider.setAPIKey(key)
        }
    }

    /// Check if provider has API key configured
    func hasAPIKey(for provider: LLMProviderType) -> Bool {
        switch provider {
        case .apple:
            return true
        case .anthropic:
            return anthropicProvider.hasAPIKey
        case .openai:
            return openaiProvider.hasAPIKey
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
                systemPrompt: systemPrompt ?? "You are a productivity assistant helping with task management. Respond in JSON format only."
            )
            return response
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            throw error
        }
    }

    // MARK: - Prompt Building

    private func buildEstimationPrompt(title: String, notes: String?) -> String {
        var prompt = """
        Estimate the duration for this task:

        Task: \(title)
        """

        if let notes = notes, !notes.isEmpty {
            prompt += "\nDetails: \(notes)"
        }

        prompt += """

        Consider complexity, typical time for similar tasks, and any implied subtasks.

        Respond in JSON format only:
        {
            "estimated_minutes": <number>,
            "confidence": "<low|medium|high>",
            "reasoning": "<brief explanation>"
        }
        """

        return prompt
    }

    private func buildPriorityPrompt(title: String, notes: String?, dueDate: Date?) -> String {
        var prompt = """
        Suggest a priority level for this task:

        Task: \(title)
        """

        if let notes = notes, !notes.isEmpty {
            prompt += "\nDetails: \(notes)"
        }

        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            prompt += "\nDue: \(formatter.string(from: dueDate))"
        }

        prompt += """

        Consider urgency, importance, and impact of delay.

        Respond in JSON format only:
        {
            "priority": "<none|low|medium|high|urgent>",
            "reasoning": "<brief explanation>"
        }
        """

        return prompt
    }

    private func buildOrderingPrompt(tasks: [Task]) -> String {
        let taskList = tasks.enumerated().map { index, task in
            var item = "\(index + 1). \(task.title)"
            if let dueDate = task.dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                item += " (Due: \(formatter.string(from: dueDate)))"
            }
            item += " [Priority: \(task.priority.displayName)]"
            return item
        }.joined(separator: "\n")

        return """
        Suggest the optimal order to complete these tasks:

        \(taskList)

        Consider due dates, dependencies, energy levels, and quick wins.

        Respond in JSON format only:
        {
            "order": [<task numbers in suggested order>],
            "reasoning": "<brief explanation>"
        }
        """
    }

    private func buildFullAnalysisPrompt(task: Task) -> String {
        var prompt = """
        Analyze this task completely:

        Title: \(task.title)
        """

        if let notes = task.notes, !notes.isEmpty {
            prompt += "\nDetails: \(notes)"
        }

        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            prompt += "\nDue: \(formatter.string(from: dueDate))"
        }

        prompt += "\nCurrent Priority: \(task.priority.displayName)"

        prompt += """

        Provide complete analysis including duration, priority, best time, category, refined title, suggested description, subtasks, and tips.

        Respond in JSON format only:
        {
            "estimated_minutes": <number>,
            "suggested_priority": "<none|low|medium|high|urgent>",
            "best_time": "<morning|afternoon|evening|anytime>",
            "category": "<work|personal|health|finance|shopping|errands|learning|home>",
            "refined_title": "<improved title or null if original is good>",
            "suggested_description": "<helpful description or null if not needed>",
            "subtasks": [<list of suggested subtask strings>],
            "tips": "<productivity tip>"
        }
        """

        return prompt
    }

    // MARK: - Response Parsing

    private func parseEstimationResponse(_ response: String) -> TaskEstimate {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return TaskEstimate(estimatedMinutes: 30, confidence: .low, reasoning: "Could not parse response")
        }

        let minutes = json["estimated_minutes"] as? Int ?? 30
        let confidenceStr = json["confidence"] as? String ?? "low"
        let reasoning = json["reasoning"] as? String ?? ""

        let confidence: TaskEstimate.Confidence
        switch confidenceStr.lowercased() {
        case "high": confidence = .high
        case "medium": confidence = .medium
        default: confidence = .low
        }

        return TaskEstimate(estimatedMinutes: minutes, confidence: confidence, reasoning: reasoning)
    }

    private func parsePriorityResponse(_ response: String) -> PrioritySuggestion {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return PrioritySuggestion(priority: .medium, reasoning: "Could not parse response")
        }

        let priorityStr = json["priority"] as? String ?? "medium"
        let reasoning = json["reasoning"] as? String ?? ""

        let priority: Priority
        switch priorityStr.lowercased() {
        case "urgent": priority = .urgent
        case "high": priority = .high
        case "medium": priority = .medium
        case "low": priority = .low
        default: priority = .none
        }

        return PrioritySuggestion(priority: priority, reasoning: reasoning)
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
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return TaskAnalysis.default
        }

        let minutes = json["estimated_minutes"] as? Int ?? 30

        let priorityStr = json["suggested_priority"] as? String ?? "medium"
        let priority: Priority
        switch priorityStr.lowercased() {
        case "urgent": priority = .urgent
        case "high": priority = .high
        case "medium": priority = .medium
        case "low": priority = .low
        default: priority = .none
        }

        let bestTimeStr = json["best_time"] as? String ?? "anytime"
        let bestTime: TaskAnalysis.BestTime
        switch bestTimeStr.lowercased() {
        case "morning": bestTime = .morning
        case "afternoon": bestTime = .afternoon
        case "evening": bestTime = .evening
        default: bestTime = .anytime
        }

        let categoryStr = json["category"] as? String ?? "uncategorized"
        let category: TaskCategory
        switch categoryStr.lowercased() {
        case "work": category = .work
        case "personal": category = .personal
        case "health": category = .health
        case "finance": category = .finance
        case "shopping": category = .shopping
        case "errands": category = .errands
        case "learning": category = .learning
        case "home": category = .home
        default: category = .uncategorized
        }

        let subtasks = json["subtasks"] as? [String] ?? []
        let tips = json["tips"] as? String ?? ""

        // Parse new fields - handle null values
        let refinedTitle = json["refined_title"] as? String
        let suggestedDescription = json["suggested_description"] as? String

        return TaskAnalysis(
            estimatedMinutes: minutes,
            suggestedPriority: priority,
            bestTime: bestTime,
            suggestedCategory: category,
            subtasks: subtasks,
            tips: tips,
            refinedTitle: refinedTitle,
            suggestedDescription: suggestedDescription
        )
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
