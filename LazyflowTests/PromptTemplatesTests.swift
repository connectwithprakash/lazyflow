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

        XCTAssertGreaterThanOrEqual(result.estimatedMinutes, 5, "Should clamp to minimum 5 minutes")
    }

    func testParseDurationResponse_BelowMinimumRange() {
        // Values 2-4 should be clamped to 5 (prompt specifies 5-480)
        let response = """
        {"estimated_minutes": 3, "confidence": "medium", "reasoning": "Quick task."}
        """
        let result = PromptTemplates.parseDurationResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 5, "Should clamp values below 5 to minimum 5")
    }

    func testParseDurationResponse_DecimalValue() {
        // Model might return decimal - should round to Int
        let response = """
        {"estimated_minutes": 45.5, "confidence": "high", "reasoning": "Estimate with decimal."}
        """
        let result = PromptTemplates.parseDurationResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 46, "Should round decimal to nearest Int")
    }

    func testParseDurationResponse_DecimalValueRoundDown() {
        let response = """
        {"estimated_minutes": 45.4, "confidence": "high", "reasoning": "Estimate with decimal."}
        """
        let result = PromptTemplates.parseDurationResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 45, "Should round decimal down when < .5")
    }

    func testParseFullAnalysisResponse_BelowMinimumRange() {
        let response = """
        {
            "estimated_minutes": 2,
            "suggested_priority": "low",
            "best_time": "anytime",
            "category": "personal",
            "subtasks": [],
            "tips": ""
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 5, "Should clamp values below 5 to minimum 5")
    }

    func testParseFullAnalysisResponse_DecimalValue() {
        let response = """
        {
            "estimated_minutes": 90.7,
            "suggested_priority": "medium",
            "best_time": "morning",
            "category": "work",
            "subtasks": [],
            "tips": ""
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertEqual(result.estimatedMinutes, 91, "Should round decimal to nearest Int")
    }

    // MARK: - Proposed New Category Tests

    func testBuildFullAnalysisPrompt_IncludesProposeCategoryInstruction() {
        let task = Task(title: "Test")
        let prompt = PromptTemplates.buildFullAnalysisPrompt(task: task, learningContext: "", customCategories: [])

        XCTAssertTrue(prompt.contains("proposed_new_category") || prompt.contains("propose") || prompt.contains("new category"),
                      "Should include instruction about proposing new categories")
    }

    func testParseFullAnalysisResponse_WithProposedNewCategory() {
        let response = """
        {
            "estimated_minutes": 45,
            "suggested_priority": "medium",
            "best_time": "afternoon",
            "category": "uncategorized",
            "proposed_new_category": {
                "name": "Volunteering",
                "color_hex": "#4CAF50",
                "icon_name": "heart.fill"
            },
            "subtasks": [],
            "tips": "Great cause!"
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertNotNil(result.proposedNewCategory, "Should parse proposed new category")
        XCTAssertEqual(result.proposedNewCategory?.name, "Volunteering")
        XCTAssertEqual(result.proposedNewCategory?.colorHex, "#4CAF50")
        XCTAssertEqual(result.proposedNewCategory?.iconName, "heart.fill")
    }

    func testParseFullAnalysisResponse_WithNullProposedCategory() {
        let response = """
        {
            "estimated_minutes": 30,
            "suggested_priority": "low",
            "best_time": "anytime",
            "category": "personal",
            "proposed_new_category": null,
            "subtasks": [],
            "tips": ""
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertNil(result.proposedNewCategory, "Should handle null proposed category")
    }

    func testParseFullAnalysisResponse_WithoutProposedCategoryField() {
        let response = """
        {
            "estimated_minutes": 30,
            "suggested_priority": "low",
            "best_time": "anytime",
            "category": "work",
            "subtasks": [],
            "tips": ""
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertNil(result.proposedNewCategory, "Should handle missing proposed category field")
    }

    func testParseFullAnalysisResponse_ProposedCategoryWithMissingFields() {
        let response = """
        {
            "estimated_minutes": 30,
            "suggested_priority": "medium",
            "best_time": "morning",
            "category": "uncategorized",
            "proposed_new_category": {
                "name": "Hobbies"
            },
            "subtasks": [],
            "tips": ""
        }
        """
        let result = PromptTemplates.parseFullAnalysisResponse(response)

        XCTAssertNotNil(result.proposedNewCategory, "Should parse partial proposed category")
        XCTAssertEqual(result.proposedNewCategory?.name, "Hobbies")
        // Should have default values for missing fields
        XCTAssertNotNil(result.proposedNewCategory?.colorHex, "Should have default color")
        XCTAssertNotNil(result.proposedNewCategory?.iconName, "Should have default icon")
    }

    // MARK: - Morning Briefing System Prompt Tests

    func testMorningBriefingSystemPrompt_ContainsRoleDefinition() {
        let systemPrompt = PromptTemplates.morningBriefingSystemPrompt
        XCTAssertTrue(systemPrompt.contains("productivity"), "Should define productivity role")
        XCTAssertTrue(systemPrompt.contains("assistant"), "Should define assistant role")
    }

    func testMorningBriefingSystemPrompt_ContainsOutputConstraints() {
        let systemPrompt = PromptTemplates.morningBriefingSystemPrompt
        XCTAssertTrue(systemPrompt.contains("JSON"), "Should specify JSON output format")
    }

    func testMorningBriefingSystemPrompt_ContainsToneGuidelines() {
        let systemPrompt = PromptTemplates.morningBriefingSystemPrompt
        XCTAssertTrue(systemPrompt.contains("warm") || systemPrompt.contains("energizing") || systemPrompt.contains("encouraging"),
                      "Should include tone guidelines")
    }

    // MARK: - Daily Summary Prompt Tests

    func testBuildDailySummaryPrompt_IncludesStats() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 5,
            totalPlanned: 8,
            topCategory: "Work",
            timeWorked: "3h 20m",
            currentStreak: 7,
            taskList: "- Task 1\n- Task 2",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("5"), "Should include completed count")
        XCTAssertTrue(prompt.contains("8"), "Should include planned count")
        XCTAssertTrue(prompt.contains("Work"), "Should include top category")
        XCTAssertTrue(prompt.contains("3h 20m"), "Should include time worked")
        XCTAssertTrue(prompt.contains("7 days"), "Should include streak")
    }

    func testBuildDailySummaryPrompt_IncludesTaskList() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 2,
            totalPlanned: 3,
            topCategory: nil,
            timeWorked: "1h",
            currentStreak: 1,
            taskList: "- Buy groceries\n- Call mom",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("Buy groceries"), "Should include task list items")
        XCTAssertTrue(prompt.contains("Call mom"), "Should include task list items")
    }

    func testBuildDailySummaryPrompt_HandlesEmptyTaskList() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 0,
            totalPlanned: 0,
            topCategory: nil,
            timeWorked: "0m",
            currentStreak: 0,
            taskList: "",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("No tasks completed"), "Should show fallback for empty task list")
    }

    func testBuildDailySummaryPrompt_IncludesLearningContext() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 3,
            totalPlanned: 5,
            topCategory: "Personal",
            timeWorked: "2h",
            currentStreak: 3,
            taskList: "- Task 1",
            learningContext: "User prefers brief summaries"
        )

        XCTAssertTrue(prompt.contains("User prefers brief summaries"), "Should include learning context")
        XCTAssertTrue(prompt.contains("User Learning Context"), "Should have learning context header")
    }

    func testBuildDailySummaryPrompt_HasJSONFormat() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 1,
            totalPlanned: 1,
            topCategory: nil,
            timeWorked: "30m",
            currentStreak: 1,
            taskList: "",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("\"summary\""), "Should specify summary field")
        XCTAssertTrue(prompt.contains("\"encouragement\""), "Should specify encouragement field")
    }

    // MARK: - Daily Summary Response Parsing Tests

    func testParseDailySummaryResponse_ValidJSON() {
        let response = """
        {"summary": "Great day today!", "encouragement": "Keep it up!"}
        """
        let result = PromptTemplates.parseDailySummaryResponse(response)

        XCTAssertEqual(result.summary, "Great day today!")
        XCTAssertEqual(result.encouragement, "Keep it up!")
    }

    func testParseDailySummaryResponse_JSONWithExtraText() {
        let response = """
        Here's your summary:
        {"summary": "You completed 5 tasks.", "encouragement": "Amazing streak!"}
        """
        let result = PromptTemplates.parseDailySummaryResponse(response)

        XCTAssertEqual(result.summary, "You completed 5 tasks.")
        XCTAssertEqual(result.encouragement, "Amazing streak!")
    }

    func testParseDailySummaryResponse_InvalidJSON_ReturnsNil() {
        let response = "Unable to generate summary."
        let result = PromptTemplates.parseDailySummaryResponse(response)

        XCTAssertNil(result.summary, "Should return nil for invalid JSON")
        XCTAssertNil(result.encouragement, "Should return nil for invalid JSON")
    }

    func testParseDailySummaryResponse_PartialJSON() {
        let response = """
        {"summary": "Partial response only."}
        """
        let result = PromptTemplates.parseDailySummaryResponse(response)

        XCTAssertEqual(result.summary, "Partial response only.")
        XCTAssertNil(result.encouragement, "Should handle missing encouragement")
    }

    // MARK: - Morning Briefing Prompt Tests

    func testBuildMorningBriefingPrompt_IncludesYesterdayStats() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 4,
            yesterdayPlanned: 6,
            yesterdayTopCategory: "Work",
            todayTaskCount: 5,
            todayHighPriority: 2,
            todayOverdue: 1,
            todayTimeEstimate: "4h 30m",
            weeklyTasksCompleted: 15,
            weeklyCompletionRate: "75%",
            currentStreak: 5,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("4"), "Should include yesterday completed")
        XCTAssertTrue(prompt.contains("6"), "Should include yesterday planned")
        XCTAssertTrue(prompt.contains("Work"), "Should include yesterday top category")
    }

    func testBuildMorningBriefingPrompt_IncludesTodayPlan() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 3,
            yesterdayPlanned: 5,
            yesterdayTopCategory: nil,
            todayTaskCount: 8,
            todayHighPriority: 3,
            todayOverdue: 2,
            todayTimeEstimate: "5h",
            weeklyTasksCompleted: 10,
            weeklyCompletionRate: "60%",
            currentStreak: 2,
            todayTaskList: "- [HIGH] Meeting prep",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("8"), "Should include today task count")
        XCTAssertTrue(prompt.contains("High priority: 3"), "Should include high priority count")
        XCTAssertTrue(prompt.contains("Overdue: 2"), "Should include overdue count")
        XCTAssertTrue(prompt.contains("Meeting prep"), "Should include task list")
    }

    func testBuildMorningBriefingPrompt_IncludesScheduleContext() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 5,
            yesterdayPlanned: 5,
            yesterdayTopCategory: "Personal",
            todayTaskCount: 4,
            todayHighPriority: 1,
            todayOverdue: 0,
            todayTimeEstimate: "2h",
            weeklyTasksCompleted: 20,
            weeklyCompletionRate: "80%",
            currentStreak: 10,
            todayTaskList: "",
            scheduleContext: "- Meetings: 2 (3h total)\n- Largest free block: 2h",
            learningContext: "",
            hasCalendarData: true
        )

        XCTAssertTrue(prompt.contains("Today's Calendar"), "Should include calendar section")
        XCTAssertTrue(prompt.contains("Meetings: 2"), "Should include meeting count")
        XCTAssertTrue(prompt.contains("Largest free block"), "Should include free block info")
    }

    func testBuildMorningBriefingPrompt_IncludesWeeklyProgress() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 3,
            yesterdayPlanned: 4,
            yesterdayTopCategory: nil,
            todayTaskCount: 5,
            todayHighPriority: 2,
            todayOverdue: 0,
            todayTimeEstimate: "3h",
            weeklyTasksCompleted: 25,
            weeklyCompletionRate: "85%",
            currentStreak: 7,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("25"), "Should include weekly tasks completed")
        XCTAssertTrue(prompt.contains("85%"), "Should include completion rate")
        XCTAssertTrue(prompt.contains("7 days"), "Should include current streak")
    }

    func testBuildMorningBriefingPrompt_HasJSONFormat() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTaskCount: 0,
            todayHighPriority: 0,
            todayOverdue: 0,
            todayTimeEstimate: "0m",
            weeklyTasksCompleted: 0,
            weeklyCompletionRate: "0%",
            currentStreak: 0,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("\"summary\""), "Should specify summary field")
        XCTAssertTrue(prompt.contains("\"todayFocus\""), "Should specify todayFocus field")
        XCTAssertTrue(prompt.contains("\"motivation\""), "Should specify motivation field")
    }

    // MARK: - Morning Briefing Response Parsing Tests

    func testParseMorningBriefingResponse_ValidJSON() {
        let response = """
        {"summary": "Good morning!", "todayFocus": "Focus on high-priority tasks.", "motivation": "You're doing great!"}
        """
        let result = PromptTemplates.parseMorningBriefingResponse(response)

        XCTAssertEqual(result.summary, "Good morning!")
        XCTAssertEqual(result.todayFocus, "Focus on high-priority tasks.")
        XCTAssertEqual(result.motivation, "You're doing great!")
    }

    func testParseMorningBriefingResponse_JSONWithExtraText() {
        let response = """
        Here's your briefing:
        {"summary": "Yesterday was productive!", "todayFocus": "Clear your overdue items.", "motivation": "Keep the streak going!"}
        """
        let result = PromptTemplates.parseMorningBriefingResponse(response)

        XCTAssertEqual(result.summary, "Yesterday was productive!")
        XCTAssertEqual(result.todayFocus, "Clear your overdue items.")
        XCTAssertEqual(result.motivation, "Keep the streak going!")
    }

    func testParseMorningBriefingResponse_InvalidJSON_ReturnsNil() {
        let response = "Unable to generate briefing."
        let result = PromptTemplates.parseMorningBriefingResponse(response)

        XCTAssertNil(result.summary, "Should return nil for invalid JSON")
        XCTAssertNil(result.todayFocus, "Should return nil for invalid JSON")
        XCTAssertNil(result.motivation, "Should return nil for invalid JSON")
    }

    func testParseMorningBriefingResponse_PartialJSON() {
        let response = """
        {"summary": "Good morning!", "todayFocus": "Focus today."}
        """
        let result = PromptTemplates.parseMorningBriefingResponse(response)

        XCTAssertEqual(result.summary, "Good morning!")
        XCTAssertEqual(result.todayFocus, "Focus today.")
        XCTAssertNil(result.motivation, "Should handle missing motivation")
    }

    // MARK: - Edge Case Handling Tests

    func testBuildDailySummaryPrompt_ZeroTasksCompleted_IncludesWarning() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 0,
            totalPlanned: 5,
            topCategory: nil,
            timeWorked: "0m",
            currentStreak: 0,
            taskList: "",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("Zero tasks completed"), "Should include zero-task scenario guidance")
        XCTAssertTrue(prompt.contains("do NOT") || prompt.contains("Do NOT"), "Should include DO NOT instruction")
        XCTAssertTrue(prompt.contains("positive") || prompt.contains("great"), "Should warn against false positive words")
    }

    func testBuildDailySummaryPrompt_AllTasksCompleted_CelebratesAchievement() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 5,
            totalPlanned: 5,
            topCategory: "Work",
            timeWorked: "3h",
            currentStreak: 7,
            taskList: "- Task 1\n- Task 2",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("All tasks completed") || prompt.contains("celebration") || prompt.contains("achievement"),
                      "Should include celebration guidance for full completion")
    }

    func testBuildDailySummaryPrompt_FirstDay_IncludesWelcome() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 1,
            totalPlanned: 3,
            topCategory: nil,
            timeWorked: "30m",
            currentStreak: 1,
            taskList: "- First task",
            learningContext: "",
            isFirstDay: true
        )

        XCTAssertTrue(prompt.contains("First day") || prompt.contains("first day"), "Should include first-day guidance")
        XCTAssertTrue(prompt.contains("Welcome") || prompt.contains("welcome") || prompt.contains("yesterday"),
                      "Should mention welcome or warn about yesterday references")
    }

    func testBuildDailySummaryPrompt_CriticalRules_AlwaysPresent() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 3,
            totalPlanned: 5,
            topCategory: nil,
            timeWorked: "2h",
            currentStreak: 3,
            taskList: "",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("CRITICAL RULES"), "Should include critical rules section")
        XCTAssertTrue(prompt.contains("MUST match"), "Should require data matching")
    }

    func testBuildMorningBriefingPrompt_ZeroYesterdayCompletions_IncludesWarning() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 0,
            yesterdayPlanned: 5,
            yesterdayTopCategory: nil,
            todayTaskCount: 3,
            todayHighPriority: 1,
            todayOverdue: 0,
            todayTimeEstimate: "2h",
            weeklyTasksCompleted: 5,
            weeklyCompletionRate: "50%",
            currentStreak: 0,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("zero completions") || prompt.contains("Zero completions"),
                      "Should include zero-completion scenario guidance")
        XCTAssertTrue(prompt.contains("do NOT") || prompt.contains("Do NOT"),
                      "Should include DO NOT instruction for yesterday")
    }

    func testBuildMorningBriefingPrompt_NoTasksPlannedYesterday_SkipsYesterday() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTaskCount: 5,
            todayHighPriority: 2,
            todayOverdue: 0,
            todayTimeEstimate: "3h",
            weeklyTasksCompleted: 10,
            weeklyCompletionRate: "70%",
            currentStreak: 5,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("No tasks were planned yesterday") || prompt.contains("Skip mentioning yesterday"),
                      "Should advise skipping yesterday when nothing was planned")
    }

    func testBuildMorningBriefingPrompt_FirstDay_NoYesterdayReference() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 0,
            yesterdayPlanned: 0,
            yesterdayTopCategory: nil,
            todayTaskCount: 3,
            todayHighPriority: 1,
            todayOverdue: 0,
            todayTimeEstimate: "2h",
            weeklyTasksCompleted: 0,
            weeklyCompletionRate: "0%",
            currentStreak: 0,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false,
            isFirstDay: true
        )

        XCTAssertTrue(prompt.contains("First day") || prompt.contains("first day"),
                      "Should include first-day guidance")
        XCTAssertTrue(prompt.contains("Welcome") || prompt.contains("welcome") || prompt.contains("Don't reference"),
                      "Should welcome user or warn about yesterday references")
    }

    func testBuildMorningBriefingPrompt_BrokenStreak_EmpatheticMessage() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 0,
            yesterdayPlanned: 3,
            yesterdayTopCategory: nil,
            todayTaskCount: 5,
            todayHighPriority: 2,
            todayOverdue: 0,
            todayTimeEstimate: "3h",
            weeklyTasksCompleted: 10,
            weeklyCompletionRate: "60%",
            currentStreak: 0,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false,
            streakJustBroken: true,
            previousStreak: 14
        )

        XCTAssertTrue(prompt.contains("Streak was recently broken") || prompt.contains("broken"),
                      "Should include broken streak guidance")
        XCTAssertTrue(prompt.contains("14"), "Should mention previous streak length")
        XCTAssertTrue(prompt.contains("empathetic") || prompt.contains("Empathetic") || prompt.contains("guilt"),
                      "Should advise empathetic messaging")
    }

    func testBuildMorningBriefingPrompt_OverdueTasks_PrioritizationGuidance() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 3,
            yesterdayPlanned: 5,
            yesterdayTopCategory: "Work",
            todayTaskCount: 8,
            todayHighPriority: 2,
            todayOverdue: 4,
            todayTimeEstimate: "5h",
            weeklyTasksCompleted: 15,
            weeklyCompletionRate: "65%",
            currentStreak: 3,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("4 overdue") || prompt.contains("overdue tasks"),
                      "Should include overdue task guidance")
        XCTAssertTrue(prompt.contains("prioritiz") || prompt.contains("Prioritiz"),
                      "Should suggest prioritization")
    }

    func testBuildMorningBriefingPrompt_CriticalRules_AlwaysPresent() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 5,
            yesterdayPlanned: 5,
            yesterdayTopCategory: "Personal",
            todayTaskCount: 3,
            todayHighPriority: 1,
            todayOverdue: 0,
            todayTimeEstimate: "2h",
            weeklyTasksCompleted: 20,
            weeklyCompletionRate: "85%",
            currentStreak: 10,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("CRITICAL RULES"), "Should include critical rules section")
        XCTAssertTrue(prompt.contains("MUST accurately reflect"), "Should require data accuracy")
    }

    // MARK: - Personalization Tests (#183)

    func testBuildDailySummaryPrompt_IncludesTimeOfDay() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 5,
            totalPlanned: 8,
            topCategory: "Work",
            timeWorked: "3h 30m",
            currentStreak: 3,
            taskList: "- Complete report (Work)\n- Review PR (Work)",
            learningContext: "",
            timeOfDay: "evening"
        )

        XCTAssertTrue(prompt.contains("Time of day: evening"), "Should include interpolated time of day")
    }

    func testBuildDailySummaryPrompt_PersonalizationGuidance() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 3,
            totalPlanned: 5,
            topCategory: "Work",
            timeWorked: "2h",
            currentStreak: 2,
            taskList: "- Fix login bug (Work)\n- Write tests (Development)",
            learningContext: "",
            timeOfDay: "afternoon"
        )

        XCTAssertTrue(prompt.contains("specific task"), "Should instruct to reference specific tasks by name")
    }

    func testBuildMorningBriefingPrompt_IncludesTimeOfDay() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 4,
            yesterdayPlanned: 6,
            yesterdayTopCategory: "Work",
            todayTaskCount: 5,
            todayHighPriority: 2,
            todayOverdue: 0,
            todayTimeEstimate: "4h",
            weeklyTasksCompleted: 15,
            weeklyCompletionRate: "75%",
            currentStreak: 5,
            todayTaskList: "- [HIGH] Sprint planning (Work)\n- Review design (Design)",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false,
            timeOfDay: "morning"
        )

        XCTAssertTrue(prompt.contains("Time of day: morning"), "Should include interpolated time of day")
    }

    func testBuildMorningBriefingPrompt_PersonalizationGuidance() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 3,
            yesterdayPlanned: 5,
            yesterdayTopCategory: "Personal",
            todayTaskCount: 4,
            todayHighPriority: 1,
            todayOverdue: 0,
            todayTimeEstimate: "3h",
            weeklyTasksCompleted: 10,
            weeklyCompletionRate: "65%",
            currentStreak: 3,
            todayTaskList: "- [HIGH] Finish proposal (Work)",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false,
            timeOfDay: "afternoon"
        )

        XCTAssertTrue(prompt.contains("specific task"), "Should instruct to reference specific tasks by name")
        XCTAssertTrue(prompt.contains("tone"), "Should include tone guidance for time of day")
    }

    func testBuildDailySummaryPrompt_TimeOfDayDefaultsToEvening() {
        let prompt = PromptTemplates.buildDailySummaryPrompt(
            tasksCompleted: 2,
            totalPlanned: 3,
            topCategory: nil,
            timeWorked: "1h",
            currentStreak: 1,
            taskList: "",
            learningContext: ""
        )

        XCTAssertTrue(prompt.contains("Time of day: evening"), "Should default to evening when no timeOfDay provided")
    }

    func testBuildMorningBriefingPrompt_TimeOfDayDefaultsToMorning() {
        let prompt = PromptTemplates.buildMorningBriefingPrompt(
            yesterdayCompleted: 2,
            yesterdayPlanned: 3,
            yesterdayTopCategory: nil,
            todayTaskCount: 4,
            todayHighPriority: 1,
            todayOverdue: 0,
            todayTimeEstimate: "2h",
            weeklyTasksCompleted: 8,
            weeklyCompletionRate: "60%",
            currentStreak: 1,
            todayTaskList: "",
            scheduleContext: nil,
            learningContext: "",
            hasCalendarData: false
        )

        XCTAssertTrue(prompt.contains("Time of day: morning"), "Should default to morning when no timeOfDay provided")
    }
}
