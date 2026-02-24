import XCTest
@testable import Lazyflow

final class NoteParsingServiceTests: XCTestCase {

    // MARK: - Deterministic Parsing Tests

    @MainActor
    func testDeterministicParse_SingleLine() {
        let service = NoteParsingService.shared
        let segments = service.deterministicParse("Buy groceries")

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.text, "Buy groceries")
        XCTAssertNil(segments.first?.parsedDate)
    }

    @MainActor
    func testDeterministicParse_MultipleLines() {
        let text = """
        Buy groceries
        Call dentist
        Finish report
        """
        let service = NoteParsingService.shared
        let segments = service.deterministicParse(text)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].text, "Buy groceries")
        XCTAssertEqual(segments[1].text, "Call dentist")
        XCTAssertEqual(segments[2].text, "Finish report")
    }

    @MainActor
    func testDeterministicParse_SentenceSplitting() {
        let text = "Buy groceries. Call the dentist. Finish the report."
        let service = NoteParsingService.shared
        let segments = service.deterministicParse(text)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].text, "Buy groceries")
        XCTAssertEqual(segments[1].text, "Call the dentist")
        XCTAssertEqual(segments[2].text, "Finish the report")
    }

    @MainActor
    func testDeterministicParse_ConjunctionSplitting() {
        let text = "Buy groceries, and call the dentist"
        let service = NoteParsingService.shared
        let segments = service.deterministicParse(text)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "Buy groceries")
        XCTAssertEqual(segments[1].text, "call the dentist")
    }

    @MainActor
    func testDeterministicParse_DateExtraction() {
        let text = "Buy groceries tomorrow"
        let service = NoteParsingService.shared
        let segments = service.deterministicParse(text)

        XCTAssertEqual(segments.count, 1)
        XCTAssertNotNil(segments.first?.parsedDate, "Should parse 'tomorrow' as a date")
    }

    @MainActor
    func testDeterministicParse_EmptyInput() {
        let service = NoteParsingService.shared
        let segments = service.deterministicParse("")

        XCTAssertTrue(segments.isEmpty)
    }

    @MainActor
    func testDeterministicParse_WhitespaceOnly() {
        let service = NoteParsingService.shared
        let segments = service.deterministicParse("   \n  \n   ")

        XCTAssertTrue(segments.isEmpty)
    }

    @MainActor
    func testDeterministicParse_SingleCharacterFiltered() {
        let text = "a\nBuy groceries\nb"
        let service = NoteParsingService.shared
        let segments = service.deterministicParse(text)

        // Single-char segments should be filtered out
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.text, "Buy groceries")
    }

    // MARK: - JSON Array Extraction Tests

    func testExtractJSONArray_ValidArray() {
        let response = """
        [{"title": "Buy groceries", "priority": "low"}, {"title": "Call dentist", "priority": "medium"}]
        """
        let data = PromptTemplates.extractJSONArray(from: response)
        XCTAssertNotNil(data)

        if let data = data,
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            XCTAssertEqual(array.count, 2)
            XCTAssertEqual(array[0]["title"] as? String, "Buy groceries")
            XCTAssertEqual(array[1]["title"] as? String, "Call dentist")
        } else {
            XCTFail("Should parse valid JSON array")
        }
    }

    func testExtractJSONArray_ArrayWithSurroundingText() {
        let response = """
        Here are the tasks I extracted:
        [{"title": "Buy groceries", "priority": "low"}]
        Hope this helps!
        """
        let data = PromptTemplates.extractJSONArray(from: response)
        XCTAssertNotNil(data, "Should extract JSON array from surrounding text")
    }

    func testExtractJSONArray_EmptyArray() {
        let response = "[]"
        let data = PromptTemplates.extractJSONArray(from: response)
        XCTAssertNotNil(data, "Should handle empty array")
    }

    func testExtractJSONArray_InvalidJSON() {
        let response = "This is not JSON at all"
        let data = PromptTemplates.extractJSONArray(from: response)
        XCTAssertNil(data, "Should return nil for non-JSON")
    }

    func testExtractJSONArray_ObjectNotArray() {
        let response = """
        {"title": "Not an array"}
        """
        let data = PromptTemplates.extractJSONArray(from: response)
        XCTAssertNil(data, "Should return nil for JSON object (not array)")
    }

    // MARK: - Note Extraction Prompt Tests

    func testBuildNoteExtractionPrompt_IncludesNoteText() {
        let prompt = PromptTemplates.buildNoteExtractionPrompt(
            noteText: "Buy groceries and call dentist",
            customCategories: [],
            listNames: [],
            learningContext: ""
        )
        XCTAssertTrue(prompt.contains("Buy groceries and call dentist"))
    }

    func testBuildNoteExtractionPrompt_IncludesCustomCategories() {
        let prompt = PromptTemplates.buildNoteExtractionPrompt(
            noteText: "Test",
            customCategories: ["Volunteering", "Side Project"],
            listNames: [],
            learningContext: ""
        )
        XCTAssertTrue(prompt.contains("Volunteering"))
        XCTAssertTrue(prompt.contains("Side Project"))
    }

    func testBuildNoteExtractionPrompt_IncludesListNames() {
        let prompt = PromptTemplates.buildNoteExtractionPrompt(
            noteText: "Test",
            customCategories: [],
            listNames: ["Work", "Personal"],
            learningContext: ""
        )
        XCTAssertTrue(prompt.contains("Work"))
        XCTAssertTrue(prompt.contains("Personal"))
    }

    func testBuildNoteExtractionPrompt_IncludesLearningContext() {
        let prompt = PromptTemplates.buildNoteExtractionPrompt(
            noteText: "Test",
            customCategories: [],
            listNames: [],
            learningContext: "User prefers high priority for work tasks"
        )
        XCTAssertTrue(prompt.contains("User prefers high priority"))
    }

    func testBuildNoteExtractionPrompt_HasJSONFormat() {
        let prompt = PromptTemplates.buildNoteExtractionPrompt(
            noteText: "Test",
            customCategories: [],
            listNames: [],
            learningContext: ""
        )
        XCTAssertTrue(prompt.contains("\"title\""))
        XCTAssertTrue(prompt.contains("\"priority\""))
        XCTAssertTrue(prompt.contains("\"category\""))
        XCTAssertTrue(prompt.contains("JSON array"))
    }

    func testNoteExtractionSystemPrompt_ContainsRole() {
        let systemPrompt = PromptTemplates.noteExtractionSystemPrompt
        XCTAssertTrue(systemPrompt.contains("task extraction"))
        XCTAssertTrue(systemPrompt.contains("actionable"))
    }

    // MARK: - Hierarchy Detection Tests

    @MainActor
    func testHierarchy_BulletListUnderHeader() {
        let text = """
        Plan birthday party
        - Send invitations
        - Order cake
        - Book venue
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent, "Plan birthday party")
        XCTAssertEqual(groups[0].children.count, 3)
        XCTAssertEqual(groups[0].children[0], "Send invitations")
        XCTAssertEqual(groups[0].children[1], "Order cake")
        XCTAssertEqual(groups[0].children[2], "Book venue")
    }

    @MainActor
    func testHierarchy_NumberedListUnderHeader() {
        let text = """
        Prepare presentation
        1. Create slides
        2. Write speaker notes
        3. Practice delivery
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent, "Prepare presentation")
        XCTAssertEqual(groups[0].children.count, 3)
        XCTAssertEqual(groups[0].children[0], "Create slides")
        XCTAssertEqual(groups[0].children[1], "Write speaker notes")
        XCTAssertEqual(groups[0].children[2], "Practice delivery")
    }

    @MainActor
    func testHierarchy_IndentedLinesUnderHeader() {
        let text = "Morning routine\n  Exercise\n  Shower\n  Breakfast"
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent, "Morning routine")
        XCTAssertEqual(groups[0].children.count, 3)
        XCTAssertEqual(groups[0].children[0], "Exercise")
    }

    @MainActor
    func testHierarchy_MarkdownCheckboxes() {
        let text = """
        Weekly review
        - [ ] Check email
        - [x] Update calendar
        - [ ] Plan next week
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent, "Weekly review")
        XCTAssertEqual(groups[0].children.count, 3)
        XCTAssertEqual(groups[0].children[0], "Check email")
        XCTAssertEqual(groups[0].children[1], "Update calendar")
        XCTAssertEqual(groups[0].children[2], "Plan next week")
    }

    @MainActor
    func testHierarchy_ColonHeader() {
        let text = """
        Groceries:
        - Milk
        - Eggs
        - Bread
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent, "Groceries")
        XCTAssertEqual(groups[0].children.count, 3)
    }

    @MainActor
    func testHierarchy_AllBulletsNoHeader_FlatTasks() {
        let text = """
        - Buy groceries
        - Call dentist
        - Finish report
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        // All bullets with no parent header = flat tasks (empty result, fall back to flat)
        XCTAssertTrue(groups.isEmpty, "All-bullet lists should return empty (fall back to flat)")
    }

    @MainActor
    func testHierarchy_SingleLine_NoHierarchy() {
        let text = "Buy groceries"
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertTrue(groups.isEmpty, "Single line should return empty (no hierarchy)")
    }

    @MainActor
    func testHierarchy_MultipleParentSubtaskGroups() {
        let text = """
        Plan birthday party
        - Send invitations
        - Order cake
        Prepare presentation
        - Create slides
        - Practice delivery
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].parent, "Plan birthday party")
        XCTAssertEqual(groups[0].children.count, 2)
        XCTAssertEqual(groups[1].parent, "Prepare presentation")
        XCTAssertEqual(groups[1].children.count, 2)
    }

    @MainActor
    func testHierarchy_MixedStandaloneAndHierarchy() {
        let text = """
        Call dentist
        Plan birthday party
        - Send invitations
        - Order cake
        Buy groceries
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].parent, "Call dentist")
        XCTAssertTrue(groups[0].children.isEmpty)
        XCTAssertEqual(groups[1].parent, "Plan birthday party")
        XCTAssertEqual(groups[1].children.count, 2)
        XCTAssertEqual(groups[2].parent, "Buy groceries")
        XCTAssertTrue(groups[2].children.isEmpty)
    }

    @MainActor
    func testHierarchy_EmptyChildLinesIgnored() {
        let text = "Plan party\n- Send invitations\n- \n- Order cake"
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].children.count, 2, "Empty bullet lines should be ignored")
    }

    @MainActor
    func testHierarchy_StarBullets() {
        let text = """
        Home repairs
        * Fix faucet
        * Paint bedroom
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent, "Home repairs")
        XCTAssertEqual(groups[0].children.count, 2)
    }

    @MainActor
    func testHierarchy_TabIndentation() {
        let text = "Morning routine\n\tExercise\n\tShower"
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent, "Morning routine")
        XCTAssertEqual(groups[0].children.count, 2)
    }

    @MainActor
    func testHierarchy_MultiplePlainLines_NoHierarchy() {
        let text = """
        Buy groceries
        Call dentist
        Finish report
        """
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertTrue(groups.isEmpty, "Multiple plain lines with no bullets should return empty")
    }

    // MARK: - Hierarchical Deterministic Parsing Tests

    @MainActor
    func testDeterministicParseHierarchical_CreatesSubtaskDrafts() {
        let text = """
        Plan birthday party
        - Send invitations
        - Order cake
        - Book venue
        """
        let service = NoteParsingService.shared
        let groups = service.deterministicParseHierarchical(text)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].parent.text, "Plan birthday party")
        XCTAssertEqual(groups[0].children.count, 3)
        XCTAssertEqual(groups[0].children[0].text, "Send invitations")
    }

    @MainActor
    func testDeterministicParseHierarchical_FlatInput_NoChildren() {
        let text = "Buy groceries, and call the dentist"
        let service = NoteParsingService.shared
        let groups = service.deterministicParseHierarchical(text)

        // Falls through to flat parsing
        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups[0].children.isEmpty)
        XCTAssertTrue(groups[1].children.isEmpty)
    }

    // MARK: - TaskDraft Subtask Tests

    func testTaskDraft_TotalSelectedCount_ParentAndSubtasks() {
        var draft = TaskDraft(
            title: "Parent",
            subtasks: [
                TaskDraft(title: "Sub 1"),
                TaskDraft(title: "Sub 2"),
                TaskDraft(title: "Sub 3")
            ]
        )
        XCTAssertEqual(draft.totalSelectedCount, 4) // 1 parent + 3 subtasks

        draft.subtasks[1].isSelected = false
        XCTAssertEqual(draft.totalSelectedCount, 3) // 1 parent + 2 subtasks
    }

    func testTaskDraft_TotalSelectedCount_ParentDeselected() {
        var draft = TaskDraft(
            title: "Parent",
            subtasks: [TaskDraft(title: "Sub 1"), TaskDraft(title: "Sub 2")]
        )
        draft.isSelected = false
        XCTAssertEqual(draft.totalSelectedCount, 0, "Parent deselected should return 0")
    }

    func testTaskDraft_TotalSelectedCount_NoSubtasks() {
        let draft = TaskDraft(title: "Simple task")
        XCTAssertEqual(draft.totalSelectedCount, 1)
    }

    func testTaskDraft_DefaultSubtasksEmpty() {
        let draft = TaskDraft(title: "Test")
        XCTAssertTrue(draft.subtasks.isEmpty)
    }

    // MARK: - Real-World Note Tests (End-to-End Deterministic)

    @MainActor
    func testRealNote_ImageNormalization_DetectsHierarchy() {
        let text = "Image normalization\n- migrate normalized images to s3 bucket with CDN setup\n- deploy to stage environment with testing"
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1, "Should detect 1 parent-child group")
        XCTAssertEqual(groups[0].parent, "Image normalization")
        XCTAssertEqual(groups[0].children.count, 2)
        XCTAssertEqual(groups[0].children[0], "migrate normalized images to s3 bucket with CDN setup")
        XCTAssertEqual(groups[0].children[1], "deploy to stage environment with testing")
    }

    @MainActor
    func testRealNote_ImageNormalization_HierarchicalParse() {
        let text = "Image normalization\n- migrate normalized images to s3 bucket with CDN setup\n- deploy to stage environment with testing"
        let service = NoteParsingService.shared
        let groups = service.deterministicParseHierarchical(text)

        XCTAssertEqual(groups.count, 1, "Should produce 1 hierarchical group")
        XCTAssertEqual(groups[0].parent.text, "Image normalization")
        XCTAssertEqual(groups[0].children.count, 2)
        XCTAssertEqual(groups[0].children[0].text, "migrate normalized images to s3 bucket with CDN setup")
        XCTAssertEqual(groups[0].children[1].text, "deploy to stage environment with testing")
    }

    @MainActor
    func testRealNote_CreateApp_WithSubtasksAndFlat() {
        let text = "Create app\n- implement home page\n- implement calendar page\n\nBuy groceries"
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 2, "Should detect 2 groups: 1 hierarchical + 1 standalone")
        XCTAssertEqual(groups[0].parent, "Create app")
        XCTAssertEqual(groups[0].children.count, 2)
        XCTAssertEqual(groups[1].parent, "Buy groceries")
        XCTAssertTrue(groups[1].children.isEmpty)
    }

    @MainActor
    func testRealNote_CreateApp_HierarchicalParseToDrafts() {
        let text = "Create app\n- implement home page\n- implement calendar page\n\nBuy groceries"
        let service = NoteParsingService.shared
        let groups = service.deterministicParseHierarchical(text)

        XCTAssertEqual(groups.count, 2)
        // First group: parent with subtasks
        XCTAssertEqual(groups[0].parent.text, "Create app")
        XCTAssertEqual(groups[0].children.count, 2)
        XCTAssertEqual(groups[0].children[0].text, "implement home page")
        XCTAssertEqual(groups[0].children[1].text, "implement calendar page")
        // Second group: standalone
        XCTAssertEqual(groups[1].parent.text, "Buy groceries")
        XCTAssertTrue(groups[1].children.isEmpty)
    }

    // MARK: - LLM Response Parsing Tests (Subtasks)

    @MainActor
    func testLLMResponse_WithSubtasks_Parsed() {
        let response = """
        [{"title": "Image normalization", "priority": "high", "category": "work", "due_date": null, "list": null, "subtasks": [{"title": "Migrate images to S3", "due_date": null, "priority": null}, {"title": "Deploy to stage", "due_date": "next week", "priority": "high"}]}]
        """
        let data = PromptTemplates.extractJSONArray(from: response)
        XCTAssertNotNil(data)

        if let data = data,
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            XCTAssertEqual(array.count, 1)
            let subtasks = array[0]["subtasks"] as? [[String: Any]]
            XCTAssertNotNil(subtasks)
            XCTAssertEqual(subtasks?.count, 2)
            XCTAssertEqual(subtasks?[0]["title"] as? String, "Migrate images to S3")
            XCTAssertEqual(subtasks?[1]["priority"] as? String, "high")
        }
    }

    @MainActor
    func testLLMResponse_FlatNoSubtasks_Parsed() {
        let response = """
        [{"title": "Migrate Images to S3", "priority": "high", "category": "work", "due_date": "Mar 6, 2026", "list": null, "subtasks": []}, {"title": "Deploy to Stage Environment", "priority": "high", "category": "work", "due_date": "Mar 6, 2026", "list": null, "subtasks": []}]
        """
        let data = PromptTemplates.extractJSONArray(from: response)
        XCTAssertNotNil(data)

        if let data = data,
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            XCTAssertEqual(array.count, 2, "LLM returned 2 flat tasks")
            let sub1 = array[0]["subtasks"] as? [[String: Any]]
            XCTAssertEqual(sub1?.count, 0, "No subtasks on flat task")
        }
    }

    // MARK: - En-dash / Em-dash Bullet Tests

    @MainActor
    func testHierarchy_EnDashBullets() {
        let text = "Project plan\n\u{2013} Design mockups\n\u{2013} Write specs"  // en-dash
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1, "En-dash bullets should be detected as children")
        XCTAssertEqual(groups[0].parent, "Project plan")
        XCTAssertEqual(groups[0].children.count, 2)
    }

    @MainActor
    func testHierarchy_EmDashBullets() {
        let text = "Project plan\n\u{2014} Design mockups\n\u{2014} Write specs"  // em-dash
        let service = NoteParsingService.shared
        let groups = service.detectHierarchy(text)

        XCTAssertEqual(groups.count, 1, "Em-dash bullets should be detected as children")
        XCTAssertEqual(groups[0].parent, "Project plan")
        XCTAssertEqual(groups[0].children.count, 2)
    }

    // MARK: - Prompt Template Subtasks Tests

    func testBuildNoteExtractionPrompt_IncludesSubtasksSchema() {
        let prompt = PromptTemplates.buildNoteExtractionPrompt(
            noteText: "Test",
            customCategories: [],
            listNames: [],
            learningContext: ""
        )
        XCTAssertTrue(prompt.contains("\"subtasks\""))
    }

    func testNoteExtractionSystemPrompt_MentionsSubtasks() {
        let systemPrompt = PromptTemplates.noteExtractionSystemPrompt
        XCTAssertTrue(systemPrompt.contains("subtask"))
    }

    // MARK: - QuickNote Model Tests

    func testQuickNote_PreviewText_Short() {
        let note = QuickNote(text: "Buy groceries")
        XCTAssertEqual(note.previewText, "Buy groceries")
    }

    func testQuickNote_PreviewText_LongTruncated() {
        let longText = String(repeating: "a", count: 100)
        let note = QuickNote(text: longText)
        XCTAssertTrue(note.previewText.count <= 83) // 80 + "..."
        XCTAssertTrue(note.previewText.hasSuffix("..."))
    }

    func testQuickNote_PreviewText_MultiLine() {
        let note = QuickNote(text: "First line\nSecond line\nThird line")
        XCTAssertEqual(note.previewText, "First line")
    }

    func testQuickNote_DefaultValues() {
        let note = QuickNote(text: "Test")
        XCTAssertFalse(note.isProcessed)
        XCTAssertNil(note.processedAt)
        XCTAssertEqual(note.extractedTaskCount, 0)
    }

    // MARK: - TaskDraft Model Tests

    func testTaskDraft_DefaultValues() {
        let draft = TaskDraft(title: "Test task")
        XCTAssertEqual(draft.priority, .none)
        XCTAssertEqual(draft.category, .uncategorized)
        XCTAssertNil(draft.dueDate)
        XCTAssertTrue(draft.isSelected)
        XCTAssertFalse(draft.isExpanded)
    }

    func testTaskDraft_IsModified_WhenTitleChanged() {
        var draft = TaskDraft(title: "Original title")
        XCTAssertFalse(draft.isModified)

        draft.title = "Modified title"
        XCTAssertTrue(draft.isModified)
    }

    func testTaskDraft_IsModified_WhenPriorityChanged() {
        var draft = TaskDraft(title: "Test", priority: .medium)
        XCTAssertFalse(draft.isModified)

        draft.priority = .high
        XCTAssertTrue(draft.isModified)
    }

    func testTaskDraft_IsModified_WhenCategoryChanged() {
        var draft = TaskDraft(title: "Test", category: .work)
        XCTAssertFalse(draft.isModified)

        draft.category = .personal
        XCTAssertTrue(draft.isModified)
    }

    func testTaskDraft_TracksOriginalValues() {
        let draft = TaskDraft(
            title: "Buy groceries",
            dueDate: Date(),
            priority: .high,
            category: .shopping
        )
        XCTAssertEqual(draft.originalTitle, "Buy groceries")
        XCTAssertEqual(draft.originalPriority, .high)
        XCTAssertEqual(draft.originalCategory, .shopping)
        XCTAssertNotNil(draft.originalDueDate)
    }
}
