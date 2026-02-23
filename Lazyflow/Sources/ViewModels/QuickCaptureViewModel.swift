import Foundation
import SwiftUI

/// View model for the Quick Capture extraction review flow
@MainActor
final class QuickCaptureViewModel: ObservableObject {

    // MARK: - State Machine

    enum ViewState: Equatable {
        case extracting
        case review
        case creating
        case completed(count: Int)
        case error(message: String)

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.extracting, .extracting): return true
            case (.review, .review): return true
            case (.creating, .creating): return true
            case (.completed(let a), .completed(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Published Properties

    @Published var viewState: ViewState = .extracting
    @Published var drafts: [TaskDraft] = []

    let note: QuickNote

    // MARK: - Dependencies

    private let noteParsingService = NoteParsingService.shared
    private let noteService = QuickNoteService.shared
    private let taskService = TaskService.shared
    private let learningService = AILearningService.shared

    // MARK: - Computed Properties

    var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    var hasSelectedDrafts: Bool {
        selectedCount > 0
    }

    // MARK: - Init

    init(note: QuickNote) {
        self.note = note
    }

    // MARK: - Actions

    /// Start the extraction process
    func extract() async {
        viewState = .extracting

        let results = await noteParsingService.extractTasks(from: note.text)

        if results.isEmpty {
            // No tasks found — offer to create a single task from the note text
            let fallbackDraft = TaskDraft(title: note.previewText)
            drafts = [fallbackDraft]
        } else {
            drafts = results
        }

        viewState = .review
    }

    /// Toggle selection of a draft
    func toggleDraft(at index: Int) {
        guard drafts.indices.contains(index) else { return }
        drafts[index].isSelected.toggle()
    }

    /// Toggle expansion of a draft for inline editing
    func toggleExpansion(at index: Int) {
        guard drafts.indices.contains(index) else { return }
        drafts[index].isExpanded.toggle()
    }

    /// Create all selected tasks
    func createTasks() {
        viewState = .creating

        let selectedDrafts = drafts.filter(\.isSelected)
        var createdCount = 0

        for draft in selectedDrafts {
            taskService.createTask(
                title: draft.title,
                dueDate: draft.dueDate,
                dueTime: draft.dueTime,
                priority: draft.priority,
                category: draft.category,
                customCategoryID: draft.customCategoryID,
                listID: draft.listID
            )
            createdCount += 1

            // Record learning data
            recordLearning(for: draft)
        }

        // Record deselected drafts
        for draft in drafts where !draft.isSelected {
            learningService.recordCorrection(
                field: .title,
                originalSuggestion: draft.originalTitle,
                userChoice: "removed",
                taskTitle: draft.originalTitle
            )
        }

        // Mark note as processed
        noteService.markProcessed(note, taskCount: createdCount)

        viewState = .completed(count: createdCount)
    }

    /// Skip extraction — mark note as processed with 0 tasks
    func skip() {
        learningService.recordCorrection(
            field: .title,
            originalSuggestion: "session",
            userChoice: "cancelled",
            taskTitle: note.previewText
        )
    }

    // MARK: - Learning

    private func recordLearning(for draft: TaskDraft) {
        // Record impression
        learningService.recordImpression()

        // Record corrections for modified fields
        if draft.title != draft.originalTitle {
            learningService.recordCorrection(
                field: .title,
                originalSuggestion: draft.originalTitle,
                userChoice: draft.title,
                taskTitle: draft.title
            )
        }

        if draft.priority != draft.originalPriority {
            learningService.recordCorrection(
                field: .priority,
                originalSuggestion: draft.originalPriority.displayName,
                userChoice: draft.priority.displayName,
                taskTitle: draft.title
            )
        }

        if draft.category != draft.originalCategory {
            learningService.recordCorrection(
                field: .category,
                originalSuggestion: draft.originalCategory.displayName,
                userChoice: draft.category.displayName,
                taskTitle: draft.title
            )
        }
    }
}
