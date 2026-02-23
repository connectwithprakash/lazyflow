import SwiftUI

/// Minimal capture sheet for quick notes — auto-saves on dismiss
struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var noteService = QuickNoteService.shared
    @State private var noteText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $noteText)
                    .font(DesignSystem.Typography.body)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .scrollContentBackground(.hidden)
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
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Quick Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Don't save on cancel
                        noteText = ""
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
            isTextFieldFocused = true
        }
        .onDisappear {
            // Auto-save non-empty notes when swiped down
            let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                noteService.createNote(text: trimmed)
            }
        }
        .interactiveDismissDisabled(false)
    }

    private func saveAndDismiss() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            noteService.createNote(text: trimmed)
        }
        noteText = "" // Clear so onDisappear doesn't double-save
        dismiss()
    }
}

#Preview {
    QuickCaptureSheet()
}
