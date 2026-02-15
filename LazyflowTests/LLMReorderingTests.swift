import XCTest
@testable import Lazyflow

final class LLMReorderingTests: XCTestCase {

    // MARK: - Prompt Template Tests

    func testBuildTaskOrderingPrompt_NoBehaviorContext() {
        let tasks = [
            (index: 1, title: "Buy groceries", dueDate: nil as Date?, priority: "Medium"),
            (index: 2, title: "Call dentist", dueDate: nil as Date?, priority: "High")
        ]

        let prompt = PromptTemplates.buildTaskOrderingPrompt(tasks: tasks)

        XCTAssertTrue(prompt.contains("Buy groceries"))
        XCTAssertTrue(prompt.contains("Call dentist"))
        XCTAssertFalse(prompt.contains("User behavior"))
    }

    func testBuildTaskOrderingPrompt_WithBehaviorContext() {
        let tasks = [
            (index: 1, title: "Buy groceries", dueDate: nil as Date?, priority: "Medium")
        ]
        let context = "User behavior from 20 interactions:\n- Prefers morning."

        let prompt = PromptTemplates.buildTaskOrderingPrompt(tasks: tasks, userBehaviorContext: context)

        XCTAssertTrue(prompt.contains("User behavior from 20 interactions"))
        XCTAssertTrue(prompt.contains("Prefers morning"))
    }

    func testBuildTaskOrderingPrompt_EmptyBehaviorContext() {
        let tasks = [
            (index: 1, title: "Task", dueDate: nil as Date?, priority: "Low")
        ]

        let prompt = PromptTemplates.buildTaskOrderingPrompt(tasks: tasks, userBehaviorContext: "")

        // Empty context should not add extra section
        XCTAssertFalse(prompt.contains("User behavior"))
    }

    // MARK: - Sanitize Permutation Tests

    func testSanitize_ValidPermutation() {
        let result = LLMService.sanitizePermutation([3, 1, 2], n: 3)
        XCTAssertEqual(result, [3, 1, 2])
    }

    func testSanitize_Duplicates() {
        let result = LLMService.sanitizePermutation([2, 2, 1, 3], n: 3)
        XCTAssertEqual(result, [2, 1, 3])
    }

    func testSanitize_OutOfRange() {
        let result = LLMService.sanitizePermutation([0, 5, 2, -1, 1], n: 3)
        // Only 2 and 1 are valid; 3 is missing and appended
        XCTAssertEqual(result, [2, 1, 3])
    }

    func testSanitize_EmptyInput() {
        let result = LLMService.sanitizePermutation([], n: 4)
        XCTAssertEqual(result, [1, 2, 3, 4])
    }

    func testSanitize_AllMissing() {
        let result = LLMService.sanitizePermutation([10, 20], n: 3)
        XCTAssertEqual(result, [1, 2, 3])
    }

    func testSanitize_PartialOrder() {
        let result = LLMService.sanitizePermutation([3], n: 5)
        // 3 is first, then 1,2,4,5 appended in order
        XCTAssertEqual(result, [3, 1, 2, 4, 5])
    }

    // MARK: - Clamp Permutation Tests

    func testClamp_IdentityPermutation() {
        // Identity should remain unchanged
        let result = LLMService.clampPermutationGreedy([1, 2, 3, 4, 5], maxDisplacement: 2)
        XCTAssertEqual(result, [1, 2, 3, 4, 5])
    }

    func testClamp_SmallSwap_WithinBounds() {
        // Swap adjacent: [2, 1, 3, 4, 5] — both within ±2
        // Greedy prefers tightest window first: task 1 (window [0,2]) beats task 2 (window [0,3]) at slot 0
        let result = LLMService.clampPermutationGreedy([2, 1, 3, 4, 5], maxDisplacement: 2)
        // Verify all within bounds (greedy may return baseline when candidate swap is within bounds)
        for (position, taskNumber) in result.enumerated() {
            let displacement = abs(position - (taskNumber - 1))
            XCTAssertLessThanOrEqual(displacement, 2)
        }
        XCTAssertEqual(Set(result), Set(1...5))
    }

    func testClamp_LargeDisplacement_GetsClamped() {
        // Full reverse: [5, 4, 3, 2, 1] — task 5 moves from pos 4 to pos 0 = displacement 4 > 2
        let result = LLMService.clampPermutationGreedy([5, 4, 3, 2, 1], maxDisplacement: 2)

        // Verify every task is displaced by at most 2
        for (position, taskNumber) in result.enumerated() {
            let baseline = taskNumber - 1
            let displacement = abs(position - baseline)
            XCTAssertLessThanOrEqual(displacement, 2,
                "Task \(taskNumber) at position \(position) has displacement \(displacement)")
        }

        // Verify it's a valid permutation
        XCTAssertEqual(Set(result), Set(1...5))
    }

