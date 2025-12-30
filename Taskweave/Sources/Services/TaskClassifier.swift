import Foundation
import NaturalLanguage
import CoreML

/// Service for ML-based task category classification
/// Uses a Create ML trained text classifier model for on-device inference
final class TaskClassifier {
    static let shared = TaskClassifier()

    private var nlModel: NLModel?
    private var isModelLoaded = false

    private init() {
        loadModel()
    }

    // MARK: - Model Loading

    /// Load the Core ML model for text classification
    private func loadModel() {
        // Try to load the compiled model
        guard let modelURL = Bundle.main.url(forResource: "TaskCategoryClassifier", withExtension: "mlmodelc") else {
            // Try uncompiled version (Xcode will compile it)
            guard let unCompiledURL = Bundle.main.url(forResource: "TaskCategoryClassifier", withExtension: "mlmodel") else {
                print("[TaskClassifier] Model file not found in bundle")
                return
            }

            do {
                // Compile the model at runtime (fallback)
                let compiledURL = try MLModel.compileModel(at: unCompiledURL)
                let mlModel = try MLModel(contentsOf: compiledURL)
                nlModel = try NLModel(mlModel: mlModel)
                isModelLoaded = true
                print("[TaskClassifier] Model loaded successfully (runtime compiled)")
            } catch {
                print("[TaskClassifier] Failed to compile/load model: \(error.localizedDescription)")
            }
            return
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            nlModel = try NLModel(mlModel: mlModel)
            isModelLoaded = true
            print("[TaskClassifier] Model loaded successfully")
        } catch {
            print("[TaskClassifier] Failed to load model: \(error.localizedDescription)")
        }
    }

    // MARK: - Classification

    /// Classify a task's text into a category
    /// - Parameters:
    ///   - title: The task title
    ///   - notes: Optional task notes/description
    /// - Returns: The predicted category, or nil if classification fails
    func classify(title: String, notes: String? = nil) -> TaskCategory? {
        guard isModelLoaded, let model = nlModel else {
            return nil
        }

        // Combine title and notes for better context
        let text = notes.map { "\(title) \($0)" } ?? title

        // Get prediction
        guard let prediction = model.predictedLabel(for: text) else {
            return nil
        }

        // Map string prediction to TaskCategory
        return mapPredictionToCategory(prediction)
    }

    /// Get prediction with confidence score
    /// - Parameters:
    ///   - title: The task title
    ///   - notes: Optional task notes/description
    /// - Returns: Tuple of (category, confidence) or nil if classification fails
    func classifyWithConfidence(title: String, notes: String? = nil) -> (category: TaskCategory, confidence: Double)? {
        guard isModelLoaded, let model = nlModel else {
            return nil
        }

        let text = notes.map { "\(title) \($0)" } ?? title

        // Get prediction with hypothesis
        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: 1)

        guard let (prediction, confidence) = hypotheses.first else {
            return nil
        }

        guard let category = mapPredictionToCategory(prediction) else {
            return nil
        }

        return (category, confidence)
    }

    /// Get top predictions with confidence scores
    /// - Parameters:
    ///   - title: The task title
    ///   - notes: Optional task notes/description
    ///   - count: Maximum number of predictions to return
    /// - Returns: Array of (category, confidence) tuples sorted by confidence
    func topPredictions(title: String, notes: String? = nil, count: Int = 3) -> [(category: TaskCategory, confidence: Double)] {
        guard isModelLoaded, let model = nlModel else {
            return []
        }

        let text = notes.map { "\(title) \($0)" } ?? title

        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: count)

        return hypotheses.compactMap { (prediction, confidence) -> (TaskCategory, Double)? in
            guard let category = mapPredictionToCategory(prediction) else {
                return nil
            }
            return (category, confidence)
        }.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Helper Methods

    private func mapPredictionToCategory(_ prediction: String) -> TaskCategory? {
        switch prediction.lowercased() {
        case "work": return .work
        case "personal": return .personal
        case "health": return .health
        case "finance": return .finance
        case "shopping": return .shopping
        case "errands": return .errands
        case "learning": return .learning
        case "home": return .home
        default: return nil
        }
    }

    /// Check if the ML model is available
    var isAvailable: Bool {
        isModelLoaded
    }
}
