import SwiftUI

/// Minimal capture sheet for quick notes — supports both creating new notes and editing existing ones
struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var noteService = QuickNoteService.shared
    @State private var noteText = ""
    @FocusState private var isTextFieldFocused: Bool

    /// When set, the sheet is in edit mode for an existing note
    private let existingNote: QuickNote?
    /// Callback to open extraction review for this note
    var onExtract: ((QuickNote) -> Void)?

    init() {
        self.existingNote = nil
    }

    init(note: QuickNote, onExtract: ((QuickNote) -> Void)? = nil) {
        self.existingNote = note
        self.onExtract = onExtract
    }

    private var isEditing: Bool { existingNote != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $noteText)
                    .font(DesignSystem.Typography.body)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(isEditing ? "Edit note" : "New note")
                    .accessibilityHint("Enter your thought, idea, or task")
                    .overlay(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("Jot down a thought, idea, or task...")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                                .padding(.top, DesignSystem.Spacing.md)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }

                // Extract button when editing an existing note
                if isEditing {
                    extractButton
                }
            }
            .background(Color.adaptiveBackground)
            .navigationTitle(isEditing ? "Edit Note" : "Quick Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        noteText = "" // Prevent onDisappear save
                        dismiss()
                    }
                    .foregroundColor(Color.Lazyflow.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Lazyflow.accent)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let note = existingNote {
                noteText = note.text
            }
            isTextFieldFocused = true
        }
        .onDisappear {
            // Auto-save non-empty notes when swiped down
            let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if let note = existingNote {
                    noteService.updateNoteText(note, text: trimmed)
                } else {
                    noteService.createNote(text: trimmed)
                }
            }
        }
        .interactiveDismissDisabled(false)
    }

    private var extractButton: some View {
        Button {
            // Save any edits first, then trigger extraction
            let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            if let note = existingNote, !trimmed.isEmpty {
                noteService.updateNoteText(note, text: trimmed)
                var updatedNote = note
                updatedNote.text = trimmed
                noteText = "" // Prevent onDisappear double-save
                dismiss()
                // Small delay to let dismiss animation complete before presenting extraction
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onExtract?(updatedNote)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.body)
                Text("Extract Tasks")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(Color.Lazyflow.accent.opacity(0.12))
            .foregroundColor(Color.Lazyflow.accent)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
        .accessibilityLabel("Extract Tasks")
        .accessibilityHint("Use AI to extract tasks from this note")
    }

    private func saveAndDismiss() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if let note = existingNote {
                noteService.updateNoteText(note, text: trimmed)
            } else {
                noteService.createNote(text: trimmed)
            }
        }
        noteText = "" // Clear so onDisappear doesn't double-save
        dismiss()
    }
}

#Preview("New Note") {
    QuickCaptureSheet()
}

#Preview("Edit Note") {
    QuickCaptureSheet(
        note: QuickNote(text: "Buy groceries tomorrow"),
        onExtract: { _ in }
    )
}
