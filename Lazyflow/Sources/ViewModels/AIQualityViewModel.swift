import Foundation

@MainActor
final class AIQualityViewModel: ObservableObject {
    private let learningService: AILearningService

    // MARK: - 7-day metrics

    @Published private(set) var correctionRate7d: Double = 0
    @Published private(set) var refinementRate7d: Double = 0
    @Published private(set) var acceptanceRate7d: Double = 0
    @Published private(set) var impressionCount7d: Int = 0
    @Published private(set) var correctionCount7d: Int = 0
    @Published private(set) var refinementCount7d: Int = 0

    // MARK: - 30-day metrics

    @Published private(set) var correctionRate30d: Double = 0
    @Published private(set) var refinementRate30d: Double = 0
    @Published private(set) var acceptanceRate30d: Double = 0
    @Published private(set) var impressionCount30d: Int = 0
    @Published private(set) var correctionCount30d: Int = 0
    @Published private(set) var refinementCount30d: Int = 0

    var hasData: Bool {
        impressionCount7d > 0 || impressionCount30d > 0
    }

    init(learningService: AILearningService = .shared) {
        self.learningService = learningService
        refresh()
    }

    func refresh() {
        // 7-day window
        correctionRate7d = learningService.getCorrectionRate(lastDays: 7)
        refinementRate7d = learningService.getRefinementRate(lastDays: 7)
        acceptanceRate7d = max(0, 1.0 - correctionRate7d)
        impressionCount7d = learningService.getImpressionCount(lastDays: 7)
        correctionCount7d = learningService.getCorrectionCount(lastDays: 7)
        refinementCount7d = learningService.getRefinementCount(lastDays: 7)

        // 30-day window
        correctionRate30d = learningService.getCorrectionRate(lastDays: 30)
        refinementRate30d = learningService.getRefinementRate(lastDays: 30)
        acceptanceRate30d = max(0, 1.0 - correctionRate30d)
        impressionCount30d = learningService.getImpressionCount(lastDays: 30)
        correctionCount30d = learningService.getCorrectionCount(lastDays: 30)
        refinementCount30d = learningService.getRefinementCount(lastDays: 30)
    }

    // MARK: - Formatted values

    var formattedCorrectionRate7d: String { formatRate(correctionRate7d, hasData: impressionCount7d > 0) }
    var formattedRefinementRate7d: String { formatRate(refinementRate7d, hasData: impressionCount7d > 0) }
    var formattedAcceptanceRate7d: String { formatRate(acceptanceRate7d, hasData: impressionCount7d > 0) }
    var formattedCorrectionRate30d: String { formatRate(correctionRate30d, hasData: impressionCount30d > 0) }
    var formattedRefinementRate30d: String { formatRate(refinementRate30d, hasData: impressionCount30d > 0) }
    var formattedAcceptanceRate30d: String { formatRate(acceptanceRate30d, hasData: impressionCount30d > 0) }

    private func formatRate(_ rate: Double, hasData: Bool) -> String {
        guard hasData else { return "—" }
        return "\(Int(rate * 100))%"
    }
}
