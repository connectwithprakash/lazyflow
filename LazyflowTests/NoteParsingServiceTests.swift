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
