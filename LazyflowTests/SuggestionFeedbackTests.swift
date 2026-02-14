import XCTest
@testable import Lazyflow

final class SuggestionFeedbackTests: XCTestCase {

    // MARK: - FeedbackAction Tests

    func testFeedbackAction_AdjustmentDeltas() {
        XCTAssertEqual(FeedbackAction.startedImmediately.adjustmentDelta, 5)
        XCTAssertEqual(FeedbackAction.viewedDetails.adjustmentDelta, 1)
        XCTAssertEqual(FeedbackAction.snoozed1Hour.adjustmentDelta, -2)
        XCTAssertEqual(FeedbackAction.snoozedEvening.adjustmentDelta, -3)
        XCTAssertEqual(FeedbackAction.snoozedTomorrow.adjustmentDelta, -3)
        XCTAssertEqual(FeedbackAction.skippedNotRelevant.adjustmentDelta, -5)
        XCTAssertEqual(FeedbackAction.skippedWrongTime.adjustmentDelta, -5)
        XCTAssertEqual(FeedbackAction.skippedNeedsFocus.adjustmentDelta, -5)
    }

    func testFeedbackAction_IsSnooze() {
        XCTAssertTrue(FeedbackAction.snoozed1Hour.isSnooze)
        XCTAssertTrue(FeedbackAction.snoozedEvening.isSnooze)
        XCTAssertTrue(FeedbackAction.snoozedTomorrow.isSnooze)
        XCTAssertFalse(FeedbackAction.startedImmediately.isSnooze)
        XCTAssertFalse(FeedbackAction.viewedDetails.isSnooze)
        XCTAssertFalse(FeedbackAction.skippedNotRelevant.isSnooze)
    }

    func testFeedbackAction_SnoozeUntilDate_1Hour() {
        let before = Date()
        let date = FeedbackAction.snoozed1Hour.snoozeUntilDate()
        XCTAssertNotNil(date)
        // Should be ~1 hour from now
        let interval = date!.timeIntervalSince(before)
        XCTAssertGreaterThan(interval, 3500)
        XCTAssertLessThan(interval, 3700)
    }

