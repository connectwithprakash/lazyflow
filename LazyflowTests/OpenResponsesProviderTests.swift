import XCTest
@testable import Lazyflow

final class OpenResponsesProviderTests: XCTestCase {

    var sut: OpenResponsesProvider!

    override func setUp() {
        super.setUp()
        // Reset any stored configuration in UserDefaults
        // Note: We avoid touching LLMService.shared in tests due to Keychain access
        // issues in CI environments. Test the components directly instead.
        UserDefaults.standard.removeObject(forKey: "openResponsesConfig")
    }

    override func tearDown() {
        sut = nil
        UserDefaults.standard.removeObject(forKey: "openResponsesConfig")
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testOpenResponsesConfig_Initialization() {
        // Given
        let config = OpenResponsesConfig(
            endpoint: "https://api.openrouter.ai/v1/responses",
            apiKey: "test-key",
            model: "openai/gpt-4"
        )

        // Then
        XCTAssertEqual(config.endpoint, "https://api.openrouter.ai/v1/responses")
        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.model, "openai/gpt-4")
    }

    func testOpenResponsesConfig_Codable() throws {
        // Given
        let config = OpenResponsesConfig(
            endpoint: "https://localhost:11434/v1/responses",
            apiKey: nil,
            model: "llama2"
        )

        // When
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(OpenResponsesConfig.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.endpoint, config.endpoint)
        XCTAssertEqual(decoded.model, config.model)
        // apiKey is intentionally excluded from Codable (stored in Keychain only)
        XCTAssertNil(decoded.apiKey, "API key should NOT be encoded - it's stored in Keychain only")
    }

    func testOpenResponsesConfig_ApiKeyExcludedFromEncoding() throws {
        // Given - config WITH an API key
        let config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "secret-api-key-12345",
            model: "gpt-4"
        )

        // When - encode to JSON
        let encoded = try JSONEncoder().encode(config)
        let jsonString = String(data: encoded, encoding: .utf8)!

