import Foundation

/// LLM Provider using Anthropic's Claude API
final class AnthropicProvider: LLMProvider {
    let id = "anthropic"
    let displayName = "Anthropic Claude"
    let requiresAPIKey = true

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let modelID = "claude-3-haiku-20240307"
    private let apiVersion = "2023-06-01"

    var isAvailable: Bool {
        true // Always available if API key is configured
    }

    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "anthropic_api_key")
    }

    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "anthropic_api_key")
    }

    func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: "anthropic_api_key")
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
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": modelID,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        if let systemPrompt = systemPrompt {
            body["system"] = systemPrompt
        }

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
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return text
    }
}

// MARK: - Model Options

extension AnthropicProvider {
    enum Model: String, CaseIterable {
        case haiku = "claude-3-haiku-20240307"
        case sonnet = "claude-3-5-sonnet-20241022"
        case opus = "claude-3-opus-20240229"

        var displayName: String {
            switch self {
            case .haiku: return "Claude 3 Haiku (Fast)"
            case .sonnet: return "Claude 3.5 Sonnet (Balanced)"
            case .opus: return "Claude 3 Opus (Powerful)"
            }
        }

        var costTier: String {
            switch self {
            case .haiku: return "$"
            case .sonnet: return "$$"
            case .opus: return "$$$"
            }
        }
    }
}
