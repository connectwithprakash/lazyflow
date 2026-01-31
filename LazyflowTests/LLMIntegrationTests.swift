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
