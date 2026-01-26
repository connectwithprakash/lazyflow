import SwiftUI

/// Detail view for viewing and editing a task
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskViewModel
    @StateObject private var llmService = LLMService.shared
    @StateObject private var taskService = TaskService.shared
    @StateObject private var listService = TaskListService()
    @FocusState private var isTitleFocused: Bool

    @AppStorage("aiAutoSuggest") private var aiAutoSuggest: Bool = true

    @State private var showAISuggestions = false
    @State private var aiAnalysis: TaskAnalysis?
    @State private var isAnalyzing = false
    @State private var showAddSubtask = false
    @State private var newSubtaskTitle = ""
    @State private var subtasks: [Task] = []
    @State private var pendingSubtasksFromAI: [String] = []

    // Store original values before AI analysis for un-apply
    @State private var originalTitleBeforeAI: String = ""
    @State private var originalNotesBeforeAI: String = ""
    @State private var originalCategoryBeforeAI: TaskCategory = .uncategorized
    @State private var originalDurationBeforeAI: TimeInterval?
    @State private var originalPriorityBeforeAI: Priority = .none

    private let originalTask: Task

    init(task: Task) {
        _viewModel = StateObject(wrappedValue: TaskViewModel(task: task))
        self.originalTask = task
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title & Notes
                Section {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        TextField("Task title", text: $viewModel.title, axis: .vertical)
                            .font(DesignSystem.Typography.headline)
                            .focused($isTitleFocused)
                            .lineLimit(1...3)

                        // AI Suggest button
                        if llmService.isReady && aiAutoSuggest && !viewModel.title.isEmpty {
                            Button {
                                analyzeTask()
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

                // Subtasks Section (only for non-subtasks)
                if !originalTask.isSubtask {
                    Section {
                        // Header with progress
                        HStack {
                            Text("Subtasks")
                                .font(DesignSystem.Typography.headline)

                            Spacer()

                            if !subtasks.isEmpty {
                                SubtaskProgressBadge(completedCount: subtasks.filter(\.isCompleted).count, totalCount: subtasks.count)
                            }

                            Button {
                                showAddSubtask = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color.Lazyflow.accent)
                            }
                        }

                        // Subtask list
                        if subtasks.isEmpty {
                            Text("No subtasks yet")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                        } else {
                            ForEach(subtasks) { subtask in
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    // Checkbox
                                    Button {
                                        toggleSubtask(subtask)
                                    } label: {
                                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(subtask.isCompleted ? Color.Lazyflow.success : Color.Lazyflow.textTertiary)
                                    }
                                    .buttonStyle(.plain)

                                    // Title
                                    Text(subtask.title)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(subtask.isCompleted ? Color.Lazyflow.textTertiary : Color.Lazyflow.textPrimary)
                                        .strikethrough(subtask.isCompleted)

                                    Spacer()
                                }
                                .padding(.vertical, DesignSystem.Spacing.xs)
                            }
                            .onDelete(perform: deleteSubtask)
                            .onMove(perform: moveSubtask)
                        }
                    }
                }

                // Due Date & Time
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

                // Reminder
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

                // Priority
                Section {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(Priority.allCases) { priority in
                            Label(priority.displayName, systemImage: priority.iconName)
                                .foregroundColor(priority.color)
                                .tag(priority)
                        }
                    }
                }

                // Category
                Section {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(TaskCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .foregroundColor(category.color)
                                .tag(category)
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

                // Time Tracking (for completed tasks with startedAt)
                if originalTask.isCompleted, let actualDuration = originalTask.formattedActualDuration {
                    Section("Time Spent") {
                        HStack {
                            Text(actualDuration)
                                .font(DesignSystem.Typography.title3)
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .foregroundColor(Color.Lazyflow.textPrimary)

                            Spacer()

                            if let estimated = originalTask.formattedDuration {
                                Text("Est: \(estimated)")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                        }
                    }
                }

                // Recurring
                Section {
                    Toggle("Repeat", isOn: $viewModel.isRecurring.animation())

                    if viewModel.isRecurring {
                        Picker("Frequency", selection: $viewModel.recurringFrequency) {
                            ForEach(RecurringFrequency.allCases) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }

                        if viewModel.recurringFrequency == .custom {
                            Stepper(
                                "Every \(viewModel.recurringInterval) day\(viewModel.recurringInterval == 1 ? "" : "s")",
                                value: $viewModel.recurringInterval,
                                in: 1...365
                            )
                        }

                        if viewModel.recurringFrequency == .weekly {
                            weekdayPicker
                        }

                        Toggle("End Date", isOn: Binding(
                            get: { viewModel.recurringEndDate != nil },
                            set: { if !$0 { viewModel.recurringEndDate = nil } else { viewModel.recurringEndDate = Date().addingDays(30) } }
                        ))

                        if viewModel.recurringEndDate != nil {
                            DatePicker(
                                "Ends on",
                                selection: Binding(
                                    get: { viewModel.recurringEndDate ?? Date() },
                                    set: { viewModel.recurringEndDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                        }
                    }
                }

                // List
                Section {
                    Picker("List", selection: $viewModel.selectedListID) {
                        Text("No List").tag(nil as UUID?)
                        ForEach(listService.lists) { list in
                            HStack {
                                Circle()
                                    .fill(list.color)
                                    .frame(width: 12, height: 12)
                                Text(list.name)
                            }
                            .tag(list.id as UUID?)
                        }
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
                            Text("Delete Task")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Task")
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
                        // Create any pending subtasks from AI suggestions
                        if !pendingSubtasksFromAI.isEmpty {
                            createSubtasksFromAI(titles: pendingSubtasksFromAI)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $showAISuggestions) {
                if let analysis = aiAnalysis {
                    AISuggestionsSheet(
                        analysis: analysis,
                        currentTitle: viewModel.title,
                        originalTitle: originalTitleBeforeAI,
                        originalNotes: originalNotesBeforeAI,
                        originalCategory: originalCategoryBeforeAI,
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
                        onApplyCategory: { category in
                            viewModel.category = category
                        },
                        onApplyTitle: { title in
                            viewModel.title = title
                        },
                        onApplyDescription: { description in
                            viewModel.notes = description
                        },
                        onApplySubtasks: { subtasks in
                            pendingSubtasksFromAI = subtasks
                        },
                        pendingSubtasks: pendingSubtasksFromAI
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showAddSubtask) {
                AddSubtaskSheet(
                    parentTaskID: originalTask.id,
                    onAdd: { title in
                        addSubtask(title: title)
                    }
                )
                .presentationDetents([.height(200)])
            }
            .onAppear {
                loadSubtasks()
            }
        }
    }

    // MARK: - Subtask Management

    private func loadSubtasks() {
        subtasks = taskService.fetchSubtasks(forParentID: originalTask.id)
    }

    private func addSubtask(title: String) {
        taskService.createSubtask(title: title, parentTaskID: originalTask.id)
        loadSubtasks()
    }

    private func toggleSubtask(_ subtask: Task) {
        taskService.toggleSubtaskCompletion(subtask)
        loadSubtasks()
    }

    private func deleteSubtask(at offsets: IndexSet) {
        for index in offsets {
            let subtask = subtasks[index]
            taskService.deleteTask(subtask)
        }
        loadSubtasks()
    }

    private func moveSubtask(from source: IndexSet, to destination: Int) {
        var reordered = subtasks
        reordered.move(fromOffsets: source, toOffset: destination)
        taskService.reorderSubtasks(reordered, parentID: originalTask.id)
        loadSubtasks()
    }

    private func createSubtasksFromAI(titles: [String]) {
        taskService.createSubtasks(titles: titles, parentTaskID: originalTask.id)
        loadSubtasks()
    }

    // MARK: - AI Analysis

    private func analyzeTask() {
        guard !viewModel.title.isEmpty else { return }
        isAnalyzing = true

        // Store original values before AI suggestions
        originalTitleBeforeAI = viewModel.title
        originalNotesBeforeAI = viewModel.notes
        originalCategoryBeforeAI = viewModel.category
        originalDurationBeforeAI = viewModel.estimatedDuration
        originalPriorityBeforeAI = viewModel.priority

        _Concurrency.Task {
            do {
                // Create a temporary task for analysis
                let tempTask = Task(
                    id: originalTask.id,
                    title: viewModel.title,
                    notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
                    dueDate: viewModel.hasDueDate ? viewModel.dueDate : nil,
                    dueTime: viewModel.hasDueTime ? viewModel.dueTime : nil,
                    reminderDate: viewModel.hasReminder ? viewModel.reminderDate : nil,
                    isCompleted: originalTask.isCompleted,
                    isArchived: originalTask.isArchived,
                    priority: viewModel.priority,
                    listID: viewModel.selectedListID,
                    linkedEventID: originalTask.linkedEventID,
                    estimatedDuration: viewModel.estimatedDuration,
                    completedAt: originalTask.completedAt,
                    createdAt: originalTask.createdAt,
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

    // MARK: - Weekday Picker

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("On days")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(1...7, id: \.self) { day in
                    WeekdayButton(
                        day: day,
                        isSelected: viewModel.recurringDaysOfWeek.contains(day),
                        action: {
                            if viewModel.recurringDaysOfWeek.contains(day) {
                                viewModel.recurringDaysOfWeek.removeAll { $0 == day }
                            } else {
                                viewModel.recurringDaysOfWeek.append(day)
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Duration Chip

struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(isSelected ? .white : Color.Lazyflow.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    isSelected
                        ? Color.Lazyflow.accent
                        : Color.secondary.opacity(0.1)
                )
                .cornerRadius(DesignSystem.CornerRadius.full)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Weekday Button

struct WeekdayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void

    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        return symbols[day - 1]
    }

    var body: some View {
        Button(action: action) {
            Text(dayLetter)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color.Lazyflow.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.Lazyflow.accent : Color.secondary.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    TaskDetailView(task: Task.sample)
}
