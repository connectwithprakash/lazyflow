import SwiftUI

/// Detail view for viewing and editing a task
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskViewModel
    @StateObject private var llmService = LLMService.shared
    @StateObject private var taskService = TaskService.shared
    @StateObject private var listService = TaskListService.shared
    @StateObject private var categoryService = CategoryService.shared
    @FocusState private var isTitleFocused: Bool

    @AppStorage("aiAutoSuggest") private var aiAutoSuggest: Bool = true

    @State private var showAISuggestions = false
    @State private var aiAnalysis: TaskAnalysis?
    @State private var isAnalyzing = false
    @State private var showAddSubtask = false
    @State private var subtasks: [Task] = []
    @State private var pendingSubtasksFromAI: [String] = []

    // Sheet states
    @State private var showDatePicker = false
    @State private var showListPicker = false
    @State private var showDurationSheet = false
    @State private var showRecurringSheet = false
    @State private var showReminderSheet = false

    // Store original values before AI analysis for un-apply
    @State private var originalTitleBeforeAI: String = ""
    @State private var originalNotesBeforeAI: String = ""
    @State private var originalCategoryBeforeAI: TaskCategory = .uncategorized
    @State private var originalDurationBeforeAI: TimeInterval?
    @State private var originalPriorityBeforeAI: Priority = .none

    // Track if AI is regenerating suggestions
    @State private var isRegeneratingAI: Bool = false

    private let originalTask: Task

    init(task: Task) {
        _viewModel = StateObject(wrappedValue: TaskViewModel(task: task))
        self.originalTask = task
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Title field with AI button
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        TextField("Task title", text: $viewModel.title, axis: .vertical)
                            .font(DesignSystem.Typography.title3)
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
                    .padding(.horizontal)
                    .padding(.top)

                    // Notes field
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .lineLimit(3...6)
                        .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Quick action buttons (3-row grid)
                    quickActionsGrid
                        .padding(.horizontal)

                    // Subtasks Section (only for non-subtasks and non-intraday tasks)
                    if !originalTask.isSubtask && !originalTask.isIntradayTask {
                        subtasksSection
                            .padding(.horizontal)
                    }

                    // Selected options display
                    if hasSelectedOptions {
                        VStack(spacing: 0) {
                            Divider()
                                .padding(.horizontal)
                                .padding(.top, DesignSystem.Spacing.md)

                            selectedOptionsView
                                .padding(.horizontal)
                                .padding(.top, DesignSystem.Spacing.md)
                        }
                    }

                    // Time Tracking (for completed tasks with startedAt)
                    if originalTask.isCompleted, let actualDuration = originalTask.formattedActualDuration {
                        Divider()
                            .padding(.horizontal)
                            .padding(.top, DesignSystem.Spacing.md)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Time Spent")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textSecondary)

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
                        .padding(.horizontal)
                    }

                    // Delete button
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, DesignSystem.Spacing.md)

                    Button(role: .destructive) {
                        viewModel.delete()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Task", systemImage: "trash")
                                .font(DesignSystem.Typography.body)
                            Spacer()
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, DesignSystem.Spacing.lg)
                .background(Color.adaptiveSurface)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.adaptiveBackground)
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
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(
                    selectedDate: $viewModel.dueDate,
                    hasDate: $viewModel.hasDueDate,
                    selectedTime: $viewModel.dueTime,
                    hasTime: $viewModel.hasDueTime
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showListPicker) {
                ListPickerSheet(
                    selectedListID: $viewModel.selectedListID,
                    lists: listService.lists
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showDurationSheet) {
                DurationPickerSheet(estimatedDuration: $viewModel.estimatedDuration)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showRecurringSheet) {
                RecurringOptionsSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showReminderSheet) {
                ReminderPickerSheet(
                    hasReminder: $viewModel.hasReminder,
                    reminderDate: $viewModel.reminderDate,
                    defaultDate: viewModel.dueDate
                )
                .presentationDetents([.medium])
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
                        onCreateCategory: { proposedCategory in
                            // Check if category with this name already exists (case-insensitive)
                            if let existingCategory = CategoryService.shared.getCategory(byName: proposedCategory.name) {
                                viewModel.customCategoryID = existingCategory.id
                            } else {
                                let newCategory = CategoryService.shared.createCategory(
                                    name: proposedCategory.name,
                                    colorHex: proposedCategory.colorHex,
                                    iconName: proposedCategory.iconName
                                )
                                viewModel.customCategoryID = newCategory.id
                            }
                            viewModel.category = .uncategorized
                        },
                        onTryAgain: {
                            regenerateAISuggestions()
                        },
                        pendingSubtasks: pendingSubtasksFromAI,
                        isRegenerating: isRegeneratingAI
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

    // MARK: - Quick Actions Grid (3-row layout)

    private var quickActionsGrid: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Row 1: Date options
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Due Date picker
                QuickActionButton(
                    icon: "calendar",
                    title: dateButtonTitle,
                    isSelected: viewModel.hasDueDate,
                    color: Color.Lazyflow.accent
                ) {
                    showDatePicker = true
                }

                // Today quick action
                QuickActionButton(
                    icon: "star",
                    title: "Today",
                    isSelected: viewModel.dueDate?.isToday == true,
                    color: Color.Lazyflow.warning
                ) {
                    viewModel.setDueToday()
                }

                // Tomorrow quick action
                QuickActionButton(
                    icon: "sunrise",
                    title: "Tomorrow",
                    isSelected: viewModel.dueDate?.isTomorrow == true,
                    color: Color.Lazyflow.priorityMedium
                ) {
                    viewModel.setDueTomorrow()
                }
            }

            // Row 2: Priority, Category, List
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Priority
                Menu {
                    ForEach(Priority.allCases) { priority in
                        Button {
                            viewModel.priority = priority
                        } label: {
                            Label(priority.displayName, systemImage: priority.iconName)
                        }
                    }
                } label: {
                    QuickActionButtonContent(
                        icon: viewModel.priority.iconName,
                        title: viewModel.priority == .none ? "Priority" : viewModel.priority.displayName,
                        isSelected: viewModel.priority != .none,
                        color: viewModel.priority.color
                    )
                }

                // Category
                Menu {
                    // System categories
                    ForEach(TaskCategory.allCases) { category in
                        Button {
                            viewModel.selectSystemCategory(category)
                        } label: {
                            Label(category.displayName, systemImage: category.iconName)
                        }
                    }

                    // Custom categories (if any)
                    if !categoryService.categories.isEmpty {
                        Divider()

                        ForEach(categoryService.categories) { customCategory in
                            Button {
                                viewModel.selectCustomCategory(customCategory.id)
                            } label: {
                                Label(customCategory.displayName, systemImage: customCategory.iconName)
                            }
                        }
                    }
                } label: {
                    QuickActionButtonContent(
                        icon: categoryDisplayIcon,
                        title: categoryDisplayName,
                        isSelected: viewModel.hasCategorySelected,
                        color: categoryDisplayColor
                    )
                }

                // List
                QuickActionButton(
                    icon: "folder",
                    title: selectedListName,
                    isSelected: viewModel.selectedListID != nil,
                    color: Color.Lazyflow.textTertiary
                ) {
                    showListPicker = true
                }
            }

            // Row 3: Reminder, Duration, Repeat
            HStack(spacing: DesignSystem.Spacing.sm) {
                QuickActionButton(
                    icon: viewModel.hasReminder ? "bell.fill" : "bell",
                    title: viewModel.hasReminder ? formatReminderTime(viewModel.reminderDate) : "Remind",
                    isSelected: viewModel.hasReminder,
                    color: Color.Lazyflow.info
                ) {
                    showReminderSheet = true
                }

                QuickActionButton(
                    icon: "clock",
                    title: durationDisplayTitle,
                    isSelected: viewModel.estimatedDuration != nil,
                    color: Color.Lazyflow.accent
                ) {
                    showDurationSheet = true
                }

                QuickActionButton(
                    icon: "repeat",
                    title: viewModel.isRecurring ? recurringDisplayTitle : "Repeat",
                    isSelected: viewModel.isRecurring,
                    color: Color.Lazyflow.info
                ) {
                    showRecurringSheet = true
                }
            }
        }
    }

    // MARK: - Subtasks Section

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header with progress
            HStack {
                Text("Subtasks")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)

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
                .accessibilityLabel("Add subtask")
            }

            // Subtask list
            if subtasks.isEmpty {
                Text("No subtasks yet")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else {
                ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
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
                        .accessibilityLabel(subtask.isCompleted ? "Mark \(subtask.title) incomplete" : "Mark \(subtask.title) complete")

                        // Title
                        Text(subtask.title)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(subtask.isCompleted ? Color.Lazyflow.textTertiary : Color.Lazyflow.textPrimary)
                            .strikethrough(subtask.isCompleted)

                        Spacer()

                        // Reorder buttons
                        if subtasks.count > 1 {
                            VStack(spacing: 0) {
                                Button {
                                    moveSubtask(from: index, direction: .up)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(index == 0 ? Color.clear : Color.Lazyflow.textTertiary)
                                }
                                .disabled(index == 0)
                                .accessibilityLabel("Move \(subtask.title) up")

                                Button {
                                    moveSubtask(from: index, direction: .down)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(index == subtasks.count - 1 ? Color.clear : Color.Lazyflow.textTertiary)
                                }
                                .disabled(index == subtasks.count - 1)
                                .accessibilityLabel("Move \(subtask.title) down")
                            }
                            .buttonStyle(.plain)
                        }

                        // Delete
                        Button {
                            deleteSubtask(subtask)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete \(subtask.title)")
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Selected Options

    private var hasSelectedOptions: Bool {
        viewModel.hasDueDate || viewModel.priority != .none || viewModel.hasReminder ||
        viewModel.hasCategorySelected || viewModel.estimatedDuration != nil ||
        viewModel.isRecurring
    }

    private var selectedOptionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if viewModel.hasDueDate, let date = viewModel.dueDate {
                    SelectedOptionChip(
                        icon: "calendar",
                        title: dateChipTitle(date: date),
                        color: date.isPast ? Color.Lazyflow.error : Color.Lazyflow.accent,
                        onRemove: { viewModel.clearDueDate() }
                    )
                }

                if viewModel.priority != .none {
                    SelectedOptionChip(
                        icon: viewModel.priority.iconName,
                        title: viewModel.priority.displayName,
                        color: viewModel.priority.color,
                        onRemove: { viewModel.priority = .none }
                    )
                }

                if viewModel.hasCategorySelected {
                    SelectedOptionChip(
                        icon: categoryDisplayIcon,
                        title: categoryDisplayName,
                        color: categoryDisplayColor,
                        onRemove: { viewModel.clearCategory() }
                    )
                }

                if let duration = viewModel.estimatedDuration {
                    SelectedOptionChip(
                        icon: "clock",
                        title: formatDuration(duration),
                        color: Color.Lazyflow.accent,
                        onRemove: { viewModel.estimatedDuration = nil }
                    )
                }

                if viewModel.hasReminder {
                    SelectedOptionChip(
                        icon: "bell.fill",
                        title: formatReminderTime(viewModel.reminderDate),
                        color: Color.Lazyflow.info,
                        onRemove: { viewModel.hasReminder = false }
                    )
                }

                if viewModel.isRecurring {
                    SelectedOptionChip(
                        icon: "repeat",
                        title: recurringDisplayTitle,
                        color: Color.Lazyflow.info,
                        onRemove: { viewModel.isRecurring = false }
                    )
                }
            }
        }
    }

    // MARK: - Display Helpers

    private var dateButtonTitle: String {
        guard viewModel.hasDueDate, let date = viewModel.dueDate else { return "Date" }
        if viewModel.hasDueTime, let time = viewModel.dueTime {
            let tf = DateFormatter()
            tf.timeStyle = .short
            tf.dateStyle = .none
            return "\(date.shortFormatted) \(tf.string(from: time))"
        }
        return date.shortFormatted
    }

    private func dateChipTitle(date: Date) -> String {
        if viewModel.hasDueTime, let time = viewModel.dueTime {
            let tf = DateFormatter()
            tf.timeStyle = .short
            tf.dateStyle = .none
            return "\(date.relativeFormatted) \(tf.string(from: time))"
        }
        return date.relativeFormatted
    }

    private var selectedListName: String {
        if let listID = viewModel.selectedListID,
           let list = listService.lists.first(where: { $0.id == listID }) {
            return list.name
        }
        return "List"
    }

    private var categoryDisplayName: String {
        if let customID = viewModel.customCategoryID,
           let custom = categoryService.getCategory(byID: customID) {
            return custom.displayName
        }
        return viewModel.category == .uncategorized ? "Category" : viewModel.category.displayName
    }

    private var categoryDisplayIcon: String {
        if let customID = viewModel.customCategoryID,
           let custom = categoryService.getCategory(byID: customID) {
            return custom.iconName
        }
        return viewModel.category.iconName
    }

    private var categoryDisplayColor: Color {
        if let customID = viewModel.customCategoryID,
           let custom = categoryService.getCategory(byID: customID) {
            return custom.color
        }
        return viewModel.category.color
    }

    private var durationDisplayTitle: String {
        if let duration = viewModel.estimatedDuration {
            return formatDuration(duration)
        }
        return "Duration"
    }

    private var recurringDisplayTitle: String {
        switch viewModel.recurringFrequency {
        case .hourly:
            return "Every \(viewModel.hourInterval)h"
        case .timesPerDay:
            return "\(viewModel.timesPerDay)x/day"
        default:
            return viewModel.recurringFrequency.displayName
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes)m"
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

    private func formatReminderTime(_ date: Date?) -> String {
        guard let date = date else { return "Remind" }
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)

        if Calendar.current.isDateInToday(date) {
            return timeString
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow \(timeString)"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        return "\(dateFormatter.string(from: date)) \(timeString)"
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

    private func deleteSubtask(_ subtask: Task) {
        taskService.deleteTask(subtask)
        loadSubtasks()
    }

    private enum MoveDirection { case up, down }

    private func moveSubtask(from index: Int, direction: MoveDirection) {
        let destination = direction == .up ? index - 1 : index + 1
        guard destination >= 0, destination < subtasks.count else { return }
        var reordered = subtasks
        reordered.swapAt(index, destination)
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

    /// Regenerate AI suggestions when user taps "Try Again"
    private func regenerateAISuggestions() {
        guard !viewModel.title.isEmpty else { return }
        isRegeneratingAI = true

        // Record the refinement request for analytics
        AILearningService.shared.recordRefinementRequest()

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
                    isRegeneratingAI = false
                }
            } catch {
                await MainActor.run {
                    isRegeneratingAI = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TaskDetailView(task: Task.sample)
}
