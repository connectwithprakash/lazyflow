import Foundation
import SwiftUI

/// Service for tracking AI corrections and providing learning context
final class AILearningService: ObservableObject {
    static let shared = AILearningService()

    private let correctionsKey = "aiCorrections"
    private let maxCorrections = 100
    private let correctionExpiryDays = 90

    @Published private(set) var corrections: [AICorrection] = []

    private init() {
        loadCorrections()
        cleanupOldCorrections()
    }

    // MARK: - Recording Corrections

    /// Record a user correction when they change an AI suggestion
    func recordCorrection(
        field: AICorrection.CorrectionField,
        originalSuggestion: String,
        userChoice: String,
        taskTitle: String
    ) {
        // Only record if the user actually changed the suggestion
        guard originalSuggestion != userChoice else { return }

        let correction = AICorrection(
            field: field,
            originalSuggestion: originalSuggestion,
            userChoice: userChoice,
            taskKeywords: AICorrection.extractKeywords(from: taskTitle)
        )

        corrections.append(correction)

        // Trim to max corrections
        if corrections.count > maxCorrections {
            corrections = Array(corrections.suffix(maxCorrections))
        }

        saveCorrections()
    }

    // MARK: - Learning Context

    /// Generate context string for LLM prompts based on user corrections
    func getCorrectionsContext() -> String {
        guard !corrections.isEmpty else {
            return "No user preferences learned yet."
        }

        var context = "User preferences learned from past corrections:\n"

        // Group corrections by field
        let grouped = Dictionary(grouping: corrections) { $0.field }

        for (field, fieldCorrections) in grouped {
            let patterns = analyzePatterns(for: fieldCorrections)
            if !patterns.isEmpty {
                context += "\n\(field.rawValue.capitalized):\n"
                for pattern in patterns {
                    context += "  - \(pattern)\n"
                }
            }
        }

        return context
    }

    /// Analyze patterns in corrections for a specific field
    private func analyzePatterns(for corrections: [AICorrection]) -> [String] {
        var patterns: [String] = []

        // Find common corrections (same original -> user choice)
        let correctionPairs = corrections.map { "\($0.originalSuggestion) -> \($0.userChoice)" }
        let pairCounts = Dictionary(correctionPairs.map { ($0, 1) }, uniquingKeysWith: +)

        for (pair, count) in pairCounts.sorted(by: { $0.value > $1.value }).prefix(3) {
            if count >= 2 {
                patterns.append("User often changes \(pair) (seen \(count) times)")
            }
        }

        // Find keyword associations
        var keywordChoices: [String: [String]] = [:]
        for correction in corrections {
            for keyword in correction.taskKeywords {
                keywordChoices[keyword, default: []].append(correction.userChoice)
            }
        }

        for (keyword, choices) in keywordChoices {
            let choiceCounts = Dictionary(choices.map { ($0, 1) }, uniquingKeysWith: +)
            if let (preferredChoice, count) = choiceCounts.max(by: { $0.value < $1.value }),
               count >= 2 {
                patterns.append("For tasks with '\(keyword)', user prefers \(preferredChoice)")
            }
        }

        return Array(patterns.prefix(5))
    }

    // MARK: - Analytics

    /// Get acceptance rate for a specific field
    func getAcceptanceRate(for field: AICorrection.CorrectionField) -> Double {
        let fieldCorrections = corrections.filter { $0.field == field }
        guard !fieldCorrections.isEmpty else { return 1.0 }

        // Lower number of corrections = higher acceptance (corrections = rejections)
        // This is an approximation since we only track rejections
        return max(0, 1.0 - Double(fieldCorrections.count) / 50.0)
    }

    /// Get all corrections for a specific field
    func getCorrections(for field: AICorrection.CorrectionField) -> [AICorrection] {
        return corrections.filter { $0.field == field }
    }

    /// Get suggested value based on past corrections and task keywords
    func getSuggestedOverride(
        for field: AICorrection.CorrectionField,
        taskTitle: String,
        aiSuggestion: String
    ) -> String? {
        let keywords = AICorrection.extractKeywords(from: taskTitle)
        let relevantCorrections = corrections.filter { correction in
            correction.field == field &&
            correction.originalSuggestion == aiSuggestion &&
            !Set(correction.taskKeywords).isDisjoint(with: Set(keywords))
        }

        // If we've corrected this exact suggestion for similar tasks multiple times
        let userChoices = relevantCorrections.map { $0.userChoice }
        let choiceCounts = Dictionary(userChoices.map { ($0, 1) }, uniquingKeysWith: +)

        if let (preferredChoice, count) = choiceCounts.max(by: { $0.value < $1.value }),
           count >= 2 {
            return preferredChoice
        }

        return nil
    }

    // MARK: - Persistence

    private func loadCorrections() {
        guard let data = UserDefaults.standard.data(forKey: correctionsKey),
              let decoded = try? JSONDecoder().decode([AICorrection].self, from: data) else {
            corrections = []
            return
        }
        corrections = decoded
    }

    private func saveCorrections() {
        guard let data = try? JSONEncoder().encode(corrections) else { return }
        UserDefaults.standard.set(data, forKey: correctionsKey)
    }

    // MARK: - Cleanup

    /// Remove corrections older than the expiry period
    func cleanupOldCorrections() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -correctionExpiryDays,
            to: Date()
        ) ?? Date()

        let countBefore = corrections.count
        corrections = corrections.filter { $0.timestamp > cutoffDate }

        if corrections.count != countBefore {
            saveCorrections()
        }
    }

    /// Clear all corrections (for testing or user request)
    func clearAllCorrections() {
        corrections = []
        saveCorrections()
    }
}