    func testClamp_SingleElement() {
        let result = LLMService.clampPermutationGreedy([1], maxDisplacement: 2)
        XCTAssertEqual(result, [1])
    }

    func testClamp_TwoElements_Swap() {
        // [2, 1] — displacement is 1 for both, within ±2
        let result = LLMService.clampPermutationGreedy([2, 1], maxDisplacement: 2)
        XCTAssertEqual(result, [2, 1])
    }

    func testClamp_DisplacementBound_AllPositions() {
        // Test with 10 elements (max used in production) and a wild reordering
        let reversed = Array((1...10).reversed())
        let result = LLMService.clampPermutationGreedy(reversed, maxDisplacement: 2)

        // Every task within ±2 of its baseline
        for (position, taskNumber) in result.enumerated() {
            let displacement = abs(position - (taskNumber - 1))
            XCTAssertLessThanOrEqual(displacement, 2,
                "Task \(taskNumber) at position \(position) has displacement \(displacement)")
        }

        // Valid permutation
        XCTAssertEqual(Set(result), Set(1...10))
    }

    func testClamp_ShiftByThree_GetsClamped() {
        // [4, 5, 6, 1, 2, 3] — tasks 1-3 moved by 3 positions each
        let result = LLMService.clampPermutationGreedy([4, 5, 6, 1, 2, 3], maxDisplacement: 2)

        for (position, taskNumber) in result.enumerated() {
            let displacement = abs(position - (taskNumber - 1))
            XCTAssertLessThanOrEqual(displacement, 2,
                "Task \(taskNumber) at position \(position) has displacement \(displacement)")
        }
        XCTAssertEqual(Set(result), Set(1...6))
    }

    // MARK: - Integration: BehavioralSignals + Prompt

    func testBehavioralSignals_ColdStart_ProducesNoContext() {
        let feedback = SuggestionFeedback()
        let patterns = CompletionPatterns()
        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: patterns)

        XCTAssertTrue(signals.isColdStart)

        // Cold start produces empty string
        let context = signals.toPromptString()
        XCTAssertTrue(context.isEmpty)

        // Building prompt with nil context should not include behavior section
        let tasks = [(index: 1, title: "Test", dueDate: nil as Date?, priority: "Low")]
        let prompt = PromptTemplates.buildTaskOrderingPrompt(tasks: tasks, userBehaviorContext: nil)
        XCTAssertFalse(prompt.contains("behavior"))
    }

    func testBehavioralSignals_RichData_ProducesContext() {
        var feedback = SuggestionFeedback()
        // 12 morning starts for work category
        for _ in 0..<12 {
            feedback.events.append(FeedbackEvent(
                taskID: UUID(),
                action: .startedImmediately,
                category: .work,
                hour: 9
            ))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())
        XCTAssertFalse(signals.isColdStart)

        let context = signals.toPromptString()
        XCTAssertFalse(context.isEmpty)
        XCTAssertTrue(context.contains("morning"))
        XCTAssertTrue(context.contains("Work"))
    }

    func testBehavioralSignals_NoSignals_EmptyContext() {
        var feedback = SuggestionFeedback()
        // 10 events of varied actions spread across categories — no signal meets thresholds
        let actions: [FeedbackAction] = [
            .startedImmediately, .viewedDetails, .snoozed1Hour, .skippedNotRelevant, .skippedWrongTime,
            .startedImmediately, .snoozedEvening, .skippedNeedsFocus, .viewedDetails, .snoozedTomorrow
        ]
        let categories: [TaskCategory] = [
            .work, .personal, .health, .finance, .shopping,
            .errands, .learning, .home, .uncategorized, .work
        ]
        let hours = [6, 10, 14, 18, 22, 8, 12, 16, 20, 2]

        for i in 0..<10 {
            feedback.events.append(FeedbackEvent(
                taskID: UUID(),
                action: actions[i],
                timestamp: Date(),
                originalScore: 50,
                taskCategory: categories[i],
                hourOfDay: hours[i]
            ))
        }

        let signals = BehavioralSignals.extract(from: feedback, completionPatterns: CompletionPatterns())
        XCTAssertFalse(signals.isColdStart) // 10 events, not cold start
        // But no individual signal meets its threshold
        let context = signals.toPromptString()
        XCTAssertTrue(context.isEmpty, "Should be empty when no signal lines are present")
    }
}

// MARK: - FeedbackEvent convenience init for tests

private extension FeedbackEvent {
    init(taskID: UUID, action: FeedbackAction, category: TaskCategory, hour: Int) {
        self.init(
            taskID: taskID,
            action: action,
            timestamp: Date(),
            originalScore: 50,
            taskCategory: category,
            hourOfDay: hour
        )
    }
}
