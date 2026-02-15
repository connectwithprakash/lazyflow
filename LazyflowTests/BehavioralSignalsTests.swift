import XCTest
@testable import Lazyflow

final class BehavioralSignalsTests: XCTestCase {

    // MARK: - TimeBucket Tests

    func testTimeBucket_FromHour() {
        XCTAssertEqual(TimeBucket.from(hour: 6), .morning)
        XCTAssertEqual(TimeBucket.from(hour: 11), .morning)
        XCTAssertEqual(TimeBucket.from(hour: 12), .afternoon)
        XCTAssertEqual(TimeBucket.from(hour: 16), .afternoon)
        XCTAssertEqual(TimeBucket.from(hour: 17), .evening)
        XCTAssertEqual(TimeBucket.from(hour: 20), .evening)
        XCTAssertEqual(TimeBucket.from(hour: 21), .night)
        XCTAssertEqual(TimeBucket.from(hour: 3), .night)
    }

    // MARK: - Cold Start Tests

    func testExtract_ColdStart_NoEvents() {
        let feedback = SuggestionFeedback()
        let patterns = CompletionPatterns()

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: patterns)

        XCTAssertTrue(signals.isColdStart)
        XCTAssertEqual(signals.totalEvents, 0)
        XCTAssertNil(signals.timePreference)
        XCTAssertTrue(signals.categoryAffinity.isEmpty)
        XCTAssertNil(signals.snoozeHotspot)
        XCTAssertTrue(signals.skipReasonHotspots.isEmpty)
        XCTAssertNil(signals.completionPeak)
    }

    func testExtract_ColdStart_FewEvents() {
        var feedback = SuggestionFeedback()
        // Add 5 events — below the 10-event threshold
        for _ in 0..<5 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertTrue(signals.isColdStart)
        XCTAssertEqual(signals.totalEvents, 5)
    }

    func testExtract_ColdStart_CompletionPeakOverrides() {
        let feedback = SuggestionFeedback()
        var patterns = CompletionPatterns()
        // 5 completions of work at 9 AM
        patterns.categoryTimePatterns["1_9"] = 5

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: patterns)

        // Even with no events, completion peak breaks cold start
        XCTAssertFalse(signals.isColdStart)
        XCTAssertNotNil(signals.completionPeak)
    }

    // MARK: - Time Preference Tests

    func testExtract_TimePreference_DominantBucket() {
        var feedback = SuggestionFeedback()
        // 8 morning starts + 2 afternoon starts = 80% morning share
        for _ in 0..<8 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }
        for _ in 0..<2 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .personal, hour: 14))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertNotNil(signals.timePreference)
        XCTAssertEqual(signals.timePreference?.bucket, .morning)
        XCTAssertEqual(signals.timePreference?.support, 10) // all 10 are positive
        XCTAssertEqual(signals.timePreference?.share ?? 0, 0.8, accuracy: 0.01)
    }

    func testExtract_TimePreference_BelowShareThreshold() {
        var feedback = SuggestionFeedback()
        // 4 morning + 3 afternoon + 3 evening = 40% morning share (exactly threshold)
        for _ in 0..<4 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .viewedDetails, category: .work, hour: 14))
        }
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .viewedDetails, category: .work, hour: 19))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        // 40% is the threshold — should match (>= 0.40)
        XCTAssertNotNil(signals.timePreference)
        XCTAssertEqual(signals.timePreference?.bucket, .morning)
    }

    func testExtract_TimePreference_NotEnoughPositiveEvents() {
        var feedback = SuggestionFeedback()
        // 5 positive + 5 skips = only 5 positive, below 6 threshold
        for _ in 0..<5 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }
        for _ in 0..<5 {
            feedback.events.append(makeEvent(action: .skippedNotRelevant, category: .work, hour: 14))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertNil(signals.timePreference)
    }

    // MARK: - Category Affinity Tests

    func testExtract_CategoryAffinity_TopTwo() {
        var feedback = SuggestionFeedback()
        // Work: 5 starts (+10) + 1 skip (-2) = score 8, support 6
        for _ in 0..<5 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }
        feedback.events.append(makeEvent(action: .skippedNotRelevant, category: .work, hour: 15))

        // Health: 3 starts (+6) = score 6, support 3
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .health, hour: 18))
        }

        // Errands: 1 start (+2) + 2 skips (-4) = score -2, support 3 — should NOT qualify (score < 2)
        feedback.events.append(makeEvent(action: .startedImmediately, category: .errands, hour: 12))
        for _ in 0..<2 {
            feedback.events.append(makeEvent(action: .skippedNotRelevant, category: .errands, hour: 12))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertEqual(signals.categoryAffinity.count, 2)
        XCTAssertEqual(signals.categoryAffinity[0].category, .work)
        XCTAssertEqual(signals.categoryAffinity[1].category, .health)
    }

    func testExtract_CategoryAffinity_BelowSupportThreshold() {
        var feedback = SuggestionFeedback()
        // 10 events but all different categories (support = 1 each)
        for i in 0..<10 {
            let categories: [TaskCategory] = [.work, .personal, .health, .finance, .shopping,
                                               .errands, .learning, .home, .uncategorized, .work]
            feedback.events.append(makeEvent(action: .startedImmediately, category: categories[i], hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        // Work has support=2 which is < 3 threshold, all others have support=1
        XCTAssertTrue(signals.categoryAffinity.isEmpty)
    }

    // MARK: - Snooze Hotspot Tests

    func testExtract_SnoozeHotspot_Identified() {
        var feedback = SuggestionFeedback()
        // 3 snoozes of work in morning + 1 snooze of personal in evening = hotspot is work@morning
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .snoozedEvening, category: .work, hour: 10))
        }
        feedback.events.append(makeEvent(action: .snoozed1Hour, category: .personal, hour: 19))
        // Pad to reach 10 total events
        for _ in 0..<6 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertNotNil(signals.snoozeHotspot)
        XCTAssertEqual(signals.snoozeHotspot?.category, .work)
        XCTAssertEqual(signals.snoozeHotspot?.bucket, .morning)
        XCTAssertEqual(signals.snoozeHotspot?.count, 3)
    }

    func testExtract_SnoozeHotspot_NotEnoughSnoozes() {
        var feedback = SuggestionFeedback()
        // Only 3 total snoozes (threshold is 4)
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .snoozed1Hour, category: .work, hour: 10))
        }
        for _ in 0..<7 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertNil(signals.snoozeHotspot)
    }

    // MARK: - Skip Reason Hotspot Tests

    func testExtract_SkipWrongTime_Hotspot() {
        var feedback = SuggestionFeedback()
        // 4 "wrong time" skips for errands
        for _ in 0..<4 {
            feedback.events.append(makeEvent(action: .skippedWrongTime, category: .errands, hour: 22))
        }
        // Pad to 10
        for _ in 0..<6 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertEqual(signals.skipReasonHotspots.count, 1)
        XCTAssertEqual(signals.skipReasonHotspots.first?.reason, .wrongTime)
        XCTAssertEqual(signals.skipReasonHotspots.first?.category, .errands)
    }

    func testExtract_SkipNeedsFocus_Hotspot() {
        var feedback = SuggestionFeedback()
        // 3 "needs focus" skips for learning
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .skippedNeedsFocus, category: .learning, hour: 15))
        }
        // Pad to 10
        for _ in 0..<7 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertEqual(signals.skipReasonHotspots.count, 1)
        XCTAssertEqual(signals.skipReasonHotspots.first?.reason, .needsFocus)
        XCTAssertEqual(signals.skipReasonHotspots.first?.category, .learning)
    }

    func testExtract_SkipReasons_BothPresent() {
        var feedback = SuggestionFeedback()
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .skippedWrongTime, category: .errands, hour: 22))
        }
        for _ in 0..<3 {
            feedback.events.append(makeEvent(action: .skippedNeedsFocus, category: .learning, hour: 15))
        }
        // Pad to 10
        for _ in 0..<4 {
            feedback.events.append(makeEvent(action: .startedImmediately, category: .work, hour: 9))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())

        XCTAssertEqual(signals.skipReasonHotspots.count, 2)
    }

    // MARK: - Completion Peak Tests

    func testExtract_CompletionPeak_FromPatterns() {
        var patterns = CompletionPatterns()
        // Work at 9 AM: 6 completions (key: "1_9")
        patterns.categoryTimePatterns["1_9"] = 6
        patterns.categoryTimePatterns["2_18"] = 2 // below threshold

        let signals = BehavioralSignals.extract(from: SuggestionFeedback(), completionPatterns: patterns)

        XCTAssertNotNil(signals.completionPeak)
        XCTAssertEqual(signals.completionPeak?.category, .work)
        XCTAssertEqual(signals.completionPeak?.bucket, .morning)
        XCTAssertEqual(signals.completionPeak?.count, 6)
    }

    func testExtract_CompletionPeak_BelowThreshold() {
        var patterns = CompletionPatterns()
        patterns.categoryTimePatterns["1_9"] = 3 // below 4 threshold

        let signals = BehavioralSignals.extract(from: SuggestionFeedback(), completionPatterns: patterns)

        XCTAssertNil(signals.completionPeak)
    }

    func testExtract_CompletionPeak_TiedCount_DeterministicTieBreak() {
        var patterns = CompletionPatterns()
        // Work at 9 AM and Personal at 6 PM both have count 5
        patterns.categoryTimePatterns["1_9"] = 5   // Work (rawValue 1), morning
        patterns.categoryTimePatterns["2_18"] = 5  // Personal (rawValue 2), evening

        let signals = BehavioralSignals.extract(from: SuggestionFeedback(), completionPatterns: patterns)

        // Tie-break: lower category rawValue wins → Work
        XCTAssertNotNil(signals.completionPeak)
        XCTAssertEqual(signals.completionPeak?.category, .work)
        XCTAssertEqual(signals.completionPeak?.bucket, .morning)
    }

    func testExtract_CompletionPeak_MalformedKey_SkipsToValidOne() {
        var patterns = CompletionPatterns()
        // Malformed key has highest count but will fail parsing
        patterns.categoryTimePatterns["invalid_key"] = 10
        // Valid entry should be found
        patterns.categoryTimePatterns["3_7"] = 4  // Health at 7 AM

        let signals = BehavioralSignals.extract(from: SuggestionFeedback(), completionPatterns: patterns)

        XCTAssertNotNil(signals.completionPeak)
        XCTAssertEqual(signals.completionPeak?.category, .health)
        XCTAssertEqual(signals.completionPeak?.bucket, .morning)
    }

    // MARK: - Prompt String Tests

    func testToPromptString_ColdStart_ReturnsEmpty() {
        let signals = BehavioralSignals(
            totalEvents: 3,
            timePreference: nil,
            categoryAffinity: [],
            snoozeHotspot: nil,
            skipReasonHotspots: [],
            completionPeak: nil
        )

        XCTAssertTrue(signals.isColdStart)
        XCTAssertEqual(signals.toPromptString(), "")
    }

    func testToPromptString_WithSignals_ContainsExpectedLines() {
        let signals = BehavioralSignals(
            totalEvents: 25,
            timePreference: .init(bucket: .morning, support: 15, share: 0.75),
            categoryAffinity: [
                .init(category: .work, score: 8, support: 10),
                .init(category: .health, score: 4, support: 5)
            ],
            snoozeHotspot: .init(category: .work, bucket: .evening, count: 4),
            skipReasonHotspots: [
                .init(reason: .wrongTime, category: .errands, count: 3)
            ],
            completionPeak: .init(category: .work, bucket: .morning, count: 7)
        )

        let prompt = signals.toPromptString()

        XCTAssertTrue(prompt.contains("25 interactions"))
        XCTAssertTrue(prompt.contains("morning"))
        XCTAssertTrue(prompt.contains("75%"))
        XCTAssertTrue(prompt.contains("Work"))
        XCTAssertTrue(prompt.contains("Health"))
        XCTAssertTrue(prompt.contains("snoozed"))
        XCTAssertTrue(prompt.contains("wrong time"))
        XCTAssertTrue(prompt.contains("Completes"))
        XCTAssertTrue(prompt.contains("within 2 positions"))
    }

    func testToPromptString_OnlyCompletionPeak() {
        let signals = BehavioralSignals(
            totalEvents: 0,
            timePreference: nil,
            categoryAffinity: [],
            snoozeHotspot: nil,
            skipReasonHotspots: [],
            completionPeak: .init(category: .learning, bucket: .evening, count: 5)
        )

        XCTAssertFalse(signals.isColdStart)
        let prompt = signals.toPromptString()
        XCTAssertTrue(prompt.contains("Learning"))
        XCTAssertTrue(prompt.contains("evening"))
    }

    // MARK: - Helpers

    private func makeEvent(
        action: FeedbackAction,
        category: TaskCategory,
        hour: Int
    ) -> FeedbackEvent {
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
