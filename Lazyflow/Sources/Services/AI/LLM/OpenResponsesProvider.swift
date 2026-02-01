import Foundation

/// Configuration for an Open Responses compatible provider
struct OpenResponsesConfig: Codable, Equatable {
    var endpoint: String
    var apiKey: String?
    var model: String

    // MARK: - Default Configurations

    /// Default configuration for OpenRouter
    static var openRouterDefault: OpenResponsesConfig {
        OpenResponsesConfig(
            endpoint: "https://openrouter.ai/api/v1/responses",
            apiKey: nil,
            model: "openai/gpt-4o-mini"
        )
    }

    /// Default configuration for Ollama (local)
    static var ollamaDefault: OpenResponsesConfig {
        OpenResponsesConfig(
            endpoint: "http://localhost:11434/v1/responses",
            apiKey: nil,
            model: "gemma2:2b"
        )
    }

    /// Empty configuration for custom endpoints
    static var customDefault: OpenResponsesConfig {
        OpenResponsesConfig(
            endpoint: "",
            apiKey: nil,
            model: ""
        )
    }
}

/// LLM Provider using the Open Responses standard API
/// Supports any Open Responses compatible service (OpenRouter, Ollama, etc.)
final class OpenResponsesProvider: LLMProvider {
    let id = "openResponses"
    let displayName = "Open Responses"
    let requiresAPIKey = false

    private let config: OpenResponsesConfig
    private let urlSession: URLSession

    var isAvailable: Bool {
        !config.endpoint.isEmpty && !config.model.isEmpty
    }

    // MARK: - Initialization

    init(config: OpenResponsesConfig, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    // MARK: - LLMProvider Protocol

    func complete(prompt: String, systemPrompt: String?) async throws -> String {
        let request = try buildRequest(prompt: prompt, systemPrompt: systemPrompt)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try parseResponse(data: data)
        case 401:
            throw LLMError.noAPIKey
        case 429:
            throw LLMError.rateLimited
        case 503:
            throw LLMError.modelUnavailable
        default:
            // Try to parse error message
            if let errorContent = try? parseErrorResponse(data: data) {
                throw LLMError.apiError(errorContent)
            }
            throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
        }
    }

    // MARK: - Request Building

    func buildRequest(prompt: String, systemPrompt: String?) throws -> URLRequest {
        guard let url = URL(string: config.endpoint) else {
            throw LLMError.apiError("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if configured
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Build request body per Open Responses spec
        var body: [String: Any] = [
            "model": config.model
        ]

        if let systemPrompt = systemPrompt {
            // Use structured input with messages
            body["input"] = [
                ["type": "message", "role": "system", "content": systemPrompt],
                ["type": "message", "role": "user", "content": prompt]
            ]
        } else {
            // Simple string input
            body["input"] = prompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Response Parsing

    func parseResponse(data: Data) throws -> String {
        // First check for error response
        if let errorMessage = try? parseErrorResponse(data: data) {
            throw LLMError.apiError(errorMessage)
        }

        // Parse Open Responses format
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [[String: Any]],
              !output.isEmpty else {
            throw LLMError.invalidResponse
        }

        // Extract text from output messages
        var textContent = ""

        for item in output {
            guard let type = item["type"] as? String,
                  type == "message",
                  let content = item["content"] as? [[String: Any]] else {
                continue
            }

            for contentBlock in content {
                if let blockType = contentBlock["type"] as? String,
                   blockType == "output_text",
                   let text = contentBlock["text"] as? String {
                    textContent += text
                }
            }
        }

        guard !textContent.isEmpty else {
            throw LLMError.invalidResponse
        }

        return textContent
    }

    private func parseErrorResponse(data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
}

// MARK: - Configuration Persistence

extension OpenResponsesConfig {
    private static let userDefaultsPrefix = "openResponsesConfig_"

    /// Save configuration for a specific provider type
    func save(for providerType: LLMProviderType) {
        let key = Self.userDefaultsPrefix + providerType.rawValue
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }

        // Store API key securely in Keychain if present
        if let apiKey = apiKey, !apiKey.isEmpty {
            KeychainHelper.save(apiKey, forKey: "llm_apikey_\(providerType.rawValue)")
        }
    }

    /// Load configuration for a specific provider type
    static func load(for providerType: LLMProviderType) -> OpenResponsesConfig? {
        let key = userDefaultsPrefix + providerType.rawValue
        guard let data = UserDefaults.standard.data(forKey: key),
              var config = try? JSONDecoder().decode(OpenResponsesConfig.self, from: data) else {
            return nil
        }

        // Load API key from Keychain
        if let apiKey = KeychainHelper.load(forKey: "llm_apikey_\(providerType.rawValue)") {
            config.apiKey = apiKey
        }

        return config
    }

    /// Delete configuration for a specific provider type
    static func delete(for providerType: LLMProviderType) {
        let key = userDefaultsPrefix + providerType.rawValue
        UserDefaults.standard.removeObject(forKey: key)
        KeychainHelper.delete(forKey: "llm_apikey_\(providerType.rawValue)")
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
