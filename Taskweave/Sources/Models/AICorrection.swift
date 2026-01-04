import Foundation

/// Represents a user correction to an AI suggestion for active learning
struct AICorrection: Codable, Identifiable {
    let id: UUID
    let field: CorrectionField
    let originalSuggestion: String
    let userChoice: String
    let taskKeywords: [String]
    let timestamp: Date

    /// The field that was corrected
    enum CorrectionField: String, Codable, CaseIterable {
        case category
        case priority
        case duration
        case title
    }

    init(
        id: UUID = UUID(),
        field: CorrectionField,
        originalSuggestion: String,
        userChoice: String,
        taskKeywords: [String],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.field = field
        self.originalSuggestion = originalSuggestion
        self.userChoice = userChoice
        self.taskKeywords = taskKeywords
        self.timestamp = timestamp
    }
}

// MARK: - Keyword Extraction

extension AICorrection {
    /// Extract keywords from a task title for learning patterns
    static func extractKeywords(from text: String) -> [String] {
        // Common stop words to filter out
        let stopWords: Set<String> = [
            "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
            "be", "have", "has", "had", "do", "does", "did", "will", "would",
            "could", "should", "may", "might", "must", "shall", "can", "need",
            "i", "you", "he", "she", "it", "we", "they", "my", "your", "his",
            "her", "its", "our", "their", "this", "that", "these", "those"
        ]

        // Tokenize and filter
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }

        // Return unique keywords (up to 5)
        return Array(Set(words).prefix(5))
    }
}
