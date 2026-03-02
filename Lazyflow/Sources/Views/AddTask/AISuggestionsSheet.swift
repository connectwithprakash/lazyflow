import SwiftUI

struct AISuggestionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let analysis: TaskAnalysis
    let currentTitle: String
    let originalTitle: String
    let originalNotes: String
    let originalCategory: TaskCategory
    let originalDuration: TimeInterval?
    let originalPriority: Priority
    let onApplyDuration: (Int?) -> Void
    let onApplyPriority: (Priority) -> Void
    let onApplyCategory: (TaskCategory) -> Void
    let onApplyTitle: (String) -> Void
    let onApplyDescription: (String) -> Void
    let onApplySubtasks: ([String]) -> Void
    let onCreateCategory: (ProposedCategory) -> Void
    let onTryAgain: () -> Void
    let pendingSubtasks: [String]  // Initial value from parent
    let isRegenerating: Bool

    @State private var titleApplied = false
    @State private var descriptionApplied = false
    @State private var categoryApplied = false
    @State private var durationApplied = false
    @State private var priorityApplied = false
    @State private var newCategoryCreated = false
    @State private var localSubtasks: [String] = []  // Local state for subtasks

    private var hasTitleSuggestion: Bool {
        if let title = analysis.refinedTitle, !title.isEmpty, title != currentTitle {
            return true
        }
        return false
    }

    private var hasDescriptionSuggestion: Bool {
        if let desc = analysis.suggestedDescription, !desc.isEmpty {
            return true
        }
        return false
    }

    private var allApplied: Bool {
        let titleDone = !hasTitleSuggestion || titleApplied
        let descDone = !hasDescriptionSuggestion || descriptionApplied
        let categoryDone = analysis.suggestedCategory == .uncategorized || categoryApplied
        return titleDone && descDone && categoryDone && durationApplied && priorityApplied
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ZStack {
                            if isRegenerating {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 40))
                                    .foregroundColor(.purple)
                            }
                        }

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text("AI Analysis")
                                .font(DesignSystem.Typography.title2)
                                .fontWeight(.bold)

                            Button {
                                onTryAgain()
                            } label: {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(.purple)
                            }
                            .disabled(isRegenerating)
                            .opacity(isRegenerating ? 0.5 : 1.0)
                        }

                        Text("Tap Apply on suggestions you want to use")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                    .padding(.top)

                    // Apply All Button
                    if !allApplied {
                        Button {
                            applyAll()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Apply All Suggestions")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .padding(.horizontal)
                    }

                    // Title Suggestion
                    if hasTitleSuggestion, let refinedTitle = analysis.refinedTitle {
                        SuggestionCard(
                            icon: "textformat",
                            title: "Refined Title",
                            value: refinedTitle,
                            color: Color.purple
                        ) {
                            ToggleApplyButton(
                                isApplied: $titleApplied,
                                color: Color.purple,
                                onApply: {
                                    onApplyTitle(refinedTitle)
                                },
                                onUnapply: {
                                    onApplyTitle(originalTitle)
                                }
                            )
                        }
                    }

                    // Description Suggestion
                    if hasDescriptionSuggestion, let description = analysis.suggestedDescription {
                        SuggestionCard(
                            icon: "text.alignleft",
                            title: "Suggested Description",
                            value: description,
                            color: Color.Lazyflow.info
                        ) {
                            ToggleApplyButton(
                                isApplied: $descriptionApplied,
                                color: Color.Lazyflow.info,
                                onApply: {
                                    onApplyDescription(description)
                                },
                                onUnapply: {
                                    onApplyDescription(originalNotes)
                                }
                            )
                        }
                    }

                    // Category Suggestion
                    if analysis.suggestedCategory != .uncategorized {
                        SuggestionCard(
                            icon: analysis.suggestedCategory.iconName,
                            title: "Category",
                            value: analysis.suggestedCategory.displayName,
                            color: analysis.suggestedCategory.color
                        ) {
                            ToggleApplyButton(
                                isApplied: $categoryApplied,
                                color: analysis.suggestedCategory.color,
                                onApply: {
                                    onApplyCategory(analysis.suggestedCategory)
                                },
                                onUnapply: {
                                    onApplyCategory(originalCategory)
                                }
                            )
                        }
                    }

                    // Proposed New Category
                    if let proposedCategory = analysis.proposedNewCategory {
                        proposedCategoryCard(proposedCategory)
                    }

                    // Duration Suggestion
                    SuggestionCard(
                        icon: "clock",
                        title: "Estimated Duration",
                        value: formatDuration(analysis.estimatedMinutes),
                        color: Color.Lazyflow.accent
                    ) {
                        ToggleApplyButton(
                            isApplied: $durationApplied,
                            color: Color.Lazyflow.accent,
                            onApply: {
                                onApplyDuration(analysis.estimatedMinutes)
                            },
                            onUnapply: {
                                if let duration = originalDuration {
                                    onApplyDuration(Int(duration / 60))
                                } else {
                                    onApplyDuration(nil)
                                }
                            }
                        )
                    }

                    // Priority Suggestion
                    SuggestionCard(
                        icon: analysis.suggestedPriority.iconName,
                        title: "Suggested Priority",
                        value: analysis.suggestedPriority.displayName,
                        color: analysis.suggestedPriority.color
                    ) {
                        ToggleApplyButton(
                            isApplied: $priorityApplied,
                            color: analysis.suggestedPriority.color,
                            onApply: {
                                onApplyPriority(analysis.suggestedPriority)
                            },
                            onUnapply: {
                                onApplyPriority(originalPriority)
                            }
                        )
                    }

                    // Best Time
                    SuggestionCard(
                        icon: bestTimeIcon,
                        title: "Best Time to Work",
                        value: analysis.bestTime.rawValue,
                        color: Color.Lazyflow.info
                    ) {
                        EmptyView()
                    }

                    // Subtasks (if any)
                    if !analysis.subtasks.isEmpty {
                        subtasksSuggestionSection
                    }

                    // Tips
                    if !analysis.tips.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Productivity Tip", systemImage: "lightbulb")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(Color.Lazyflow.warning)

                            Text(analysis.tips)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        .padding()
                        .background(Color.Lazyflow.warning.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
            }
            .navigationTitle("AI Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Apply subtasks before dismissing
                        onApplySubtasks(localSubtasks)
                        // Small delay to ensure state update propagates
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                // Initialize local state from parent
                localSubtasks = pendingSubtasks
            }
        }
    }

    // MARK: - Proposed Category Card

    private func proposedCategoryCard(_ proposedCategory: ProposedCategory) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label("Create New Category", systemImage: "plus.circle.fill")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Spacer()

                if newCategoryCreated {
                    Label("Created", systemImage: "checkmark.circle.fill")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.success)
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                // Category preview
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: proposedCategory.iconName)
                        .foregroundColor(Color(hex: proposedCategory.colorHex) ?? Color.gray)
                    Text(proposedCategory.name)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill((Color(hex: proposedCategory.colorHex) ?? Color.gray).opacity(0.15))
                )

                Spacer()

                // Create button
                if !newCategoryCreated {
                    Button {
                        onCreateCategory(proposedCategory)
                        newCategoryCreated = true
                    } label: {
                        Text("Create & Apply")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(Color.Lazyflow.accent)
                            .cornerRadius(DesignSystem.CornerRadius.small)
                    }
                }
            }

            Text("AI suggests creating this category for tasks like yours")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(Color.Lazyflow.accent.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Subtasks Suggestion Section

    private var subtasksSuggestionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label("Suggested Subtasks", systemImage: "list.bullet")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Spacer()

                if !localSubtasks.isEmpty {
                    Text("\(localSubtasks.count) selected")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.accent)
                }
            }

            ForEach(analysis.subtasks, id: \.self) { subtask in
                Button {
                    toggleSubtask(subtask)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: localSubtasks.contains(subtask) ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundColor(localSubtasks.contains(subtask) ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)

                        Text(subtask)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    localSubtasks = analysis.subtasks
                } label: {
                    Text("Select All")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(Color.Lazyflow.accent)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }

                Button {
                    localSubtasks.removeAll()
                } label: {
                    Text("Clear All")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
                .disabled(localSubtasks.isEmpty)
            }
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func applyAll() {
        // Apply title if available
        if hasTitleSuggestion, let title = analysis.refinedTitle {
            onApplyTitle(title)
            titleApplied = true
        }

        // Apply description if available
        if hasDescriptionSuggestion, let desc = analysis.suggestedDescription {
            onApplyDescription(desc)
            descriptionApplied = true
        }

        // Apply category if not uncategorized
        if analysis.suggestedCategory != .uncategorized {
            onApplyCategory(analysis.suggestedCategory)
            categoryApplied = true
        }

        // Apply duration and priority
        onApplyDuration(analysis.estimatedMinutes)
        durationApplied = true

        onApplyPriority(analysis.suggestedPriority)
        priorityApplied = true

        // Select all subtasks
        if !analysis.subtasks.isEmpty {
            localSubtasks = analysis.subtasks
        }
    }

    private func toggleSubtask(_ subtask: String) {
        if let index = localSubtasks.firstIndex(of: subtask) {
            localSubtasks.remove(at: index)
        } else {
            localSubtasks.append(subtask)
        }
    }

    private var bestTimeIcon: String {
        switch analysis.bestTime {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon"
        case .anytime: return "clock"
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
}
