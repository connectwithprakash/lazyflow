import Foundation
import SwiftUI

/// Represents a duration accuracy record for learning estimation patterns
struct DurationAccuracy: Codable, Identifiable {
    let id: UUID
    let taskCategory: String
    let estimatedMinutes: Int
    let actualMinutes: Int
    let ratio: Double  // actual / estimated
    let timestamp: Date

    init(
        id: UUID = UUID(),
        taskCategory: String,
        estimatedMinutes: Int,
        actualMinutes: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.taskCategory = taskCategory
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.ratio = Double(actualMinutes) / Double(estimatedMinutes)
        self.timestamp = timestamp
    }
}

/// Service for tracking AI corrections and providing learning context
final class AILearningService: ObservableObject {
    static let shared = AILearningService()

    private let correctionsKey = "aiCorrections"
    private let durationAccuracyKey = "durationAccuracyData"
    private let impressionsKey = "aiImpressions"
    private let maxCorrections = 100
    private let maxAccuracyRecords = 100
    private let maxImpressions = 200
    private let correctionExpiryDays = 90

    @Published private(set) var corrections: [AICorrection] = []
    @Published private(set) var durationAccuracyRecords: [DurationAccuracy] = []
    @Published private(set) var impressions: [Date] = []

    private init() {
        loadCorrections()
        loadDurationAccuracy()
        loadImpressions()
        cleanupOldCorrections()
        cleanupOldAccuracyRecords()
        cleanupOldImpressions()
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
            return ""
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

    // MARK: - Duration Accuracy Tracking

    /// Record duration accuracy when a task is completed with timer data
    func recordDurationAccuracy(
        category: String,
        estimatedMinutes: Int,
        actualMinutes: Int
    ) {
        // Skip if either value is zero or negative
        guard estimatedMinutes > 0, actualMinutes > 0 else { return }

        let accuracy = DurationAccuracy(
            taskCategory: category.lowercased(),
            estimatedMinutes: estimatedMinutes,
            actualMinutes: actualMinutes
        )

        durationAccuracyRecords.append(accuracy)

        // Trim to max records
        if durationAccuracyRecords.count > maxAccuracyRecords {
            durationAccuracyRecords = Array(durationAccuracyRecords.suffix(maxAccuracyRecords))
        }

        saveDurationAccuracy()
    }

    /// Generate context string for duration accuracy patterns
    func getDurationAccuracyContext() -> String {
        guard !durationAccuracyRecords.isEmpty else {
            return ""
        }

        // Group by category and calculate average ratio
        let grouped = Dictionary(grouping: durationAccuracyRecords) { $0.taskCategory }

        var patterns: [String] = []

        for (category, records) in grouped {
            // Require at least 2 records to report a pattern
            guard records.count >= 2 else { continue }

            let averageRatio = records.map { $0.ratio }.reduce(0, +) / Double(records.count)
            let formattedRatio = String(format: "%.1f", averageRatio)

            if averageRatio > 1.1 {
                patterns.append("\(category.capitalized) tasks: user takes \(formattedRatio)x longer than estimated")
            } else if averageRatio < 0.9 {
                patterns.append("\(category.capitalized) tasks: user takes \(formattedRatio)x of estimated time")
            } else {
                patterns.append("\(category.capitalized) tasks: estimates are accurate")
            }
        }

        guard !patterns.isEmpty else { return "" }

        var context = "\nDuration accuracy patterns:\n"
        for pattern in patterns.prefix(5) {
            context += "  - \(pattern)\n"
        }

        return context
    }

    // MARK: - Impression Tracking

    /// Record when AI suggestions are shown to the user
    func recordImpression() {
        impressions.append(Date())

        // Trim to max impressions
        if impressions.count > maxImpressions {
            impressions = Array(impressions.suffix(maxImpressions))
        }

        saveImpressions()
    }

    /// Get count of impressions within the specified time window
    func getImpressionCount(lastDays: Int = 7) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date()) ?? Date()
        return impressions.filter { $0 > cutoff }.count
    }

    /// Get count of corrections within the specified time window
    func getCorrectionCount(lastDays: Int = 7) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date()) ?? Date()
        return corrections.filter { $0.timestamp > cutoff }.count
    }

    /// Calculate correction rate (corrections / impressions) for the specified time window
    /// Returns 0 if no impressions to avoid division by zero
    /// Capped at 1.0 since one impression can yield multiple corrections (category, priority, duration)
    func getCorrectionRate(lastDays: Int = 7) -> Double {
        let impressionCount = getImpressionCount(lastDays: lastDays)
        guard impressionCount > 0 else { return 0 }

        let correctionCount = getCorrectionCount(lastDays: lastDays)
        return min(1.0, Double(correctionCount) / Double(impressionCount))
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

    private func loadDurationAccuracy() {
        guard let data = UserDefaults.standard.data(forKey: durationAccuracyKey),
              let decoded = try? JSONDecoder().decode([DurationAccuracy].self, from: data) else {
            durationAccuracyRecords = []
            return
        }
        durationAccuracyRecords = decoded
    }

    private func saveDurationAccuracy() {
        guard let data = try? JSONEncoder().encode(durationAccuracyRecords) else { return }
        UserDefaults.standard.set(data, forKey: durationAccuracyKey)
    }

    private func loadImpressions() {
        guard let data = UserDefaults.standard.data(forKey: impressionsKey),
              let decoded = try? JSONDecoder().decode([Date].self, from: data) else {
            impressions = []
            return
        }
        impressions = decoded
    }

    private func saveImpressions() {
        guard let data = try? JSONEncoder().encode(impressions) else { return }
        UserDefaults.standard.set(data, forKey: impressionsKey)
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

    /// Remove accuracy records older than the expiry period
    func cleanupOldAccuracyRecords() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -correctionExpiryDays,
            to: Date()
        ) ?? Date()

        let countBefore = durationAccuracyRecords.count
        durationAccuracyRecords = durationAccuracyRecords.filter { $0.timestamp > cutoffDate }

        if durationAccuracyRecords.count != countBefore {
            saveDurationAccuracy()
        }
    }

    /// Remove impressions older than the expiry period
    func cleanupOldImpressions() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -correctionExpiryDays,
            to: Date()
        ) ?? Date()

        let countBefore = impressions.count
        impressions = impressions.filter { $0 > cutoffDate }

        if impressions.count != countBefore {
            saveImpressions()
        }
    }

    /// Clear all corrections, accuracy data, and impressions (for testing or user request)
    func clearAllCorrections() {
        corrections = []
        durationAccuracyRecords = []
        impressions = []
        saveCorrections()
        UserDefaults.standard.removeObject(forKey: durationAccuracyKey)
        UserDefaults.standard.removeObject(forKey: impressionsKey)
    }
}
