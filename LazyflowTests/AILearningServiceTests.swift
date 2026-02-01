import XCTest
@testable import Lazyflow

final class AILearningServiceTests: XCTestCase {

    var sut: AILearningService!

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        sut = AILearningService.shared
        sut.clearAllCorrections()
    }

    override func tearDown() {
        sut.clearAllCorrections()
        super.tearDown()
    }

    // MARK: - recordCorrection Tests

    func testRecordCorrection_StoresCorrection_WhenValuesDiffer() {
        // Given
        let originalSuggestion = "Work"
        let userChoice = "Personal"

        // When
        sut.recordCorrection(
            field: .category,
            originalSuggestion: originalSuggestion,
            userChoice: userChoice,
            taskTitle: "Team meeting prep"
        )

        // Then
        XCTAssertEqual(sut.corrections.count, 1)
        XCTAssertEqual(sut.corrections.first?.field, .category)
        XCTAssertEqual(sut.corrections.first?.originalSuggestion, originalSuggestion)
        XCTAssertEqual(sut.corrections.first?.userChoice, userChoice)
    }

    func testRecordCorrection_SkipsCorrection_WhenValuesMatch() {
        // Given
        let sameValue = "Work"

        // When
        sut.recordCorrection(
            field: .category,
            originalSuggestion: sameValue,
            userChoice: sameValue,
            taskTitle: "Team meeting"
        )

        // Then
        XCTAssertEqual(sut.corrections.count, 0)
    }

    func testRecordCorrection_StoresDurationCorrection() {
        // Given
        let originalDuration = "30 min"
        let userDuration = "60 min"

        // When
        sut.recordCorrection(
            field: .duration,
            originalSuggestion: originalDuration,
            userChoice: userDuration,
            taskTitle: "Write report"
        )

        // Then
        XCTAssertEqual(sut.corrections.count, 1)
        XCTAssertEqual(sut.corrections.first?.field, .duration)
    }

    func testRecordCorrection_StoresPriorityCorrection() {
        // Given
        let originalPriority = "Medium"
        let userPriority = "High"

        // When
        sut.recordCorrection(
            field: .priority,
            originalSuggestion: originalPriority,
            userChoice: userPriority,
            taskTitle: "Urgent deadline"
        )

        // Then
        XCTAssertEqual(sut.corrections.count, 1)
        XCTAssertEqual(sut.corrections.first?.field, .priority)
    }

    func testRecordCorrection_ExtractsKeywords() {
        // Given/When
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Quarterly budget review meeting"
        )

        // Then
        let keywords = sut.corrections.first?.taskKeywords ?? []
        XCTAssertTrue(keywords.contains("quarterly") || keywords.contains("budget") || keywords.contains("review") || keywords.contains("meeting"))
    }

    func testRecordCorrection_EnforcesMaxLimit() {
        // Given - record more than max (100)
        for i in 0..<110 {
            sut.recordCorrection(
                field: .category,
                originalSuggestion: "Original",
                userChoice: "Choice\(i)",
                taskTitle: "Task \(i)"
            )
        }

        // Then - should be trimmed to 100
        XCTAssertEqual(sut.corrections.count, 100)
    }

    // MARK: - getCorrectionsContext Tests

    func testGetCorrectionsContext_ReturnsEmpty_WhenNoCorrections() {
        // Given - no corrections

        // When
        let context = sut.getCorrectionsContext()

        // Then - returns empty string, AIContextService handles the "no preferences" message
        XCTAssertTrue(context.isEmpty)
    }

    func testGetCorrectionsContext_ReturnsPatterns_AfterMultipleCorrections() {
        // Given - record same correction multiple times (threshold is 2+)
        for _ in 0..<3 {
            sut.recordCorrection(
                field: .category,
                originalSuggestion: "Personal",
                userChoice: "Work",
                taskTitle: "Meeting prep"
            )
        }

        // When
        let context = sut.getCorrectionsContext()

        // Then
        XCTAssertTrue(context.contains("Personal -> Work") || context.contains("User often changes"))
    }

    func testGetCorrectionsContext_DetectsKeywordAssociations() {
        // Given - record corrections with same keyword
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Meeting with team"
        )
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Meeting notes review"
        )

        // When
        let context = sut.getCorrectionsContext()

        // Then - should detect "meeting" keyword association
        XCTAssertTrue(context.contains("meeting") || context.contains("Work"))
    }

    // MARK: - getAcceptanceRate Tests

    func testGetAcceptanceRate_Returns1_WhenNoCorrections() {
        // Given - no corrections

        // When
        let rate = sut.getAcceptanceRate(for: .category)

        // Then - 1.0 means 100% acceptance (no rejections)
        XCTAssertEqual(rate, 1.0)
    }

    func testGetAcceptanceRate_DecreasesWithCorrections() {
        // Given - record some corrections
        for _ in 0..<10 {
            sut.recordCorrection(
                field: .category,
                originalSuggestion: "Personal",
                userChoice: "Work",
                taskTitle: "Test task"
            )
        }

        // When
        let rate = sut.getAcceptanceRate(for: .category)

        // Then - rate should be lower than 1.0
        XCTAssertLessThan(rate, 1.0)
    }

    // MARK: - getSuggestedOverride Tests

    func testGetSuggestedOverride_ReturnsNil_WithNoMatchingCorrections() {
        // Given - no corrections

        // When
        let override = sut.getSuggestedOverride(
            for: .category,
            taskTitle: "New task",
            aiSuggestion: "Personal"
        )

        // Then
        XCTAssertNil(override)
    }

    func testGetSuggestedOverride_ReturnsPreference_AfterMultipleSimilarCorrections() {
        // Given - record same correction for similar tasks
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Meeting with client"
        )
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Client meeting prep"
        )

        // When
        let override = sut.getSuggestedOverride(
            for: .category,
            taskTitle: "Meeting agenda",
            aiSuggestion: "Personal"
        )

        // Then - should suggest "Work" based on "meeting" keyword
        XCTAssertEqual(override, "Work")
    }

    // MARK: - Cleanup Tests

    func testCleanupOldCorrections_KeepsRecentCorrections() {
        // Given - add a recent correction
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Recent task"
        )

        let countBefore = sut.corrections.count
        XCTAssertGreaterThan(countBefore, 0)

        // When - cleanup is called
        sut.cleanupOldCorrections()

        // Then - recent correction should remain (not expired)
        XCTAssertEqual(sut.corrections.count, countBefore)
    }

    func testCleanupOldCorrections_ExpiryLogicExists() {
        // This test verifies the cleanup method uses the correct expiry period (90 days)
        // Note: Full expiration testing would require injecting old corrections
        // which the singleton doesn't support. This verifies the method runs without error.
        sut.cleanupOldCorrections()
        // No assertion needed - just verify no crash
    }

    func testClearAllCorrections_RemovesAllData() {
        // Given
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Test task"
        )
        XCTAssertGreaterThan(sut.corrections.count, 0)

        // When
        sut.clearAllCorrections()

        // Then
        XCTAssertEqual(sut.corrections.count, 0)
    }

    // MARK: - analyzePatterns Tests

    func testAnalyzePatterns_ReturnsPatterns_WhenThresholdMet() {
        // Given - record 2+ corrections with same pattern
        for _ in 0..<3 {
            sut.recordCorrection(
                field: .priority,
                originalSuggestion: "Low",
                userChoice: "High",
                taskTitle: "Urgent task"
            )
        }

        // When
        let corrections = sut.getCorrections(for: .priority)

        // Then
        XCTAssertGreaterThanOrEqual(corrections.count, 2)
    }

    // MARK: - Duration Accuracy Tests

    func testRecordDurationAccuracy_StoresAccuracy_WhenBothDurationsExist() {
        // Given
        let estimatedMinutes = 30
        let actualMinutes = 45
        let category = "Work"

        // When
        sut.recordDurationAccuracy(
            category: category,
            estimatedMinutes: estimatedMinutes,
            actualMinutes: actualMinutes
        )

        // Then
        XCTAssertEqual(sut.durationAccuracyRecords.count, 1)
        XCTAssertEqual(sut.durationAccuracyRecords.first?.taskCategory, category.lowercased())
        XCTAssertEqual(sut.durationAccuracyRecords.first?.estimatedMinutes, estimatedMinutes)
        XCTAssertEqual(sut.durationAccuracyRecords.first?.actualMinutes, actualMinutes)
    }

    func testRecordDurationAccuracy_CalculatesRatio() {
        // Given
        let estimatedMinutes = 30
        let actualMinutes = 60  // Took 2x longer

        // When
        sut.recordDurationAccuracy(
            category: "Work",
            estimatedMinutes: estimatedMinutes,
            actualMinutes: actualMinutes
        )

        // Then
        let ratio = sut.durationAccuracyRecords.first?.ratio ?? 0
        XCTAssertEqual(ratio, 2.0, accuracy: 0.01)
    }

    func testRecordDurationAccuracy_SkipsZeroEstimate() {
        // Given/When
        sut.recordDurationAccuracy(
            category: "Work",
            estimatedMinutes: 0,
            actualMinutes: 30
        )

        // Then - should not record
        XCTAssertEqual(sut.durationAccuracyRecords.count, 0)
    }

    func testRecordDurationAccuracy_SkipsZeroActual() {
        // Given/When
        sut.recordDurationAccuracy(
            category: "Work",
            estimatedMinutes: 30,
            actualMinutes: 0
        )

        // Then - should not record
        XCTAssertEqual(sut.durationAccuracyRecords.count, 0)
    }

    func testRecordDurationAccuracy_EnforcesMaxLimit() {
        // Given - record more than max (100)
        for i in 0..<110 {
            sut.recordDurationAccuracy(
                category: "Work",
                estimatedMinutes: 30,
                actualMinutes: 30 + i
            )
        }

        // Then - should be trimmed to 100
        XCTAssertEqual(sut.durationAccuracyRecords.count, 100)
    }

    func testGetDurationAccuracyContext_ReturnsEmpty_WhenNoData() {
        // Given - no accuracy data

        // When
        let context = sut.getDurationAccuracyContext()

        // Then
        XCTAssertTrue(context.isEmpty || context.contains("No duration"))
    }

    func testGetDurationAccuracyContext_ReturnsPattern_WithSufficientData() {
        // Given - record 2+ accuracy entries for same category
        sut.recordDurationAccuracy(category: "Work", estimatedMinutes: 30, actualMinutes: 45)
        sut.recordDurationAccuracy(category: "Work", estimatedMinutes: 60, actualMinutes: 90)

        // When
        let context = sut.getDurationAccuracyContext()

        // Then - should include Work category pattern
        XCTAssertTrue(context.contains("Work") || context.contains("1.5"))
    }

    func testClearAllCorrections_AlsoClearsDurationAccuracy() {
        // Given
        sut.recordDurationAccuracy(category: "Work", estimatedMinutes: 30, actualMinutes: 45)
        XCTAssertGreaterThan(sut.durationAccuracyRecords.count, 0)

        // When
        sut.clearAllCorrections()

        // Then - both corrections and accuracy records should be cleared
        XCTAssertEqual(sut.corrections.count, 0)
        XCTAssertEqual(sut.durationAccuracyRecords.count, 0)
    }

    // MARK: - Impression Tracking Tests

    func testRecordImpression_StoresImpression() {
        // Given - no impressions

        // When
        sut.recordImpression()

        // Then
        XCTAssertEqual(sut.impressions.count, 1)
    }

    func testRecordImpression_StoresMultipleImpressions() {
        // Given/When
        sut.recordImpression()
        sut.recordImpression()
        sut.recordImpression()

        // Then
        XCTAssertEqual(sut.impressions.count, 3)
    }

    func testRecordImpression_EnforcesMaxLimit() {
        // Given - record more than max (200)
        for _ in 0..<210 {
            sut.recordImpression()
        }

        // Then - should be trimmed to 200
        XCTAssertEqual(sut.impressions.count, 200)
    }

    func testGetImpressionCount_ReturnsZero_WhenNoImpressions() {
        // Given - no impressions

        // When
        let count = sut.getImpressionCount(lastDays: 7)

        // Then
        XCTAssertEqual(count, 0)
    }

    func testGetImpressionCount_ReturnsAllRecent_WithinTimeWindow() {
        // Given
        sut.recordImpression()
        sut.recordImpression()
        sut.recordImpression()

        // When
        let count = sut.getImpressionCount(lastDays: 7)

        // Then
        XCTAssertEqual(count, 3)
    }

    func testGetCorrectionRate_ReturnsZero_WhenNoImpressions() {
        // Given - no impressions, but some corrections
        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Test task"
        )

        // When
        let rate = sut.getCorrectionRate(lastDays: 7)

        // Then - avoid division by zero
        XCTAssertEqual(rate, 0)
    }

    func testGetCorrectionRate_ReturnsZero_WhenNoCorrections() {
        // Given - impressions but no corrections
        sut.recordImpression()
        sut.recordImpression()

        // When
        let rate = sut.getCorrectionRate(lastDays: 7)

        // Then
        XCTAssertEqual(rate, 0)
    }

    func testGetCorrectionRate_CalculatesCorrectly() {
        // Given - 4 impressions, 2 corrections = 50% correction rate
        sut.recordImpression()
        sut.recordImpression()
        sut.recordImpression()
        sut.recordImpression()

        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Task 1"
        )
        sut.recordCorrection(
            field: .priority,
            originalSuggestion: "Low",
            userChoice: "High",
            taskTitle: "Task 2"
        )

        // When
        let rate = sut.getCorrectionRate(lastDays: 7)

        // Then - 2/4 = 0.5
        XCTAssertEqual(rate, 0.5, accuracy: 0.01)
    }

    func testGetCorrectionRate_CapsAtOne_WhenCorrectionsExceedImpressions() {
        // Given - 1 impression, 3 corrections (one per field)
        sut.recordImpression()

        sut.recordCorrection(
            field: .category,
            originalSuggestion: "Personal",
            userChoice: "Work",
            taskTitle: "Task 1"
        )
        sut.recordCorrection(
            field: .priority,
            originalSuggestion: "Low",
            userChoice: "High",
            taskTitle: "Task 1"
        )
        sut.recordCorrection(
            field: .duration,
            originalSuggestion: "30 min",
            userChoice: "60 min",
            taskTitle: "Task 1"
        )

        // When
        let rate = sut.getCorrectionRate(lastDays: 7)

        // Then - capped at 1.0 even though 3/1 = 3.0
        XCTAssertEqual(rate, 1.0, accuracy: 0.01)
    }

    func testClearAllCorrections_AlsoClearsImpressions() {
        // Given
        sut.recordImpression()
        sut.recordImpression()
        XCTAssertGreaterThan(sut.impressions.count, 0)

        // When
        sut.clearAllCorrections()

        // Then
        XCTAssertEqual(sut.impressions.count, 0)
    }

    // MARK: - Refinement Request Tracking Tests

    func testRecordRefinementRequest_StoresRefinement() {
        // Given - no refinements

        // When
        sut.recordRefinementRequest()

        // Then
        XCTAssertEqual(sut.refinementRequests.count, 1)
    }

    func testRecordRefinementRequest_StoresMultipleRefinements() {
        // Given/When
        sut.recordRefinementRequest()
        sut.recordRefinementRequest()
        sut.recordRefinementRequest()

        // Then
        XCTAssertEqual(sut.refinementRequests.count, 3)
    }

    func testRecordRefinementRequest_EnforcesMaxLimit() {
        // Given - record more than max (100)
        for _ in 0..<110 {
            sut.recordRefinementRequest()
        }

        // Then - should be trimmed to 100
        XCTAssertEqual(sut.refinementRequests.count, 100)
    }

    func testGetRefinementCount_ReturnsZero_WhenNoRefinements() {
        // Given - no refinements

        // When
        let count = sut.getRefinementCount(lastDays: 7)

        // Then
        XCTAssertEqual(count, 0)
    }

    func testGetRefinementCount_ReturnsAllRecent_WithinTimeWindow() {
        // Given
        sut.recordRefinementRequest()
        sut.recordRefinementRequest()
        sut.recordRefinementRequest()

        // When
        let count = sut.getRefinementCount(lastDays: 7)

        // Then
        XCTAssertEqual(count, 3)
    }

    func testGetRefinementRate_ReturnsZero_WhenNoImpressions() {
        // Given - no impressions, but some refinements
        sut.recordRefinementRequest()

        // When
        let rate = sut.getRefinementRate(lastDays: 7)

        // Then - avoid division by zero
        XCTAssertEqual(rate, 0)
    }

    func testGetRefinementRate_CalculatesCorrectly() {
        // Given - 4 impressions, 1 refinement = 25% refinement rate
        sut.recordImpression()
        sut.recordImpression()
        sut.recordImpression()
        sut.recordImpression()

        sut.recordRefinementRequest()

        // When
        let rate = sut.getRefinementRate(lastDays: 7)

        // Then - 1/4 = 0.25
        XCTAssertEqual(rate, 0.25, accuracy: 0.01)
    }

    func testClearAllCorrections_AlsoClearsRefinements() {
        // Given
        sut.recordRefinementRequest()
        sut.recordRefinementRequest()
        XCTAssertGreaterThan(sut.refinementRequests.count, 0)

        // When
        sut.clearAllCorrections()

        // Then
        XCTAssertEqual(sut.refinementRequests.count, 0)
    }
}
