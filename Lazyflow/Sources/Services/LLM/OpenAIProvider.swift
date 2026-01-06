import Foundation

/// LLM Provider using OpenAI's API
final class OpenAIProvider: LLMProvider {
    let id = "openai"
    let displayName = "OpenAI GPT"
    let requiresAPIKey = true

    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let modelID = "gpt-4.1-mini" // Fast, cost-effective model

    var isAvailable: Bool {
        true // Always available if API key is configured
    }

    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "openai_api_key")
    }

    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
    }

    func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
    }

    func complete(prompt: String, systemPrompt: String?) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw LLMError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = []

        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }

        messages.append(["role": "user", "content": prompt])

        let body: [String: Any] = [
            "model": modelID,
            "messages": messages,
            "max_completion_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.noAPIKey
        case 429:
            throw LLMError.rateLimited
        default:
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMError.apiError(message)
            }
            throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content
    }
}

// MARK: - Model Options

extension OpenAIProvider {
    enum Model: String, CaseIterable {
        case gpt41Mini = "gpt-4.1-mini"
        case gpt4o = "gpt-4o"
        case gpt5Mini = "gpt-5-mini"
        case gpt5 = "gpt-5"

        var displayName: String {
            switch self {
            case .gpt41Mini: return "GPT-4.1 Mini (Fast)"
            case .gpt4o: return "GPT-4o (Balanced)"
            case .gpt5Mini: return "GPT-5 Mini (Advanced)"
            case .gpt5: return "GPT-5 (Most Powerful)"
            }
        }

        var costTier: String {
            switch self {
            case .gpt41Mini: return "$"
            case .gpt4o: return "$$"
            case .gpt5Mini: return "$$$"
            case .gpt5: return "$$$$"
            }
        }
    }
}
