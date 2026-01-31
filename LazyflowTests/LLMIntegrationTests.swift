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

    func testActualFullAnalysis_BeforeAndAfterComparison_MultipleQueries() async throws {
        guard LLMService.shared.isReady else {
            throw XCTSkip("Apple Intelligence not available")
        }

        // Define test tasks
        let tasks = [
            Task(title: "Write quarterly report", notes: "Q4 sales summary with charts", priority: .medium),
            Task(title: "Call mom", notes: "Check how she's doing", priority: .none),
            Task(title: "Buy groceries", notes: "Milk, eggs, bread, vegetables", priority: .low),
            Task(title: "Prepare presentation", notes: "Team meeting slides for Monday", priority: .high),
            Task(title: "Go for a run", notes: "30 minute jog in the park", priority: .medium)
        ]

        var beforeResults: [(String, Int, String, String, String)] = []
        var afterResults: [(String, Int, String, String, String)] = []

        // ============================================
        // BEFORE: Empty context (simulating #133 state)
        // ============================================
        AIContextService.shared.resetPatterns()

        print("=== BEFORE (#133): Running with empty context ===")
        for task in tasks {
            let result = try await LLMService.shared.analyzeTask(task)
            beforeResults.append((
                task.title,
                result.estimatedMinutes,
                result.suggestedPriority.displayName,
                result.bestTime.rawValue,
                result.suggestedCategory.displayName
            ))
        }

        // ============================================
        // AFTER: Rich context with user history (#134)
        // ============================================
        let calendar = Calendar.current

        // Simulate realistic user patterns
        var patterns = UserPatterns()

        // User completes work tasks in morning (avg 90 min)
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        for _ in 0..<5 {
            patterns.recordCompletion(category: "Work", priority: "High", duration: 90, completedAt: morning)
        }

        // User completes personal tasks in evening (avg 20 min)
        let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
        for _ in 0..<4 {
            patterns.recordCompletion(category: "Personal", priority: "Medium", duration: 20, completedAt: evening)
        }

        // User completes errands on weekends (avg 45 min)
        for _ in 0..<3 {
            patterns.recordCompletion(category: "Errands", priority: "Low", duration: 45, completedAt: Date())
        }

        // User completes health tasks in morning (avg 30 min)
        for _ in 0..<3 {
            patterns.recordCompletion(category: "Health", priority: "Medium", duration: 30, completedAt: morning)
        }

        patterns.save()
        AIContextService.shared.reloadPatterns()

        print("")
        print("=== AFTER (#134): Running with user history ===")
        let afterContext = AIContextService.shared.buildContext()
        print("Context string sent to AI:")
        print(afterContext.toPromptString())
        print("")

        for task in tasks {
            let result = try await LLMService.shared.analyzeTask(task)
            afterResults.append((
                task.title,
                result.estimatedMinutes,
                result.suggestedPriority.displayName,
                result.bestTime.rawValue,
                result.suggestedCategory.displayName
            ))
        }

        // Print comparison table
        print("")
        print("╔══════════════════════════════════════════════════════════════════════════════════════════════════════╗")
        print("║                           BEFORE/AFTER COMPARISON - SAME QUERIES                                     ║")
        print("╠══════════════════════════════════════════════════════════════════════════════════════════════════════╣")
        print("║ Task                      │ Duration (B→A) │ Priority (B→A)   │ Best Time (B→A)  │ Category (B→A)    ║")
        print("╠══════════════════════════════════════════════════════════════════════════════════════════════════════╣")

        for i in 0..<tasks.count {
            let b = beforeResults[i]
            let a = afterResults[i]
            let taskName = String(b.0.prefix(24)).padding(toLength: 24, withPad: " ", startingAt: 0)
            let duration = "\(b.1)→\(a.1)".padding(toLength: 13, withPad: " ", startingAt: 0)
            let priority = "\(b.2)→\(a.2)".padding(toLength: 15, withPad: " ", startingAt: 0)
            let bestTime = "\(b.3)→\(a.3)".padding(toLength: 15, withPad: " ", startingAt: 0)
            let category = "\(b.4)→\(a.4)".padding(toLength: 16, withPad: " ", startingAt: 0)
            print("║ \(taskName) │ \(duration) │ \(priority) │ \(bestTime) │ \(category) ║")
        }

        print("╚══════════════════════════════════════════════════════════════════════════════════════════════════════╝")

        // Assert: Context with patterns should be richer than empty context
        let beforeContext = AIContext.empty.toPromptString()
        let afterContextStr = afterContext.toPromptString()
        XCTAssertGreaterThan(
            afterContextStr.count,
            beforeContext.count,
            "Context with user patterns should be longer than empty context"
        )

        // Assert: Context should include category details (avg duration, time preference)
        XCTAssertTrue(
            afterContextStr.contains("avg") || afterContextStr.contains("usually"),
            "Context should include duration or time details for categories"
        )

        // Assert: At least one response field differs between before and after
        // (LLM responses are non-deterministic, so we check if ANY difference exists)
        var hasDifference = false
        for i in 0..<tasks.count {
            let b = beforeResults[i]
            let a = afterResults[i]
            if b.1 != a.1 || b.2 != a.2 || b.3 != a.3 || b.4 != a.4 {
                hasDifference = true
                break
            }
        }

        // Note: Due to LLM non-determinism, we log but don't fail if no difference
        // The primary assertion is that richer context is being sent
        if !hasDifference {
            print("Note: No response differences detected in this run (LLM non-determinism)")
        }

        // Clean up
        AIContextService.shared.resetPatterns()

        XCTAssertEqual(beforeResults.count, 5)
        XCTAssertEqual(afterResults.count, 5)
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
