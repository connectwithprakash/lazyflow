import Foundation

/// Protocol defining the interface for LLM providers
protocol LLMProvider {
    /// Unique identifier for the provider
    var id: String { get }

    /// Display name for UI
    var displayName: String { get }

    /// Whether this provider requires an API key
    var requiresAPIKey: Bool { get }

    /// Whether the provider is available (e.g., device supports it)
    var isAvailable: Bool { get }

    /// Send a prompt and get a response
    func complete(prompt: String) async throws -> String

    /// Send a prompt with system context
    func complete(prompt: String, systemPrompt: String?) async throws -> String
}

extension LLMProvider {
    func complete(prompt: String) async throws -> String {
        try await complete(prompt: prompt, systemPrompt: nil)
    }
}

// MARK: - Provider Types

/// Enum of supported LLM providers
enum LLMProviderType: String, CaseIterable, Codable, Identifiable {
    case apple = "apple"
    case ollama = "ollama"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple Intelligence"
        case .ollama: return "Ollama (Local)"
        case .custom: return "Custom Endpoint"
        }
    }

    var description: String {
        switch self {
        case .apple: return "On-device, free, private"
        case .ollama: return "Run local models on your Mac"
        case .custom: return "Connect to any Open Responses API"
        }
    }

    var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .ollama: return "desktopcomputer"
        case .custom: return "link"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .apple: return false
        case .ollama: return false
        case .custom: return false // May or may not need key
        }
    }

    /// Whether this provider sends data to external servers
    var isExternal: Bool {
        switch self {
        case .apple, .ollama: return false
        case .custom: return true
        }
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case providerUnavailable(String)
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case rateLimited
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let provider):
            return "\(provider) is not available on this device."
        case .noAPIKey:
            return "API key not configured. Please add your API key in Settings."
        case .invalidResponse:
            return "Received invalid response from the AI service."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .modelUnavailable:
            return "The AI model is currently unavailable."
        }
    }
}

// MARK: - Response Models

/// Standard response format from any LLM provider
struct LLMResponse {
    let content: String
    let provider: LLMProviderType
    let tokensUsed: Int?
    let latencyMs: Int?
}