    func testFeedbackAction_SnoozeUntilDate_Tomorrow() {
        let date = FeedbackAction.snoozedTomorrow.snoozeUntilDate()
        XCTAssertNotNil(date)
        // Should be tomorrow at 9 AM
        let components = Calendar.current.dateComponents([.hour], from: date!)
        XCTAssertEqual(components.hour, 9)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(date!))
    }

    func testFeedbackAction_NonSnoozeReturnsNil() {
        XCTAssertNil(FeedbackAction.startedImmediately.snoozeUntilDate())
        XCTAssertNil(FeedbackAction.skippedNotRelevant.snoozeUntilDate())
    }

    // MARK: - SuggestionFeedback Tests

    func testSuggestionFeedback_InitialState() {
        let feedback = SuggestionFeedback()
        XCTAssertTrue(feedback.events.isEmpty)
        XCTAssertTrue(feedback.adjustments.isEmpty)
        XCTAssertTrue(feedback.snoozedUntil.isEmpty)
    }

    func testSuggestionFeedback_RecordFeedback_AddsEvent() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()
        feedback.recordFeedback(taskID: taskID, action: .startedImmediately, originalScore: 50, taskCategory: .work)

        XCTAssertEqual(feedback.events.count, 1)
        XCTAssertEqual(feedback.events.first?.taskID, taskID)
        XCTAssertEqual(feedback.events.first?.action, .startedImmediately)
    }

    func testSuggestionFeedback_RecordFeedback_UpdatesAdjustment() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()

        feedback.recordFeedback(taskID: taskID, action: .startedImmediately, originalScore: 50, taskCategory: .work)
        XCTAssertEqual(feedback.getAdjustment(for: taskID), 5)

        feedback.recordFeedback(taskID: taskID, action: .skippedNotRelevant, originalScore: 55, taskCategory: .work)
        XCTAssertEqual(feedback.getAdjustment(for: taskID), 0) // 5 + (-5) = 0
    }

    func testSuggestionFeedback_AdjustmentClampedAt15() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()

        // Start 4 times = +20, should clamp to +15
        for _ in 0..<4 {
            feedback.recordFeedback(taskID: taskID, action: .startedImmediately, originalScore: 50, taskCategory: .work)
        }
        XCTAssertEqual(feedback.getAdjustment(for: taskID), 15)
    }

    func testSuggestionFeedback_AdjustmentClampedAtNegative15() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()

        // Skip 4 times = -20, should clamp to -15
        for _ in 0..<4 {
            feedback.recordFeedback(taskID: taskID, action: .skippedNotRelevant, originalScore: 50, taskCategory: .work)
        }
        XCTAssertEqual(feedback.getAdjustment(for: taskID), -15)
    }

    func testSuggestionFeedback_EventsCappedAt200() {
        var feedback = SuggestionFeedback()
        for i in 0..<250 {
            let taskID = UUID()
            feedback.recordFeedback(taskID: taskID, action: .viewedDetails, originalScore: Double(i), taskCategory: .work)
        }
        XCTAssertEqual(feedback.events.count, 200)
    }

    func testSuggestionFeedback_SnoozeSetOnSnoozeAction() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()

        feedback.recordFeedback(taskID: taskID, action: .snoozed1Hour, originalScore: 50, taskCategory: .work)
        XCTAssertTrue(feedback.isSnoozed(taskID))
    }

    func testSuggestionFeedback_SnoozeNotSetOnNonSnoozeAction() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()

        feedback.recordFeedback(taskID: taskID, action: .skippedNotRelevant, originalScore: 50, taskCategory: .work)
        XCTAssertFalse(feedback.isSnoozed(taskID))
    }

    func testSuggestionFeedback_CleanExpiredSnoozes() {
        var feedback = SuggestionFeedback()
        let expiredID = UUID()
        let activeID = UUID()

        // Set one expired snooze and one active
        feedback.snoozedUntil[expiredID] = Date().addingTimeInterval(-60) // Expired
        feedback.snoozedUntil[activeID] = Date().addingTimeInterval(3600) // Active

        feedback.cleanExpiredSnoozes()

        XCTAssertNil(feedback.snoozedUntil[expiredID])
        XCTAssertNotNil(feedback.snoozedUntil[activeID])
    }

    func testSuggestionFeedback_DecayNotAppliedBefore7Days() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()
        feedback.adjustments[taskID] = 10
        feedback.lastDecayDate = Date().addingTimeInterval(-6 * 86400) // 6 days ago

        feedback.applyDecayIfNeeded()
        XCTAssertEqual(feedback.adjustments[taskID], 10) // No decay
    }

    func testSuggestionFeedback_DecayAppliedAfter7Days() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()
        feedback.adjustments[taskID] = 10
        feedback.lastDecayDate = Date().addingTimeInterval(-8 * 86400) // 8 days ago

        feedback.applyDecayIfNeeded()
        // After 1 week of decay: 10 * 0.95 = 9.5
        XCTAssertEqual(feedback.adjustments[taskID]!, 9.5, accuracy: 0.01)
    }

    func testSuggestionFeedback_DecayPrunesSmallAdjustments() {
        var feedback = SuggestionFeedback()
        let taskID = UUID()
        feedback.adjustments[taskID] = 0.4
        feedback.lastDecayDate = Date().addingTimeInterval(-8 * 86400) // 8 days ago

        feedback.applyDecayIfNeeded()
        // 0.4 * 0.95 = 0.38 < 0.5, should be pruned
        XCTAssertNil(feedback.adjustments[taskID])
    }

    func testSuggestionFeedback_GetAdjustment_UnknownTaskReturnsZero() {
        let feedback = SuggestionFeedback()
        XCTAssertEqual(feedback.getAdjustment(for: UUID()), 0)
    }

    // MARK: - ConfidenceLevel Tests

    func testConfidenceLevel_RawValues() {
        XCTAssertEqual(ConfidenceLevel.recommended.rawValue, "Top Pick")
        XCTAssertEqual(ConfidenceLevel.goodFit.rawValue, "Strong")
        XCTAssertEqual(ConfidenceLevel.consider.rawValue, "Good Fit")
    }

    // MARK: - Codable Tests

    func testSuggestionFeedback_Codable() throws {
        var feedback = SuggestionFeedback()
        let taskID = UUID()
        feedback.recordFeedback(taskID: taskID, action: .startedImmediately, originalScore: 75, taskCategory: .personal)
        feedback.snoozedUntil[UUID()] = Date().addingTimeInterval(3600)

        let encoded = try JSONEncoder().encode(feedback)
        let decoded = try JSONDecoder().decode(SuggestionFeedback.self, from: encoded)

        XCTAssertEqual(decoded.events.count, 1)
        XCTAssertEqual(decoded.adjustments[taskID], 5)
        XCTAssertEqual(decoded.snoozedUntil.count, 1)
    }

    func testFeedbackAction_Codable() throws {
        let action = FeedbackAction.snoozedEvening
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(FeedbackAction.self, from: encoded)
        XCTAssertEqual(decoded, action)
    }
}
