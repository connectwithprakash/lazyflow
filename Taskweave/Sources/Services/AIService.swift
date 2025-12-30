import Foundation
import Combine

/// Service for AI-powered task analysis using Claude API
final class AIService: ObservableObject {
    static let shared = AIService()

    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let modelID = "claude-3-haiku-20240307" // Fast, cost-effective for task analysis

    private var apiKey: String? {
        // In production, this should be fetched from Keychain or secure storage
        // For now, check UserDefaults or environment
        UserDefaults.standard.string(forKey: "anthropic_api_key")
    }

    private init() {}

    // MARK: - API Configuration

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "anthropic_api_key")
    }

    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    // MARK: - Task Analysis

    /// Estimate duration for a task based on its title and description
    func estimateTaskDuration(title: String, notes: String?) async throws -> TaskEstimate {
        guard hasAPIKey else {
            throw AIServiceError.noAPIKey
        }

        let prompt = buildEstimationPrompt(title: title, notes: notes)
        let response = try await sendRequest(prompt: prompt)

        return parseEstimationResponse(response)
    }

    /// Suggest priority level for a task
    func suggestPriority(title: String, notes: String?, dueDate: Date?) async throws -> PrioritySuggestion {
        guard hasAPIKey else {
            throw AIServiceError.noAPIKey
        }

        let prompt = buildPriorityPrompt(title: title, notes: notes, dueDate: dueDate)
        let response = try await sendRequest(prompt: prompt)

        return parsePriorityResponse(response)
    }

    /// Analyze multiple tasks and suggest optimal order
    func suggestTaskOrder(tasks: [Task]) async throws -> [TaskOrderSuggestion] {
        guard hasAPIKey else {
            throw AIServiceError.noAPIKey
        }

        guard !tasks.isEmpty else {
            return []
        }

        let prompt = buildOrderingPrompt(tasks: tasks)
        let response = try await sendRequest(prompt: prompt)

        return parseOrderingResponse(response, tasks: tasks)
    }

    /// Get smart suggestions for a task (duration, priority, best time)
    func analyzeTask(_ task: Task) async throws -> TaskAnalysis {
        guard hasAPIKey else {
            throw AIServiceError.noAPIKey
        }

        let prompt = buildFullAnalysisPrompt(task: task)
        let response = try await sendRequest(prompt: prompt)

        return parseFullAnalysisResponse(response)
    }

    // MARK: - Prompt Building

    private func buildEstimationPrompt(title: String, notes: String?) -> String {
        var prompt = """
        You are a productivity assistant helping estimate task duration.

        Task: \(title)
        """

        if let notes = notes, !notes.isEmpty {
            prompt += "\nDetails: \(notes)"
        }

        prompt += """

        Estimate how long this task will take. Consider:
        - Complexity of the task
        - Typical time for similar tasks
        - Any dependencies or subtasks implied

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
        You are a productivity assistant helping prioritize tasks.

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

        Suggest an appropriate priority level. Consider:
        - Urgency based on due date
        - Importance implied by the task description
        - Impact of delay

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
        You are a productivity assistant helping optimize task order.

        Tasks to order:
        \(taskList)

        Suggest the optimal order to complete these tasks. Consider:
        - Due dates and urgency
        - Task dependencies
        - Energy levels throughout the day
        - Quick wins vs deep work

        Respond in JSON format only:
        {
            "order": [<task numbers in suggested order>],
            "reasoning": "<brief explanation of the ordering strategy>"
        }
        """
    }

    private func buildFullAnalysisPrompt(task: Task) -> String {
        var prompt = """
        You are a productivity assistant for ML/AI engineers.

        Analyze this task:
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

        Provide a complete analysis including:
        1. Estimated duration
        2. Suggested priority
        3. Best time of day to work on this
        4. Category (work, personal, health, finance, shopping, errands, learning, home)
        5. Refined title (clearer, more actionable version if the original can be improved, otherwise null)
        6. Suggested description (helpful context or details for the task, null if not needed)
        7. Any subtasks or dependencies

        Respond in JSON format only:
        {
            "estimated_minutes": <number>,
            "suggested_priority": "<none|low|medium|high|urgent>",
            "best_time": "<morning|afternoon|evening|anytime>",
            "category": "<work|personal|health|finance|shopping|errands|learning|home>",
            "refined_title": "<improved title or null>",
            "suggested_description": "<helpful description or null>",
            "subtasks": [<list of suggested subtask strings>],
            "tips": "<productivity tip for this type of task>"
        }
        """

        return prompt
    }

    // MARK: - API Request

    private func sendRequest(prompt: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AIServiceError.noAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        await MainActor.run { isProcessing = true }
        defer {
            _Concurrency.Task { @MainActor in
                isProcessing = false
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.apiError(message)
            }
            throw AIServiceError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIServiceError.parseError
        }

        return text
    }

    // MARK: - Response Parsing

    private func parseEstimationResponse(_ response: String) -> TaskEstimate {
        guard let data = response.data(using: .utf8),
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
        guard let data = response.data(using: .utf8),
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
        guard let data = response.data(using: .utf8),
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
        guard let data = response.data(using: .utf8),
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
}

// MARK: - Models

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

struct TaskAnalysis {
    let estimatedMinutes: Int
    let suggestedPriority: Priority
    let bestTime: BestTime
    let suggestedCategory: TaskCategory
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
            subtasks: [],
            tips: "",
            refinedTitle: nil,
            suggestedDescription: nil
        )
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured. Please add your Anthropic API key in Settings."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Received invalid response from API."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .parseError:
            return "Could not parse API response."
        }
    }
}
