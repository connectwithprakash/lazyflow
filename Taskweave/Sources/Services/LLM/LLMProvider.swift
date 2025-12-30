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
    case anthropic = "anthropic"
    case openai = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple Intelligence"
        case .anthropic: return "Anthropic Claude"
        case .openai: return "OpenAI GPT"
        }
    }

    var description: String {
        switch self {
        case .apple: return "On-device, free, private"
        case .anthropic: return "Claude 3 Haiku, requires API key"
        case .openai: return "GPT-4.1 Mini, requires API key"
        }
    }

    var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .anthropic: return "brain.head.profile"
        case .openai: return "globe"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .apple: return false
        case .anthropic, .openai: return true
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
