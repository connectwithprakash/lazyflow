import SwiftUI
import LazyflowCore
import LazyflowUI

/// Full list of all quick notes (both unprocessed and processed)
struct QuickNotesListView: View {
    @State private var noteService = QuickNoteService.shared
    @State private var noteToEdit: QuickNote?
    @State private var noteToExtract: QuickNote?
    @State private var noteToDelete: QuickNote?
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            if !noteService.unprocessedNotes.isEmpty {
                Section {
                    ForEach(noteService.unprocessedNotes) { note in
                        QuickNoteRow(note: note, onTap: {
                            noteToEdit = note
                        }, onExtract: {
                            noteToExtract = note
                        })
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                noteToDelete = note
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Unprocessed")
                }
            }

            if !noteService.processedNotes.isEmpty {
                Section {
                    ForEach(noteService.processedNotes) { note in
                        QuickNoteRow(note: note, isProcessed: true, onTap: {
                            noteToEdit = note
                        }, onExtract: {
                            noteToExtract = note
                        })
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                noteToDelete = note
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Processed")
                }
            }

            if noteService.notes.isEmpty {
                Section {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        Text("No quick notes yet")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                        Text("Tap the + button to capture a thought")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xxxl)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground)
        .navigationTitle("Quick Notes")
        .sheet(item: $noteToEdit) { note in
            QuickCaptureSheet(note: note) { updatedNote in
                noteToExtract = updatedNote
            }
        }
        .sheet(item: $noteToExtract) { note in
            QuickCaptureReviewView(note: note)
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    noteService.deleteNote(note)
                }
                noteToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
    }
}

// MARK: - Quick Note Row

struct QuickNoteRow: View {
    let note: QuickNote
    var isProcessed: Bool = false
    let onTap: () -> Void
    var onExtract: (() -> Void)?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Content — tappable for editing
            Button {
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(note.previewText)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(note.timeAgo)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)

                        if isProcessed, note.extractedTaskCount > 0 {
                            Text("\(note.extractedTaskCount) task\(note.extractedTaskCount == 1 ? "" : "s")")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.success)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Note: \(note.previewText)")
            .accessibilityHint("Double-tap to edit")

            // Extract pill — separate tap target
            if let onExtract {
                Button {
                    onExtract()
                } label: {
                    Text(isProcessed ? "Extract Again" : "Extract")
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Lazyflow.accent)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                        .background(Color.Lazyflow.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Extract")
                .accessibilityLabel(isProcessed ? "Extract tasks again" : "Extract tasks")
                .accessibilityHint("Use AI to extract tasks from this note")
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        QuickNotesListView()
    }
}
