import CoreData
import XCTest
@testable import Lazyflow

@MainActor
final class QuickNoteServiceTests: XCTestCase {

    var persistence: PersistenceController!
    var sut: QuickNoteService!

    override func setUp() async throws {
        persistence = PersistenceController(inMemory: true, enableCloudKit: false)
        sut = QuickNoteService(persistenceController: persistence)
    }

    override func tearDown() async throws {
        sut = nil
        persistence = nil
    }

    // MARK: - Create

    func testCreateNote_AddsNote() {
        let note = sut.createNote(text: "Buy groceries")

        XCTAssertEqual(note.text, "Buy groceries")
        XCTAssertFalse(note.isProcessed)
        XCTAssertEqual(sut.notes.count, 1)
    }

    func testCreateNote_TrimsWhitespace() {
        let note = sut.createNote(text: "  Buy groceries  ")
        XCTAssertEqual(note.text, "Buy groceries")
    }

    func testCreateNote_EmptyText_ReturnsEmptyNote() {
        let note = sut.createNote(text: "   ")
        XCTAssertEqual(note.text, "")
        XCTAssertEqual(sut.notes.count, 0, "Empty notes should not be persisted")
    }

    func testCreateNote_MultipleNotes() {
        sut.createNote(text: "Note 1")
        sut.createNote(text: "Note 2")
        sut.createNote(text: "Note 3")

        XCTAssertEqual(sut.notes.count, 3)
    }

    // MARK: - Fetch & Filtering

    func testUnprocessedNotes_FiltersCorrectly() {
        sut.createNote(text: "Unprocessed note")
        let processed = sut.createNote(text: "Processed note")
        sut.markProcessed(processed, taskCount: 2)

        XCTAssertEqual(sut.unprocessedNotes.count, 1)
        XCTAssertEqual(sut.unprocessedNotes.first?.text, "Unprocessed note")
    }

    func testProcessedNotes_FiltersCorrectly() {
        sut.createNote(text: "Unprocessed")
        let note = sut.createNote(text: "Will be processed")
        sut.markProcessed(note, taskCount: 1)

        XCTAssertEqual(sut.processedNotes.count, 1)
        XCTAssertEqual(sut.processedNotes.first?.text, "Will be processed")
    }

    // MARK: - Update

    func testUpdateNoteText() {
        let note = sut.createNote(text: "Original text")
        sut.updateNoteText(note, text: "Updated text")

        XCTAssertEqual(sut.notes.first?.text, "Updated text")
    }

    func testUpdateNoteText_EmptyText_NoChange() {
        let note = sut.createNote(text: "Original text")
        sut.updateNoteText(note, text: "  ")

        XCTAssertEqual(sut.notes.first?.text, "Original text")
    }

    // MARK: - Mark Processed

    func testMarkProcessed() {
        let note = sut.createNote(text: "Process me")
        sut.markProcessed(note, taskCount: 3)

        let updated = sut.notes.first { $0.id == note.id }
        XCTAssertNotNil(updated)
        XCTAssertTrue(updated!.isProcessed)
        XCTAssertEqual(updated!.extractedTaskCount, 3)
        XCTAssertNotNil(updated!.processedAt)
    }

    func testUnmarkProcessed() {
        let note = sut.createNote(text: "Toggle me")
        sut.markProcessed(note, taskCount: 2)
        sut.unmarkProcessed(sut.notes.first { $0.id == note.id }!)

        let updated = sut.notes.first { $0.id == note.id }
        XCTAssertNotNil(updated)
        XCTAssertFalse(updated!.isProcessed)
        XCTAssertEqual(updated!.extractedTaskCount, 0)
        XCTAssertNil(updated!.processedAt, "processedAt should be nil after unmark")
    }

    // MARK: - Delete

    func testDeleteNote() {
        let note = sut.createNote(text: "Delete me")
        XCTAssertEqual(sut.notes.count, 1)

        sut.deleteNote(note)

        XCTAssertEqual(sut.notes.count, 0)
    }

    func testDeleteNote_OnlyDeletesTarget() {
        sut.createNote(text: "Keep me")
        let toDelete = sut.createNote(text: "Delete me")

        sut.deleteNote(toDelete)

        XCTAssertEqual(sut.notes.count, 1)
        XCTAssertEqual(sut.notes.first?.text, "Keep me")
    }
}
