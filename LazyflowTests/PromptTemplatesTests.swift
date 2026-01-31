import XCTest
@testable import Lazyflow

final class PromptTemplatesTests: XCTestCase {

    // MARK: - System Prompt Tests

    func testTaskAnalysisSystemPrompt_ContainsRoleDefinition() {
        let systemPrompt = PromptTemplates.taskAnalysisSystemPrompt
        XCTAssertTrue(systemPrompt.contains("productivity"), "Should define productivity role")
        XCTAssertTrue(systemPrompt.contains("coach") || systemPrompt.contains("assistant"), "Should define assistant/coach role")
    }

    func testTaskAnalysisSystemPrompt_ContainsOutputConstraints() {
        let systemPrompt = PromptTemplates.taskAnalysisSystemPrompt
        XCTAssertTrue(systemPrompt.contains("JSON"), "Should specify JSON output format")
        XCTAssertTrue(systemPrompt.contains("concise") || systemPrompt.contains("brief"), "Should encourage brevity")
    }

    func testTaskAnalysisSystemPrompt_ContainsSafetyGuidelines() {
        let systemPrompt = PromptTemplates.taskAnalysisSystemPrompt
        XCTAssertTrue(systemPrompt.contains("DO NOT") || systemPrompt.contains("NEVER"), "Should include safety guidelines")
    }

    // MARK: - Duration Estimation Prompt Tests

    func testBuildDurationPrompt_IncludesTitle() {
        let prompt = PromptTemplates.buildDurationEstimationPrompt(title: "Buy groceries", notes: nil)
        XCTAssertTrue(prompt.contains("Buy groceries"), "Should include task title")
    }

    func testBuildDurationPrompt_IncludesNotes() {
        let prompt = PromptTemplates.buildDurationEstimationPrompt(title: "Test", notes: "Get milk and eggs")
        XCTAssertTrue(prompt.contains("Get milk and eggs"), "Should include notes when provided")
    }

    func testBuildDurationPrompt_HasExample() {
        let prompt = PromptTemplates.buildDurationEstimationPrompt(title: "Test", notes: nil)
        XCTAssertTrue(prompt.contains("Example"), "Should include few-shot example")
    }

    func testBuildDurationPrompt_HasOutputConstraint() {
        let prompt = PromptTemplates.buildDurationEstimationPrompt(title: "Test", notes: nil)
        XCTAssertTrue(prompt.contains("one sentence") || prompt.contains("brief"), "Should constrain output length")
    }

    func testBuildDurationPrompt_HasJSONFormat() {
        let prompt = PromptTemplates.buildDurationEstimationPrompt(title: "Test", notes: nil)
        XCTAssertTrue(prompt.contains("estimated_minutes"), "Should specify JSON field")
        XCTAssertTrue(prompt.contains("confidence"), "Should specify confidence field")
    }

    // MARK: - Priority Suggestion Prompt Tests

    func testBuildPriorityPrompt_IncludesTitle() {
        let prompt = PromptTemplates.buildPrioritySuggestionPrompt(title: "Urgent meeting prep", notes: nil, dueDate: nil)
        XCTAssertTrue(prompt.contains("Urgent meeting prep"), "Should include task title")
    }

