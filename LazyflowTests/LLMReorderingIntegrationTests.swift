import XCTest
@testable import Lazyflow

/// Integration tests that simulate the full user journey:
/// feedback accumulation → signal extraction → prompt injection → response clamping
final class LLMReorderingIntegrationTests: XCTestCase {

    // MARK: - Cold Start Journey

    func testColdStart_NoFeedback_PromptHasNoBehaviorSection() {
        // Simulate fresh install: no feedback, no completion patterns
        let feedback = SuggestionFeedback()
        let patterns = CompletionPatterns()

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: patterns)
        XCTAssertTrue(signals.isColdStart)

        let context = signals.toPromptString()
        XCTAssertTrue(context.isEmpty, "Cold start should produce no behavior context")

        // Build the prompt — should be identical to pre-#210 behavior
        let tasks = [
            (index: 1, title: "Buy groceries", dueDate: Date() as Date?, priority: "Medium"),
            (index: 2, title: "Call dentist", dueDate: nil as Date?, priority: "High"),
            (index: 3, title: "Review PR", dueDate: nil as Date?, priority: "Low")
        ]
        let prompt = PromptTemplates.buildTaskOrderingPrompt(tasks: tasks, userBehaviorContext: nil)

        XCTAssertTrue(prompt.contains("Buy groceries"))
        XCTAssertTrue(prompt.contains("Call dentist"))
        XCTAssertFalse(prompt.contains("behavior"), "Cold start prompt should not contain behavior section")
        XCTAssertFalse(prompt.contains("interactions"), "Cold start prompt should not mention interactions")
        XCTAssertTrue(prompt.contains("due dates first"), "Base heuristic guidance should still be present")
    }

    // MARK: - Feedback Accumulation Journey

    func testGradualFeedback_SignalsAppearAfterThreshold() {
        var feedback = SuggestionFeedback()
        let patterns = CompletionPatterns()

        // Phase 1: 5 events — still cold start
        for _ in 0..<5 {
            feedback.events.append(makeEvent(.startedImmediately, .work, hour: 9))
        }
        var signals = BehavioralSignals.extract(from: feedback, completionPatterns: patterns)
        XCTAssertTrue(signals.isColdStart, "5 events should still be cold start")
        XCTAssertTrue(signals.toPromptString().isEmpty)

        // Phase 2: 5 more events — crosses 10-event threshold
        for _ in 0..<5 {
            feedback.events.append(makeEvent(.startedImmediately, .work, hour: 10))
        }
        signals = BehavioralSignals.extract(from: feedback, completionPatterns: patterns)
        XCTAssertFalse(signals.isColdStart, "10 events should exit cold start")

        let context = signals.toPromptString()
        XCTAssertFalse(context.isEmpty, "Should produce context after 10 events")
        XCTAssertTrue(context.contains("morning"), "10 morning starts should produce time preference")
        XCTAssertTrue(context.contains("Work"), "10 work starts should produce category affinity")
    }

    // MARK: - Realistic User Session

    func testRealisticSession_MixedFeedback_ProducesExpectedSignals() {
        var feedback = SuggestionFeedback()

        // Simulate 2 weeks of realistic usage:
        // Morning: User consistently starts Work tasks
        for _ in 0..<8 {
            feedback.events.append(makeEvent(.startedImmediately, .work, hour: 9))
        }

        // Afternoon: User views Health details but often snoozes Errands
        for _ in 0..<3 {
            feedback.events.append(makeEvent(.viewedDetails, .health, hour: 14))
        }
        for _ in 0..<4 {
            feedback.events.append(makeEvent(.snoozedEvening, .errands, hour: 14))
        }

        // Evening: User skips Work tasks as "wrong time"
        for _ in 0..<3 {
            feedback.events.append(makeEvent(.skippedWrongTime, .work, hour: 20))
        }

        // Also some "needs focus" skips for Learning
        for _ in 0..<3 {
            feedback.events.append(makeEvent(.skippedNeedsFocus, .learning, hour: 15))
        }

        // Total: 8 + 3 + 4 + 3 + 3 = 21 events

        // Add completion patterns from real usage
        var patterns = CompletionPatterns()
        patterns.categoryTimePatterns["1_9"] = 6   // Work at 9 AM: 6 completions
        patterns.categoryTimePatterns["3_18"] = 3  // Health at 6 PM: below threshold

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: patterns)

        // Verify extracted signals match expected behavior
        XCTAssertFalse(signals.isColdStart)
        XCTAssertEqual(signals.totalEvents, 21)

        // Time preference: 11 positive events (8 starts + 3 details), 8 morning = 73%
        XCTAssertNotNil(signals.timePreference, "Should detect morning time preference")
        XCTAssertEqual(signals.timePreference?.bucket, .morning)

        // Category affinity: Work has 8 starts(+16) + 3 wrongTime skips(-6) = score 10, support 11
        // Health has 3 details(+3) = score 3, support 3
        XCTAssertFalse(signals.categoryAffinity.isEmpty)
        XCTAssertEqual(signals.categoryAffinity.first?.category, .work)

        // Snooze hotspot: 4 snoozes of errands in afternoon
        XCTAssertNotNil(signals.snoozeHotspot)
        XCTAssertEqual(signals.snoozeHotspot?.category, .errands)
        XCTAssertEqual(signals.snoozeHotspot?.bucket, .afternoon)

        // Skip hotspots: wrongTime for work (3), needsFocus for learning (3)
        XCTAssertEqual(signals.skipReasonHotspots.count, 2)
        let wrongTimeHotspot = signals.skipReasonHotspots.first { $0.reason == .wrongTime }
        XCTAssertEqual(wrongTimeHotspot?.category, .work)
        let needsFocusHotspot = signals.skipReasonHotspots.first { $0.reason == .needsFocus }
        XCTAssertEqual(needsFocusHotspot?.category, .learning)

        // Completion peak: Work at morning (6 completions)
        XCTAssertNotNil(signals.completionPeak)
        XCTAssertEqual(signals.completionPeak?.category, .work)
        XCTAssertEqual(signals.completionPeak?.bucket, .morning)

        // Verify the prompt string is well-formed and contains all signals
        let prompt = signals.toPromptString()
        XCTAssertTrue(prompt.contains("21 interactions"))
        XCTAssertTrue(prompt.contains("morning"))
        XCTAssertTrue(prompt.contains("Work"))
        XCTAssertTrue(prompt.contains("snoozed"))
        XCTAssertTrue(prompt.contains("Errands"))
        XCTAssertTrue(prompt.contains("wrong time"))
        XCTAssertTrue(prompt.contains("needs focus"))
        XCTAssertTrue(prompt.contains("Completes"))
        XCTAssertTrue(prompt.contains("within 2 positions"))
    }

    // MARK: - Full Pipeline: Signals → Prompt → LLM Response → Clamped Output

    func testFullPipeline_SignalsInPrompt_ResponseClamped() {
        // Step 1: Build feedback that produces signals
        var feedback = SuggestionFeedback()
        for _ in 0..<12 {
            feedback.events.append(makeEvent(.startedImmediately, .work, hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())
        let behaviorContext = signals.toPromptString()
        XCTAssertFalse(behaviorContext.isEmpty, "Should have behavior context")

        // Step 2: Build the prompt with behavior context
        let tasks = [
            (index: 1, title: "Review quarterly report", dueDate: nil as Date?, priority: "High"),
            (index: 2, title: "Buy groceries", dueDate: nil as Date?, priority: "Low"),
            (index: 3, title: "Morning standup prep", dueDate: Date() as Date?, priority: "Medium"),
            (index: 4, title: "Read ML paper", dueDate: nil as Date?, priority: "Low"),
            (index: 5, title: "Fix login bug", dueDate: Date() as Date?, priority: "Urgent")
        ]
        let prompt = PromptTemplates.buildTaskOrderingPrompt(tasks: tasks, userBehaviorContext: behaviorContext)

        // Verify prompt structure
        XCTAssertTrue(prompt.contains("Review quarterly report"))
        XCTAssertTrue(prompt.contains("User behavior from 12 interactions"))
        XCTAssertTrue(prompt.contains("morning"))
        XCTAssertTrue(prompt.contains("within 2 positions"))

        // Step 3: Simulate LLM response — a wild reordering [5, 1, 4, 3, 2]
        // This moves task 5 from position 4→0 (displacement 4) and task 2 from position 1→4 (displacement 3)
        let wildReorder = [5, 1, 4, 3, 2]

        // Step 4: Sanitize and clamp
        let sanitized = LLMService.sanitizePermutation(wildReorder, n: 5)
        XCTAssertEqual(sanitized, [5, 1, 4, 3, 2], "Already valid permutation")

        let clamped = LLMService.clampPermutationGreedy(sanitized, maxDisplacement: 2)

        // Step 5: Verify displacement constraint
        for (position, taskNumber) in clamped.enumerated() {
            let baseline = taskNumber - 1
            let displacement = abs(position - baseline)
            XCTAssertLessThanOrEqual(displacement, 2,
                "Task \(taskNumber) displaced by \(displacement) (pos \(position), baseline \(baseline))")
        }

        // Verify it's still a valid permutation
        XCTAssertEqual(Set(clamped), Set(1...5), "Must be valid permutation of 1...5")

        // Verify the clamped result is different from the wild input (proving clamping did something)
        XCTAssertNotEqual(clamped, wildReorder, "Wild reorder should have been clamped")
    }

    // MARK: - Edge Case: All Same Category

    func testAllSameCategory_ProducesTimePreferenceOnly() {
        var feedback = SuggestionFeedback()
        // 12 events all Work, all morning
        for _ in 0..<12 {
            feedback.events.append(makeEvent(.startedImmediately, .work, hour: 8))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        // Time preference should be present
        XCTAssertNotNil(signals.timePreference)
        XCTAssertEqual(signals.timePreference?.bucket, .morning)

        // Category affinity should show Work
        XCTAssertEqual(signals.categoryAffinity.count, 1)
        XCTAssertEqual(signals.categoryAffinity.first?.category, .work)

        // No snooze or skip hotspots
        XCTAssertNil(signals.snoozeHotspot)
        XCTAssertTrue(signals.skipReasonHotspots.isEmpty)
    }

    // MARK: - Edge Case: Mostly Negative Feedback

    func testMostlySkips_ProducesNegativeSignals() {
        var feedback = SuggestionFeedback()

        // 4 skippedWrongTime for errands at night
        for _ in 0..<4 {
            feedback.events.append(makeEvent(.skippedWrongTime, .errands, hour: 22))
        }
        // 4 skippedNeedsFocus for learning in afternoon
        for _ in 0..<4 {
            feedback.events.append(makeEvent(.skippedNeedsFocus, .learning, hour: 15))
        }
        // 2 starts to pad to 10 events
        feedback.events.append(makeEvent(.startedImmediately, .work, hour: 9))
        feedback.events.append(makeEvent(.startedImmediately, .personal, hour: 18))

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        // No time preference (only 2 positive events, below 6 threshold)
        XCTAssertNil(signals.timePreference)

        // No positive category affinity (errands: -8, learning: -8)
        XCTAssertTrue(signals.categoryAffinity.isEmpty)

        // Skip hotspots should be present
        XCTAssertEqual(signals.skipReasonHotspots.count, 2)

        // Prompt should mention skip patterns but not positive preferences
        let prompt = signals.toPromptString()
        XCTAssertTrue(prompt.contains("wrong time"))
        XCTAssertTrue(prompt.contains("needs focus"))
        XCTAssertFalse(prompt.contains("Prefers engaging"))
        XCTAssertFalse(prompt.contains("Strongest categories"))
    }

    // MARK: - Edge Case: LLM Returns Garbage

    func testGarbageLLMResponse_FallsBackToBaseline() {
        // Simulate LLM returning nonsense
        let garbage1 = LLMService.sanitizePermutation([99, -1, 0], n: 5)
        XCTAssertEqual(garbage1, [1, 2, 3, 4, 5], "All invalid → baseline")

        let garbage2 = LLMService.sanitizePermutation([], n: 3)
        XCTAssertEqual(garbage2, [1, 2, 3], "Empty → baseline")

        let garbage3 = LLMService.sanitizePermutation([1, 1, 1, 1], n: 4)
        XCTAssertEqual(garbage3, [1, 2, 3, 4], "All duplicates → first kept, rest filled")

        // Clamp on baseline is identity
        let clamped = LLMService.clampPermutationGreedy(garbage1, maxDisplacement: 2)
        XCTAssertEqual(clamped, [1, 2, 3, 4, 5])
    }

    // MARK: - Verify Feedback Recording → Signal Pipeline

    func testFeedbackRecording_FlowsThroughToSignals() {
        var feedback = SuggestionFeedback()

        // Simulate the actual recordFeedback flow (as called by PrioritizationService)
        for _ in 0..<6 {
            let taskID = UUID()
            feedback.recordFeedback(taskID: taskID, action: .startedImmediately, originalScore: 75, taskCategory: .work)
        }
        for _ in 0..<4 {
            let taskID = UUID()
            feedback.recordFeedback(taskID: taskID, action: .snoozedEvening, originalScore: 60, taskCategory: .personal)
        }
        for _ in 0..<3 {
            let taskID = UUID()
            feedback.recordFeedback(taskID: taskID, action: .skippedWrongTime, originalScore: 40, taskCategory: .errands)
        }

        // Verify events were recorded with correct metadata
        XCTAssertEqual(feedback.events.count, 13)

        // Extract signals from the recorded feedback
        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())
        XCTAssertFalse(signals.isColdStart)
        XCTAssertEqual(signals.totalEvents, 13)

        // Verify the hour metadata was captured (should be current hour)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let expectedBucket = TimeBucket.from(hour: currentHour)

        // Time preference should reflect current time of day (all 6 positive events at same hour)
        if signals.timePreference != nil {
            XCTAssertEqual(signals.timePreference?.bucket, expectedBucket)
        }

        // Category affinity: Work has 6 starts (+12), support 6 → should qualify
        XCTAssertTrue(signals.categoryAffinity.contains { $0.category == .work })
    }

    // MARK: - Helpers

    private func makeEvent(_ action: FeedbackAction, _ category: TaskCategory, hour: Int) -> FeedbackEvent {
        FeedbackEvent(
            taskID: UUID(),
            action: action,
            timestamp: Date(),
            originalScore: 50,
            taskCategory: category,
            hourOfDay: hour
        )
    }
}
