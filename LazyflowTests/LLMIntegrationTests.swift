import XCTest
@testable import Lazyflow

/// Integration tests that call actual Apple Intelligence on physical device
/// These tests require a device with Apple Intelligence enabled
final class LLMIntegrationTests: XCTestCase {

    // MARK: - Duration Estimation

    func testActualDurationEstimation_Groceries() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let result = try await LLMService.shared.estimateTaskDuration(
            title: "Buy groceries",
            notes: "Get milk, eggs, bread, and vegetables"
        )

        print("=== DURATION ESTIMATION: Groceries ===")
        print("Input: Buy groceries (Get milk, eggs, bread, and vegetables)")
        print("Response: \(result.estimatedMinutes) minutes")
        print("Confidence: \(result.confidence)")
        print("Reasoning: \(result.reasoning)")
        print("=======================================")

        XCTAssertGreaterThanOrEqual(result.estimatedMinutes, 5)
        XCTAssertLessThanOrEqual(result.estimatedMinutes, 480)
    }

    func testActualDurationEstimation_Report() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let result = try await LLMService.shared.estimateTaskDuration(
            title: "Write quarterly report",
            notes: "Summarize Q4 sales data and create charts"
        )

        print("=== DURATION ESTIMATION: Report ===")
        print("Input: Write quarterly report (Summarize Q4 sales data and create charts)")
        print("Response: \(result.estimatedMinutes) minutes")
        print("Confidence: \(result.confidence)")
        print("Reasoning: \(result.reasoning)")
        print("===================================")

        XCTAssertGreaterThanOrEqual(result.estimatedMinutes, 5)
        XCTAssertLessThanOrEqual(result.estimatedMinutes, 480)
    }

    // MARK: - Priority Suggestion

    func testActualPrioritySuggestion_UrgentDeadline() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())

        let result = try await LLMService.shared.suggestPriority(
            title: "Submit tax forms",
            notes: "IRS deadline",
            dueDate: tomorrow
        )

        print("=== PRIORITY SUGGESTION: Tax Forms ===")
        print("Input: Submit tax forms (IRS deadline, due tomorrow)")
        print("Response: \(result.priority.displayName)")
        print("Reasoning: \(result.reasoning)")
        print("======================================")
    }

    func testActualPrioritySuggestion_Casual() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let result = try await LLMService.shared.suggestPriority(
            title: "Organize bookshelf",
            notes: nil,
            dueDate: nil
        )

        print("=== PRIORITY SUGGESTION: Bookshelf ===")
        print("Input: Organize bookshelf (no notes, no due date)")
        print("Response: \(result.priority.displayName)")
        print("Reasoning: \(result.reasoning)")
        print("======================================")
    }

    // MARK: - Full Analysis

    func testActualFullAnalysis_WorkTask() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let task = Task(
            title: "Prepare presentation for Monday meeting",
            notes: "Team sync about Q1 goals",
            priority: .medium
        )

        let result = try await LLMService.shared.analyzeTask(task)

        print("=== FULL ANALYSIS: Presentation ===")
        print("Input: Prepare presentation for Monday meeting")
        print("Duration: \(result.estimatedMinutes) minutes")
        print("Priority: \(result.suggestedPriority.displayName)")
        print("Best Time: \(result.bestTime.rawValue)")
        print("Category: \(result.suggestedCategory.displayName)")
        print("Refined Title: \(result.refinedTitle ?? "none")")
        print("Description: \(result.suggestedDescription ?? "none")")
        print("Subtasks: \(result.subtasks)")
        print("Tips: \(result.tips)")
        print("===================================")

        XCTAssertGreaterThanOrEqual(result.estimatedMinutes, 5)
        XCTAssertLessThanOrEqual(result.subtasks.count, 3)
    }

    func testActualFullAnalysis_BeforeAndAfterComparison() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let task = Task(
            title: "Write quarterly report",
            notes: "Q4 sales summary with charts",
            priority: .medium
        )

        // ============================================
        // BEFORE: Empty context (simulating #133 state)
        // ============================================
        AIContextService.shared.resetPatterns()

        let beforeContext = AIContextService.shared.buildContext(for: task)
        print("=== BEFORE (#133): Context sent to AI ===")
        print(beforeContext.toPromptString())
        print("==========================================")

        let beforeResult = try await LLMService.shared.analyzeTask(task)

        print("")
        print("=== BEFORE (#133): AI Response ===")
        print("Task: Write quarterly report")
        print("Duration: \(beforeResult.estimatedMinutes) minutes")
        print("Priority: \(beforeResult.suggestedPriority.displayName)")
        print("Best Time: \(beforeResult.bestTime.rawValue)")
        print("Category: \(beforeResult.suggestedCategory.displayName)")
        print("Subtasks: \(beforeResult.subtasks)")
        print("Tips: \(beforeResult.tips)")
        print("==================================")

        // ============================================
        // AFTER: Rich context with user history (#134)
        // ============================================
        let calendar = Calendar.current

        // Simulate user patterns: completes reports in morning, prefers Work category
        var patterns = UserPatterns()
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        for _ in 0..<5 {
            patterns.recordCompletion(category: "Work", priority: "High", duration: 90, completedAt: morning)
        }
        for _ in 0..<3 {
            patterns.recordCompletion(category: "Personal", priority: "Medium", duration: 30, completedAt: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!)
        }
        patterns.save()
        AIContextService.shared.reloadPatterns()

        let afterContext = AIContextService.shared.buildContext(for: task)
        print("")
        print("=== AFTER (#134): Context sent to AI ===")
        print(afterContext.toPromptString())
        print("=========================================")

        let afterResult = try await LLMService.shared.analyzeTask(task)

        print("")
        print("=== AFTER (#134): AI Response ===")
        print("Task: Write quarterly report")
        print("Duration: \(afterResult.estimatedMinutes) minutes")
        print("Priority: \(afterResult.suggestedPriority.displayName)")
        print("Best Time: \(afterResult.bestTime.rawValue)")
        print("Category: \(afterResult.suggestedCategory.displayName)")
        print("Subtasks: \(afterResult.subtasks)")
        print("Tips: \(afterResult.tips)")
        print("=================================")

        // Clean up
        AIContextService.shared.resetPatterns()

        XCTAssertGreaterThanOrEqual(beforeResult.estimatedMinutes, 5)
        XCTAssertGreaterThanOrEqual(afterResult.estimatedMinutes, 5)
    }

    func testActualFullAnalysis_WithSimulatedHistory() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        // Simulate user history by recording some patterns
        var patterns = UserPatterns.load()

        // Simulate: user completes work tasks in morning
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        for _ in 0..<5 {
            patterns.recordCompletion(category: "Work", priority: "High", duration: 60, completedAt: morning)
        }

        // Simulate: user completes personal tasks in evening
        let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
        for _ in 0..<3 {
            patterns.recordCompletion(category: "Personal", priority: "Medium", duration: 30, completedAt: evening)
        }

        patterns.save()

        // Reload patterns so AIContextService picks up the simulated history
        AIContextService.shared.reloadPatterns()

        let task = Task(
            title: "Review team performance",
            notes: "Quarterly review meeting prep",
            priority: .medium
        )

        // Build context with simulated history
        let context = AIContextService.shared.buildContext(for: task)

        print("=== CONTEXT WITH USER HISTORY ===")
        print(context.toPromptString())
        print("=================================")

        let result = try await LLMService.shared.analyzeTask(task)

        print("")
        print("=== AI RESPONSE (with history) ===")
        print("Task: Review team performance")
        print("Duration: \(result.estimatedMinutes) minutes")
        print("Priority: \(result.suggestedPriority.displayName)")
        print("Best Time: \(result.bestTime.rawValue)")
        print("Category: \(result.suggestedCategory.displayName)")
        print("Tips: \(result.tips)")
        print("==================================")

        // Clean up - reset patterns to avoid affecting other tests
        AIContextService.shared.resetPatterns()

        XCTAssertGreaterThanOrEqual(result.estimatedMinutes, 5)
    }

    func testActualFullAnalysis_PersonalTask() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let task = Task(
            title: "Call mom",
            notes: "Check how she's doing",
            priority: .none
        )

        let result = try await LLMService.shared.analyzeTask(task)

        print("=== FULL ANALYSIS: Personal ===")
        print("Input: Call mom (Check how she's doing)")
        print("Duration: \(result.estimatedMinutes) minutes")
        print("Priority: \(result.suggestedPriority.displayName)")
        print("Best Time: \(result.bestTime.rawValue)")
        print("Category: \(result.suggestedCategory.displayName)")
        print("Subtasks: \(result.subtasks)")
        print("Tips: \(result.tips)")
        print("===============================")
    }
}
