import SwiftUI

/// Simplified detail view for editing subtasks
/// Only shows essential options: title, notes, due date, priority, duration, reminder
struct SubtaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskViewModel
    @StateObject private var llmService = LLMService.shared
    @StateObject private var taskService = TaskService.shared
    @FocusState private var isTitleFocused: Bool

    @AppStorage("aiAutoSuggest") private var aiAutoSuggest: Bool = true

    @State private var showAISuggestions = false
    @State private var aiAnalysis: TaskAnalysis?
    @State private var isAnalyzing = false

    // Store original values before AI analysis for un-apply
    @State private var originalTitleBeforeAI: String = ""
    @State private var originalNotesBeforeAI: String = ""
    @State private var originalDurationBeforeAI: TimeInterval?
    @State private var originalPriorityBeforeAI: Priority = .none

    private let originalSubtask: Task

    init(subtask: Task) {
        _viewModel = StateObject(wrappedValue: TaskViewModel(task: subtask))
        self.originalSubtask = subtask
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title & Notes
                Section {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        TextField("Subtask title", text: $viewModel.title, axis: .vertical)
                            .font(DesignSystem.Typography.headline)
                            .focused($isTitleFocused)
                            .lineLimit(1...3)

                        // AI Suggest button (no subtask suggestions for subtasks)
                        if llmService.isReady && aiAutoSuggest && !viewModel.title.isEmpty {
                            Button {
                                analyzeSubtask()
                            } label: {
                                Image(systemName: isAnalyzing ? "sparkles" : "wand.and.stars")
                                    .font(.system(size: 20))
                                    .foregroundColor(isAnalyzing ? Color.purple.opacity(0.5) : Color.purple)
                                    .symbolEffect(.pulse, isActive: isAnalyzing)
                            }
                            .disabled(isAnalyzing)
                            .accessibilityLabel("AI Suggest")
                        }
                    }

                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .lineLimit(3...6)
                }

                // Due Date & Time (optional - can be earlier than parent)
                Section {
                    Toggle("Due Date", isOn: $viewModel.hasDueDate.animation())

                    if viewModel.hasDueDate {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { viewModel.dueDate ?? Date() },
                                set: { viewModel.dueDate = $0 }
                            ),
                            displayedComponents: .date
                        )

                        Toggle("Due Time", isOn: $viewModel.hasDueTime.animation())

                        if viewModel.hasDueTime {
                            DatePicker(
                                "Time",
                                selection: Binding(
                                    get: { viewModel.dueTime ?? Date() },
                                    set: { viewModel.dueTime = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }

                // Reminder (optional)
                Section {
                    Toggle("Reminder", isOn: $viewModel.hasReminder.animation())

                    if viewModel.hasReminder {
                        DatePicker(
                            "Remind at",
                            selection: Binding(
                                get: { viewModel.reminderDate ?? Date() },
                                set: { viewModel.reminderDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // Priority (optional - can override parent)
                Section {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(Priority.allCases) { priority in
                            Label(priority.displayName, systemImage: priority.iconName)
                                .foregroundColor(priority.color)
                                .tag(priority)
                        }
                    }
                }

                // Duration
                Section("Estimated Duration") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(TaskViewModel.durationPresets, id: \.0) { preset in
                                DurationChip(
                                    title: preset.0,
                                    isSelected: viewModel.estimatedDuration == preset.1,
                                    action: {
                                        if viewModel.estimatedDuration == preset.1 {
                                            viewModel.estimatedDuration = nil
                                        } else {
                                            viewModel.estimatedDuration = preset.1
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        viewModel.delete()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Subtask")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        _ = viewModel.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $showAISuggestions) {
                if let analysis = aiAnalysis {
                    SubtaskAISuggestionsSheet(
                        analysis: analysis,
                        currentTitle: viewModel.title,
                        originalTitle: originalTitleBeforeAI,
                        originalNotes: originalNotesBeforeAI,
                        originalDuration: originalDurationBeforeAI,
                        originalPriority: originalPriorityBeforeAI,
                        onApplyDuration: { minutes in
                            if let mins = minutes {
                                viewModel.estimatedDuration = TimeInterval(mins * 60)
                            } else {
                                viewModel.estimatedDuration = nil
                            }
                        },
                        onApplyPriority: { priority in
                            viewModel.priority = priority
                        },
                        onApplyTitle: { title in
                            viewModel.title = title
                        },
                        onApplyDescription: { description in
                            viewModel.notes = description
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    // MARK: - AI Analysis (no subtask suggestions for subtasks)

    private func analyzeSubtask() {
        guard !viewModel.title.isEmpty else { return }
        isAnalyzing = true

        // Store original values before AI suggestions
        originalTitleBeforeAI = viewModel.title
        originalNotesBeforeAI = viewModel.notes
        originalDurationBeforeAI = viewModel.estimatedDuration
        originalPriorityBeforeAI = viewModel.priority

        _Concurrency.Task {
            do {
                // Create a temporary task for analysis
                let tempTask = Task(
                    id: originalSubtask.id,
                    title: viewModel.title,
                    notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
                    dueDate: viewModel.hasDueDate ? viewModel.dueDate : nil,
                    dueTime: viewModel.hasDueTime ? viewModel.dueTime : nil,
                    reminderDate: viewModel.hasReminder ? viewModel.reminderDate : nil,
                    isCompleted: originalSubtask.isCompleted,
                    isArchived: originalSubtask.isArchived,
                    priority: viewModel.priority,
                    listID: originalSubtask.listID,
                    linkedEventID: originalSubtask.linkedEventID,
                    estimatedDuration: viewModel.estimatedDuration,
                    completedAt: originalSubtask.completedAt,
                    createdAt: originalSubtask.createdAt,
                    updatedAt: Date(),
                    recurringRule: nil
                )

                let analysis = try await llmService.analyzeTask(tempTask)

                await MainActor.run {
                    aiAnalysis = analysis
                    showAISuggestions = true
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Subtask AI Suggestions Sheet (no subtask suggestions)

struct SubtaskAISuggestionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let analysis: TaskAnalysis
    let currentTitle: String
    let originalTitle: String
    let originalNotes: String
    let originalDuration: TimeInterval?
    let originalPriority: Priority
    let onApplyDuration: (Int?) -> Void
    let onApplyPriority: (Priority) -> Void
    let onApplyTitle: (String) -> Void
    let onApplyDescription: (String) -> Void

    @State private var titleApplied = false
    @State private var descriptionApplied = false
    @State private var durationApplied = false
    @State private var priorityApplied = false

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
        return titleDone && descDone && durationApplied && priorityApplied
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)

                        Text("AI Analysis")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.bold)

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

                    // Note: No subtask suggestions for subtasks
                    Text("Subtask suggestions are not available for subtasks")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textTertiary)
                        .padding(.horizontal)

                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
            }
            .navigationTitle("AI Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

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

        // Apply duration and priority
        onApplyDuration(analysis.estimatedMinutes)
        durationApplied = true

        onApplyPriority(analysis.suggestedPriority)
        priorityApplied = true
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

// MARK: - Preview

#Preview("Subtask Detail") {
    SubtaskDetailView(subtask: Task(title: "Research existing patterns", notes: "Look at how other apps handle this"))
}
