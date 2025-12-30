import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// LLM Provider using Apple's on-device Foundation Models (iOS 18.4+)
final class AppleFoundationModelsProvider: LLMProvider {
    let id = "apple"
    let displayName = "Apple Intelligence"
    let requiresAPIKey = false

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    func complete(prompt: String, systemPrompt: String?) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await performCompletion(prompt: prompt, systemPrompt: systemPrompt)
        }
        #endif
        throw LLMError.providerUnavailable("Apple Intelligence")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func performCompletion(prompt: String, systemPrompt: String?) async throws -> String {
        do {
            let session = LanguageModelSession()

            // Build the full prompt with system context if provided
            let fullPrompt: String
            if let systemPrompt = systemPrompt {
                fullPrompt = """
                \(systemPrompt)

                \(prompt)
                """
            } else {
                fullPrompt = prompt
            }

            let response = try await session.respond(to: fullPrompt)
            return response.content
        } catch {
            // Map Foundation Models errors to our error types
            throw LLMError.apiError(error.localizedDescription)
        }
    }
    #endif
}

// MARK: - Guided Generation Support (iOS 26.0+)

#if canImport(FoundationModels)
@available(iOS 26.0, *)
extension AppleFoundationModelsProvider {
    /// Perform structured generation with a specific output schema
    func generateStructured<T: Decodable>(
        prompt: String,
        systemPrompt: String?,
        responseType: T.Type
    ) async throws -> T {
        let session = LanguageModelSession()

        let fullPrompt: String
        if let systemPrompt = systemPrompt {
            fullPrompt = "\(systemPrompt)\n\n\(prompt)"
        } else {
            fullPrompt = prompt
        }

        // Request JSON response
        let jsonPrompt = """
        \(fullPrompt)

        Respond with valid JSON only, no other text.
        """

        let response = try await session.respond(to: jsonPrompt)
        let content = response.content

        // Parse JSON response
        guard let data = content.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LLMError.invalidResponse
        }
    }
}
#endif