        // Then - API key should NOT appear in the encoded data (security fix)
        XCTAssertFalse(jsonString.contains("secret-api-key"), "API key must NOT be encoded to UserDefaults")
        XCTAssertFalse(jsonString.contains("apiKey"), "apiKey field must NOT be in encoded JSON")
        XCTAssertTrue(jsonString.contains("endpoint"), "endpoint should be encoded")
        XCTAssertTrue(jsonString.contains("model"), "model should be encoded")
    }

    func testOpenResponsesConfig_DefaultEndpoints() {
        // Ollama local
        XCTAssertEqual(
            OpenResponsesConfig.ollamaDefault.endpoint,
            "http://localhost:11434/v1/responses"
        )

        // Custom (empty by default)
        XCTAssertEqual(
            OpenResponsesConfig.customDefault.endpoint,
            ""
        )
    }

    // MARK: - Provider Initialization Tests

    func testOpenResponsesProvider_Initialization_WithConfig() {
        // Given
        let config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: "test-model"
        )

        // When
        sut = OpenResponsesProvider(config: config)

        // Then
        XCTAssertEqual(sut.id, "openResponses")
        XCTAssertEqual(sut.displayName, "Open Responses")
        XCTAssertTrue(sut.isAvailable)
    }

    func testOpenResponsesProvider_RequiresAPIKey_WhenConfigured() {
        // Given - config with API key
        let configWithKey = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: "test-model"
        )
        sut = OpenResponsesProvider(config: configWithKey)

        // Then
        XCTAssertFalse(sut.requiresAPIKey) // Already has key

        // Given - config without API key (like Ollama)
        let configNoKey = OpenResponsesConfig(
            endpoint: "http://localhost:11434/v1/responses",
            apiKey: nil,
            model: "llama2"
        )
        sut = OpenResponsesProvider(config: configNoKey)

        // Then - local providers don't require API key
        XCTAssertFalse(sut.requiresAPIKey)
    }

    // MARK: - Request Building Tests

    func testBuildRequest_BasicPrompt() throws {
        // Given
        let config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: "gpt-4"
        )
        sut = OpenResponsesProvider(config: config)

        // When
        let request = try sut.buildRequest(prompt: "Hello", systemPrompt: nil)

        // Then
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.test.com/v1/responses")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

        // Verify body
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "gpt-4")
        XCTAssertEqual(body["input"] as? String, "Hello")
    }

    func testBuildRequest_WithSystemPrompt() throws {
        // Given
        let config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: "gpt-4"
        )
        sut = OpenResponsesProvider(config: config)

        // When
        let request = try sut.buildRequest(
            prompt: "What is 2+2?",
            systemPrompt: "You are a math tutor."
        )

        // Then - verify body contains input array with messages
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let input = body["input"] as! [[String: Any]]

        XCTAssertEqual(input.count, 2)
        XCTAssertEqual(input[0]["role"] as? String, "system")
        XCTAssertEqual(input[0]["content"] as? String, "You are a math tutor.")
        XCTAssertEqual(input[1]["role"] as? String, "user")
        XCTAssertEqual(input[1]["content"] as? String, "What is 2+2?")
    }

    func testBuildRequest_NoAPIKey_OmitsAuthHeader() throws {
        // Given - Ollama-style local config without API key
        let config = OpenResponsesConfig(
            endpoint: "http://localhost:11434/v1/responses",
            apiKey: nil,
            model: "llama2"
        )
        sut = OpenResponsesProvider(config: config)

        // When
        let request = try sut.buildRequest(prompt: "Hello", systemPrompt: nil)

        // Then - no Authorization header
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Response Parsing Tests

    func testParseResponse_ValidJSON() throws {
        // Given
        let responseJSON = """
        {
            "id": "resp_123",
            "output": [
                {
                    "type": "message",
                    "role": "assistant",
                    "content": [
                        {
                            "type": "output_text",
                            "text": "Hello! How can I help you?"
                        }
                    ]
                }
            ],
            "status": "completed"
        }
        """.data(using: .utf8)!

        sut = OpenResponsesProvider(config: .ollamaDefault)

        // When
        let content = try sut.parseResponse(data: responseJSON)

        // Then
        XCTAssertEqual(content, "Hello! How can I help you?")
    }

    func testParseResponse_MultipleTextBlocks() throws {
        // Given
        let responseJSON = """
        {
            "id": "resp_123",
            "output": [
                {
                    "type": "message",
                    "role": "assistant",
                    "content": [
                        {"type": "output_text", "text": "First part. "},
                        {"type": "output_text", "text": "Second part."}
                    ]
                }
            ],
            "status": "completed"
        }
        """.data(using: .utf8)!

        sut = OpenResponsesProvider(config: .ollamaDefault)

        // When
        let content = try sut.parseResponse(data: responseJSON)

        // Then
        XCTAssertEqual(content, "First part. Second part.")
    }

    func testParseResponse_EmptyOutput_ThrowsError() {
        // Given
        let responseJSON = """
        {
            "id": "resp_123",
            "output": [],
            "status": "completed"
        }
        """.data(using: .utf8)!

        sut = OpenResponsesProvider(config: .ollamaDefault)

        // Then
        XCTAssertThrowsError(try sut.parseResponse(data: responseJSON)) { error in
            XCTAssertEqual(error as? LLMError, LLMError.invalidResponse)
        }
    }

    func testParseResponse_APIError_ThrowsError() {
        // Given
        let errorJSON = """
        {
            "error": {
                "message": "Invalid API key",
                "type": "authentication_error"
            }
        }
        """.data(using: .utf8)!

        sut = OpenResponsesProvider(config: .ollamaDefault)

        // Then
        XCTAssertThrowsError(try sut.parseResponse(data: errorJSON)) { error in
            if case LLMError.apiError(let message) = error {
                XCTAssertTrue(message.contains("Invalid API key"))
            } else {
                XCTFail("Expected apiError")
            }
        }
    }

    // MARK: - Provider Type Tests

    func testLLMProviderType_OpenResponses() {
        // Test Ollama
        XCTAssertEqual(LLMProviderType.ollama.displayName, "Ollama (Local)")
        XCTAssertFalse(LLMProviderType.ollama.requiresAPIKey)
        XCTAssertEqual(LLMProviderType.ollama.iconName, "desktopcomputer")

        // Test Custom
        XCTAssertEqual(LLMProviderType.custom.displayName, "Custom Endpoint")
        XCTAssertFalse(LLMProviderType.custom.requiresAPIKey) // May or may not need key
        XCTAssertEqual(LLMProviderType.custom.iconName, "link")
    }

    func testLLMProviderType_Descriptions() {
        XCTAssertTrue(LLMProviderType.apple.description.contains("On-device"))
        XCTAssertTrue(LLMProviderType.ollama.description.contains("local"))
        XCTAssertTrue(LLMProviderType.custom.description.contains("Open Responses"))
    }

    // MARK: - Provider Availability Tests
    // Note: These tests verify OpenResponsesProvider behavior directly without
    // using LLMService.shared, which avoids Keychain access issues in CI.

    func testOpenResponsesProvider_IsAvailable_WhenConfigured() {
        // Given - a fully configured provider
        let config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: "test-model"
        )

        // When
        let provider = OpenResponsesProvider(config: config)

        // Then - provider should be available
        XCTAssertTrue(provider.isAvailable)
    }

    func testOpenResponsesProvider_NotAvailable_WhenEndpointEmpty() {
        // Given - config with empty endpoint
        let config = OpenResponsesConfig(
            endpoint: "",
            apiKey: "test-key",
            model: "test-model"
        )

        // When
        let provider = OpenResponsesProvider(config: config)

        // Then - provider should not be available
        XCTAssertFalse(provider.isAvailable)
    }

    func testOpenResponsesProvider_NotAvailable_WhenModelEmpty() {
        // Given - config with empty model
        let config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: ""
        )

        // When
        let provider = OpenResponsesProvider(config: config)

        // Then - provider should not be available
        XCTAssertFalse(provider.isAvailable)
    }

    // MARK: - Model Configuration Tests

    func testOpenResponsesConfig_StoresModelCorrectly() {
        // Given - config with specific model
        let config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: "model-a"
        )

        // Then - model should be stored
        XCTAssertEqual(config.model, "model-a")
    }

    func testOpenResponsesConfig_CanChangeModel() {
        // Given - initial config with model A
        var config = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "test-key",
            model: "model-a"
        )

        // When - change to model B
        config.model = "model-b"

        // Then - model should be updated
        XCTAssertEqual(config.model, "model-b")
        // Endpoint should remain unchanged
        XCTAssertEqual(config.endpoint, "https://api.test.com/v1/responses")
    }

    func testOpenResponsesConfig_SameEndpointDifferentModels() {
        // Given - two configs with same endpoint but different models
        let configA = OpenResponsesConfig(
            endpoint: "http://localhost:11434/v1/responses",
            apiKey: nil,
            model: "gemma2:2b"
        )
        let configB = OpenResponsesConfig(
            endpoint: "http://localhost:11434/v1/responses",
            apiKey: nil,
            model: "qwen2.5:1.5b"
        )

        // Then - endpoints match, models differ
        XCTAssertEqual(configA.endpoint, configB.endpoint)
        XCTAssertNotEqual(configA.model, configB.model)
        XCTAssertEqual(configA.model, "gemma2:2b")
        XCTAssertEqual(configB.model, "qwen2.5:1.5b")
    }

    func testOpenResponsesConfig_Equatable() {
        // Given - two identical configs
        let config1 = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "key",
            model: "model"
        )
        let config2 = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "key",
            model: "model"
        )

        // Then - should be equal
        XCTAssertEqual(config1, config2)
    }

    func testOpenResponsesConfig_NotEqual_DifferentModels() {
        // Given - configs with different models
        let config1 = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "key",
            model: "model-a"
        )
        let config2 = OpenResponsesConfig(
            endpoint: "https://api.test.com/v1/responses",
            apiKey: "key",
            model: "model-b"
        )

        // Then - should not be equal
        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - AvailableModel Tests

    func testAvailableModel_DisplayName_RemovesProviderPrefix() {
        // Given - model with provider prefix
        let model = AvailableModel.parse(
            id: "openai/gpt-4",
            name: "OpenAI: GPT-4",
            description: "Latest GPT-4 model",
            isFree: false
        )

        // Then
        XCTAssertEqual(model.provider, "OpenAI")
        XCTAssertEqual(model.displayName, "GPT-4")
    }

    func testAvailableModel_DisplayName_NoPrefix() {
        // Given - model without provider prefix
        let model = AvailableModel(
            id: "gemma2:2b",
            name: "gemma2:2b",
            provider: "Ollama",
            description: "2.6 GB",
            isFree: true
        )

        // Then - displayName should be same as name
        XCTAssertEqual(model.displayName, "gemma2:2b")
    }

    func testAvailableModel_FreeFlag() {
        // Given - free model
        let freeModel = AvailableModel.parse(
            id: "free/model",
            name: "Free Model",
            description: nil,
            isFree: true
        )

        // Given - paid model
        let paidModel = AvailableModel.parse(
            id: "paid/model",
            name: "Paid Model",
            description: nil,
            isFree: false
        )

        // Then
        XCTAssertTrue(freeModel.isFree)
        XCTAssertFalse(paidModel.isFree)
    }

    // MARK: - Live Integration Tests (requires Ollama running)

    /// Test actual call to Ollama Open Responses endpoint
    /// Requires: Ollama running locally with gemma2:2b model
    func testOllamaIntegration_LiveCall() async throws {
        // Check if Ollama is running
        let tagsURL = URL(string: "http://localhost:11434/api/tags")!
        do {
            let (data, _) = try await URLSession.shared.data(from: tagsURL)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]],
                  !models.isEmpty else {
                throw XCTSkip("Ollama not running or no models available")
            }
        } catch {
            throw XCTSkip("Ollama not available: \(error.localizedDescription)")
        }

        // Create provider with Ollama config
        let config = OpenResponsesConfig(
            endpoint: "http://localhost:11434/v1/responses",
            apiKey: nil,
            model: "gemma2:2b"
        )
        let provider = OpenResponsesProvider(config: config)

        // Make actual call
        let response = try await provider.complete(
            prompt: "What is 2+2? Answer with just the number.",
            systemPrompt: "You are a math assistant. Be concise."
        )

        // Verify response
        XCTAssertFalse(response.isEmpty, "Should receive a response")
        print("Ollama response: \(response)")

        // Response should contain "4"
        XCTAssertTrue(response.contains("4"), "Response should contain the answer 4")
    }

    /// Test model discovery from live Ollama instance
    func testOllamaIntegration_ModelDiscovery() async throws {
        do {
            let models = try await OpenResponsesConfig.fetchAvailableModels(
                endpoint: "http://localhost:11434/v1/responses",
                apiKey: nil,
                for: .ollama
            )

            XCTAssertFalse(models.isEmpty, "Should find models from Ollama")
            print("Found \(models.count) models from Ollama:")
            for model in models {
                print("  - \(model.name) (\(model.description ?? "no description"))")
            }
        } catch {
            throw XCTSkip("Ollama not available: \(error.localizedDescription)")
        }
    }
}

// MARK: - LLMError Equatable for Testing

extension LLMError: Equatable {
    public static func == (lhs: LLMError, rhs: LLMError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse):
            return true
        case (.noAPIKey, .noAPIKey):
            return true
        case (.rateLimited, .rateLimited):
            return true
        case (.modelUnavailable, .modelUnavailable):
            return true
        case let (.providerUnavailable(l), .providerUnavailable(r)):
            return l == r
        case let (.apiError(l), .apiError(r)):
            return l == r
        default:
            return false
        }
    }
}
