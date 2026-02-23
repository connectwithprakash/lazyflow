import SwiftUI

/// Review screen for AI-extracted tasks from a quick note
struct QuickCaptureReviewView: View {
    @StateObject private var viewModel: QuickCaptureViewModel
    @Environment(\.dismiss) private var dismiss

    init(note: QuickNote) {
        _viewModel = StateObject(wrappedValue: QuickCaptureViewModel(note: note))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.viewState {
                case .extracting:
                    extractingState
                case .review:
                    reviewState
                case .creating:
                    creatingState
                case .completed(let count):
                    completedState(count: count)
                case .error(let message):
                    errorState(message: message)
                }
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Extract Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.extract()
        }
    }

    // MARK: - Extracting State

    private var extractingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing your note...")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review State

    private var reviewState: some View {
        VStack(spacing: 0) {
            // Source note preview
            notePreview

            // Draft cards
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(viewModel.drafts.enumerated()), id: \.element.id) { index, draft in
                        DraftCardView(
                            draft: Binding(
                                get: { viewModel.drafts[index] },
                                set: { viewModel.drafts[index] = $0 }
                            ),
                            onToggle: { viewModel.toggleDraft(at: index) },
                            onExpand: { viewModel.toggleExpansion(at: index) }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }

            // Bottom action bar
            actionBar
        }
    }

    private var notePreview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("From your note:")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text(viewModel.note.previewText)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.adaptiveSurface)
    }

    private var actionBar: some View {
        HStack {
            Button("Skip") {
                viewModel.skip()
                dismiss()
            }
            .foregroundColor(Color.Lazyflow.textSecondary)

            Spacer()

            Button {
                viewModel.createTasks()
            } label: {
                Text("Create \(viewModel.selectedCount) Task\(viewModel.selectedCount == 1 ? "" : "s")")
                    .fontWeight(.semibold)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.hasSelectedDrafts)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface)
    }

    // MARK: - Creating State

    private var creatingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Creating tasks...")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Completed State

    private func completedState(count: Int) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Color.Lazyflow.success)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("\(count) Task\(count == 1 ? "" : "s") Created")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text("Your note has been processed")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundColor(Color.Lazyflow.warning)

            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                _Concurrency.Task {
                    await viewModel.extract()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Draft Card View

private struct DraftCardView: View {
    @Binding var draft: TaskDraft
    let onToggle: () -> Void
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: DesignSystem.Spacing.md) {
                // Checkbox — separate tap target
                Button {
                    onToggle()
                } label: {
                    Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(draft.isSelected ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)
                        .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
                }
                .buttonStyle(.plain)

                    // Title and metadata
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(draft.title)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Metadata chips
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if let dueDate = draft.dueDate {
                                metadataChip(
                                    icon: "calendar",
                                    text: dueDate.relativeFormatted
                                )
                            }

                            if draft.priority != .none {
                                metadataChip(
                                    icon: draft.priority.iconName,
                                    text: draft.priority.displayName,
                                    color: draft.priority.color
                                )
                            }

                            if draft.category != .uncategorized {
                                metadataChip(
                                    icon: draft.category.iconName,
                                    text: draft.category.displayName
                                )
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(Color.Lazyflow.textTertiary)
                        .rotationEffect(.degrees(draft.isExpanded ? 180 : 0))
                }
                .padding(DesignSystem.Spacing.md)
                .contentShape(Rectangle())
                .onTapGesture { onExpand() }

            // Expanded editing
            if draft.isExpanded {
                expandedEditor
            }
        }
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    private func metadataChip(icon: String, text: String, color: Color = Color.Lazyflow.textSecondary) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(DesignSystem.Typography.caption2)
        }
        .foregroundColor(color)
    }

    private var expandedEditor: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Divider()

            // Title editor
            TextField("Task title", text: $draft.title)
                .font(DesignSystem.Typography.body)
                .textFieldStyle(.roundedBorder)

            // Priority picker
            HStack {
                Text("Priority")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                Spacer()
                Picker("Priority", selection: $draft.priority) {
                    ForEach(Priority.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
                .pickerStyle(.menu)
            }

            // Category picker
            HStack {
                Text("Category")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                Spacer()
                Picker("Category", selection: $draft.category) {
                    ForEach(TaskCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            // Due date picker
            HStack {
                Text("Due Date")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                Spacer()
                if let dueDate = draft.dueDate {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        DatePicker("", selection: Binding(
                            get: { dueDate },
                            set: { draft.dueDate = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()

                        Button {
                            draft.dueDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button("Add Date") {
                        draft.dueDate = Date()
                    }
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.accent)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
}

#Preview {
    QuickCaptureReviewView(
        note: QuickNote(
            text: "Buy groceries tomorrow and call dentist next week. Also need to finish the report by Friday."
        )
    )
}
