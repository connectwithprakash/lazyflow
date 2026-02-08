import XCTest
@testable import Lazyflow

@MainActor
final class AIQualityViewModelTests: XCTestCase {

    var sut: AIQualityViewModel!
    var learningService: AILearningService!

    override func setUp() {
        super.setUp()
        learningService = AILearningService.shared
        learningService.clearAllLearningData()
        sut = AIQualityViewModel(learningService: learningService)
    }

    override func tearDown() {
        learningService.clearAllLearningData()
        sut = nil
        learningService = nil
        super.tearDown()
    }

    // MARK: - Empty State

    func testEmptyState_AllRatesAreZero() {
        sut.refresh()

        XCTAssertEqual(sut.correctionRate7d, 0)
        XCTAssertEqual(sut.refinementRate7d, 0)
        XCTAssertEqual(sut.correctionRate30d, 0)
        XCTAssertEqual(sut.refinementRate30d, 0)
    }

    func testEmptyState_AllCountsAreZero() {
        sut.refresh()

        XCTAssertEqual(sut.impressionCount7d, 0)
        XCTAssertEqual(sut.impressionCount30d, 0)
        XCTAssertEqual(sut.correctionCount7d, 0)
        XCTAssertEqual(sut.refinementCount7d, 0)
    }

    func testHasData_FalseWhenNoImpressions() {
        sut.refresh()
        XCTAssertFalse(sut.hasData)
    }

    // MARK: - Correction Rate

    func testCorrectionRate_ComputedFromService() {
        // Record 10 impressions and 3 corrections
        for _ in 0..<10 {
            learningService.recordImpression()
        }
        for _ in 0..<3 {
            learningService.recordCorrection(
                field: .category,
                originalSuggestion: "Work",
                userChoice: "Personal",
                taskTitle: "Test task"
            )
        }

        sut.refresh()

        XCTAssertEqual(sut.correctionRate7d, 0.3, accuracy: 0.01)
        XCTAssertEqual(sut.correctionCount7d, 3)
        XCTAssertEqual(sut.impressionCount7d, 10)
    }

    // MARK: - Refinement Rate

    func testRefinementRate_ComputedFromService() {
        // Record 10 impressions and 2 refinements
        for _ in 0..<10 {
            learningService.recordImpression()
        }
        learningService.recordRefinementRequest()
        learningService.recordRefinementRequest()

        sut.refresh()

        XCTAssertEqual(sut.refinementRate7d, 0.2, accuracy: 0.01)
        XCTAssertEqual(sut.refinementCount7d, 2)
    }

    // MARK: - Has Data

    func testHasData_TrueWhenImpressionsExist() {
        learningService.recordImpression()

        sut.refresh()

        XCTAssertTrue(sut.hasData)
    }

    // MARK: - Formatted Rates

    func testFormattedRate_ZeroShowsDash() {
        sut.refresh()
        XCTAssertEqual(sut.formattedCorrectionRate7d, "—")
    }

    func testFormattedRate_ShowsPercentage() {
        for _ in 0..<10 {
            learningService.recordImpression()
        }
        for _ in 0..<3 {
            learningService.recordCorrection(
                field: .priority,
                originalSuggestion: "High",
                userChoice: "Low",
                taskTitle: "Test"
            )
        }

        sut.refresh()

        XCTAssertEqual(sut.formattedCorrectionRate7d, "30%")
    }

    // MARK: - Acceptance Rate

    func testAcceptanceRate_InverseOfCorrectionRate() {
        for _ in 0..<10 {
            learningService.recordImpression()
        }
        for _ in 0..<4 {
            learningService.recordCorrection(
                field: .category,
                originalSuggestion: "Work",
                userChoice: "Personal",
                taskTitle: "Test"
            )
        }

        sut.refresh()

        // Acceptance = 1 - correction rate = 1 - 0.4 = 0.6
        XCTAssertEqual(sut.acceptanceRate7d, 0.6, accuracy: 0.01)
    }

    func testAcceptanceRate_100PercentWhenNoCorrections() {
        for _ in 0..<5 {
            learningService.recordImpression()
        }

        sut.refresh()

        XCTAssertEqual(sut.acceptanceRate7d, 1.0, accuracy: 0.01)
    }
}