    func testBuildPriorityPrompt_IncludesDueDate() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let prompt = PromptTemplates.buildPrioritySuggestionPrompt(title: "Test", notes: nil, dueDate: tomorrow)
        XCTAssertTrue(prompt.contains("Due:"), "Should include due date when provided")
    }

    func testBuildPriorityPrompt_HasPriorityOptions() {
        let prompt = PromptTemplates.buildPrioritySuggestionPrompt(title: "Test", notes: nil, dueDate: nil)
        XCTAssertTrue(prompt.contains("none") && prompt.contains("low") && prompt.contains("medium") && prompt.contains("high") && prompt.contains("urgent"), "Should list all priority options")
    }

    // MARK: - Full Analysis Prompt Tests

    func testBuildFullAnalysisPrompt_IncludesAllFields() {
        let task = Task(title: "Write report", notes: "Quarterly summary", priority: .high)
        let prompt = PromptTemplates.buildFullAnalysisPrompt(task: task, learningContext: "", customCategories: [])

        XCTAssertTrue(prompt.contains("Write report"), "Should include title")
        XCTAssertTrue(prompt.contains("Quarterly summary"), "Should include notes")
        XCTAssertTrue(prompt.contains("High") || prompt.contains("high"), "Should include priority")
    }

    func testBuildFullAnalysisPrompt_IncludesLearningContext() {
        let task = Task(title: "Test")
        let learningContext = "User prefers morning for work tasks"
        let prompt = PromptTemplates.buildFullAnalysisPrompt(task: task, learningContext: learningContext, customCategories: [])

        XCTAssertTrue(prompt.contains("User prefers morning"), "Should include learning context")
    }

    func testBuildFullAnalysisPrompt_IncludesCustomCategories() {
        let task = Task(title: "Test")
        let customCategories = ["Research", "Meetings"]
        let prompt = PromptTemplates.buildFullAnalysisPrompt(task: task, learningContext: "", customCategories: customCategories)

        XCTAssertTrue(prompt.contains("Research"), "Should include custom categories")
        XCTAssertTrue(prompt.contains("Meetings"), "Should include custom categories")
    }

    func testBuildFullAnalysisPrompt_HasStructuredOutput() {
        let task = Task(title: "Test")
        let prompt = PromptTemplates.buildFullAnalysisPrompt(task: task, learningContext: "", customCategories: [])

        XCTAssertTrue(prompt.contains("estimated_minutes"), "Should have duration field")
        XCTAssertTrue(prompt.contains("suggested_priority"), "Should have priority field")
        XCTAssertTrue(prompt.contains("category"), "Should have category field")
        XCTAssertTrue(prompt.contains("subtasks"), "Should have subtasks field")
    }

    func testBuildFullAnalysisPrompt_ConstrainsSubtasks() {
        let task = Task(title: "Test")
        let prompt = PromptTemplates.buildFullAnalysisPrompt(task: task, learningContext: "", customCategories: [])

        XCTAssertTrue(prompt.contains("3") || prompt.contains("three"), "Should limit subtasks count")
    }

    // MARK: - Response Parsing Tests

    func testParseDurationResponse_ValidJSON() {
        let response = """
        {"estimated_minutes": 45, "confidence": "high", "reasoning": "Typical grocery trip."}
        """
        let result = PromptTemplates.parseDurationResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 45)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.reasoning, "Typical grocery trip.")
    }

    func testParseDurationResponse_JSONWithExtraText() {
        let response = """
        Here's my analysis:
        {"estimated_minutes": 30, "confidence": "medium", "reasoning": "Standard task duration."}
        Hope this helps!
        """
        let result = PromptTemplates.parseDurationResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 30)
        XCTAssertEqual(result.confidence, .medium)
    }

    func testParseDurationResponse_InvalidJSON_ReturnsDefault() {
        let response = "I cannot estimate this task."
        let result = PromptTemplates.parseDurationResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 30, "Should return default 30 minutes")
        XCTAssertEqual(result.confidence, .low, "Should return low confidence for failed parse")
    }

    func testParsePriorityResponse_ValidJSON() {
        let response = """
        {"priority": "high", "reasoning": "Due soon and important."}
        """
        let result = PromptTemplates.parsePriorityResponse(response)

        XCTAssertEqual(result.priority, .high)
        XCTAssertEqual(result.reasoning, "Due soon and important.")
    }

    func testParsePriorityResponse_UrgentPriority() {
        let response = """
        {"priority": "urgent", "reasoning": "Deadline is today."}
        """
        let result = PromptTemplates.parsePriorityResponse(response)

        XCTAssertEqual(result.priority, .urgent)
    }

    func testParseFullAnalysisResponse_ValidJSON() {
        let response = """
        {
            "estimated_minutes": 60,
            "suggested_priority": "high",
            "best_time": "morning",
            "category": "work",
            "refined_title": "Complete quarterly report",
            "suggested_description": "Review data and write summary",
            "subtasks": ["Gather data", "Write draft", "Review"],
            "tips": "Break into chunks."
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 60)
        XCTAssertEqual(result.suggestedPriority, .high)
        XCTAssertEqual(result.bestTime, .morning)
        XCTAssertEqual(result.suggestedCategory, .work)
        XCTAssertEqual(result.refinedTitle, "Complete quarterly report")
        XCTAssertEqual(result.subtasks.count, 3)
    }

    func testParseFullAnalysisResponse_CustomCategory() {
        let response = """
        {
            "estimated_minutes": 30,
            "suggested_priority": "medium",
            "best_time": "afternoon",
            "category": "research",
            "subtasks": [],
            "tips": "Focus deeply."
        }
        """
        // Note: Custom category lookup would need CategoryService mock
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        // When category doesn't match system categories, it stays as string for later lookup
        XCTAssertEqual(result.estimatedMinutes, 30)
    }

    func testParseFullAnalysisResponse_NullFields() {
        let response = """
        {
            "estimated_minutes": 15,
            "suggested_priority": "low",
            "best_time": "anytime",
            "category": "personal",
            "refined_title": null,
            "suggested_description": null,
            "subtasks": [],
            "tips": ""
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertNil(result.refinedTitle, "Should handle null refined_title")
        XCTAssertNil(result.suggestedDescription, "Should handle null description")
    }

    // MARK: - Edge Cases

    func testBuildDurationPrompt_EmptyTitle() {
        let prompt = PromptTemplates.buildDurationEstimationPrompt(title: "", notes: nil)
        XCTAssertTrue(prompt.contains("Task:"), "Should still have task label")
    }

    func testBuildDurationPrompt_VeryLongTitle() {
        let longTitle = String(repeating: "Test ", count: 100)
        let prompt = PromptTemplates.buildDurationEstimationPrompt(title: longTitle, notes: nil)
        XCTAssertTrue(prompt.contains(longTitle), "Should handle long titles")
    }

    func testParseDurationResponse_ExtremeValues() {
        let response = """
        {"estimated_minutes": 10000, "confidence": "high", "reasoning": "Very long task."}
        """
        let result = PromptTemplates.parseDurationResponse(response)

        // Should cap at reasonable maximum (8 hours = 480 minutes)
        XCTAssertLessThanOrEqual(result.estimatedMinutes, 480, "Should cap extreme duration values")
    }

    func testParseDurationResponse_NegativeMinutes() {
        let response = """
        {"estimated_minutes": -30, "confidence": "low", "reasoning": "Invalid."}
        """
        let result = PromptTemplates.parseDurationResponse(response)

        XCTAssertGreaterThan(result.estimatedMinutes, 0, "Should not allow negative duration")
    }
}
