import SwiftUI
import LazyflowCore
import LazyflowUI

/// View for creating a new task
struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TaskViewModel
    @State private var listService = TaskListService.shared
    @State private var categoryService = CategoryService.shared
    private var llmService = LLMService.shared
    @FocusState private var isTitleFocused: Bool

    @AppStorage(AppConstants.StorageKey.aiAutoSuggest) private var aiAutoSuggest: Bool = true

    @State var showDatePicker = false
    @State var showTimeBlockSheet = false
    @State var showListPicker = false
    @State var showAISuggestions = false
    @State var aiAnalysis: TaskAnalysis?
    @State var isAnalyzing = false
    @State var detectedDate: Date.ParsedDateResult?
    @State var pendingSubtasks: [String] = []
    @State var showAddSubtaskField = false
    @State var newSubtaskTitle = ""
    @State var showRecurringSheet = false
    @State var showReminderSheet = false

    // Store original values before AI analysis for un-apply
    @State private var originalTitleBeforeAI: String = ""
    @State private var originalNotesBeforeAI: String = ""
    @State private var originalCategoryBeforeAI: TaskCategory = .uncategorized
    @State private var originalDurationBeforeAI: TimeInterval?
    @State private var originalPriorityBeforeAI: Priority = .none

    // Track if AI suggestions were shown for implicit feedback
    @State private var aiSuggestionsWereShown: Bool = false

    // Track if AI is regenerating suggestions
    @State private var isRegeneratingAI: Bool = false

    // Internal accessors for extensions in other files
    var addTaskViewModel: TaskViewModel { viewModel }
    var addTaskListService: TaskListService { listService }
    var addTaskCategoryService: CategoryService { categoryService }

    init(
        defaultDueDate: Date? = nil,
        defaultListID: UUID? = nil,
        defaultCategory: TaskCategory? = nil,
        defaultCustomCategoryID: UUID? = nil
    ) {
        let vm = TaskViewModel()
        if let date = defaultDueDate {
            vm.hasDueDate = true
            vm.dueDate = date
        }
        if let listID = defaultListID {
            vm.selectedListID = listID
        }
        if let customCategoryID = defaultCustomCategoryID {
            vm.selectCustomCategory(customCategoryID)
        } else if let category = defaultCategory {
            vm.selectSystemCategory(category)
        }
        _viewModel = State(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Main input area
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Title field with AI button
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        TextField("What do you need to do?", text: $viewModel.title, axis: .vertical)
                            .font(DesignSystem.Typography.title3)
                            .focused($isTitleFocused)
                            .lineLimit(1...3)
                            .onChange(of: viewModel.title) { _, newValue in
                                detectDateInTitle(newValue)
                            }

                        // AI Suggest button (contextual, next to title)
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

                    // Detected date suggestion
                    if let detected = detectedDate, !viewModel.hasDueDate {
                        DetectedDateBanner(
                            date: detected.date,
                            time: detected.time,
                            matchedText: detected.matchedText,
                            onApply: {
                                applyDetectedDate(detected)
                            },
                            onDismiss: {
                                detectedDate = nil
                            }
                        )
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Notes field
                    TextField("Add notes", text: $viewModel.notes, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .lineLimit(1...4)
                        .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Quick action buttons (3-row grid)
                    quickActionsGrid
                        .padding(.horizontal)

                    // Subtasks section
                    subtasksSection
                        .padding(.horizontal)

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
                }
                .padding(.bottom, DesignSystem.Spacing.lg)
                .background(Color.adaptiveSurface)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.adaptiveBackground)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if let savedTask = viewModel.save() {
                            // Record AI corrections after successful save (implicit feedback)
                            recordAICorrections()

                            // Create subtasks if any were selected from AI suggestions
                            if !pendingSubtasks.isEmpty {
                                let taskService = TaskService.shared
                                taskService.createSubtasks(titles: pendingSubtasks, parentTaskID: savedTask.id)
                            }
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(
                    selectedDate: $viewModel.dueDate,
                    hasDate: $viewModel.hasDueDate
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTimeBlockSheet) {
                TimeBlockSheet(
                    selectedDate: $viewModel.dueDate,
                    hasDate: $viewModel.hasDueDate,
                    selectedTime: $viewModel.dueTime,
                    hasTime: $viewModel.hasDueTime,
                    estimatedDuration: $viewModel.estimatedDuration
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showListPicker) {
                ListPickerSheet(
                    selectedListID: $viewModel.selectedListID,
                    lists: listService.lists
                )
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
                            pendingSubtasks = subtasks
                        },
                        onCreateCategory: { proposedCategory in
                            // Check if category with this name already exists (case-insensitive)
                            if let existingCategory = categoryService.getCategory(byName: proposedCategory.name) {
                                viewModel.customCategoryID = existingCategory.id
                            } else {
                                // Create the new category and assign it to the task
                                let newCategory = categoryService.createCategory(
                                    name: proposedCategory.name,
                                    colorHex: proposedCategory.colorHex,
                                    iconName: proposedCategory.iconName
                                )
                                viewModel.customCategoryID = newCategory.id
                            }
                            viewModel.category = .uncategorized  // Custom categories use uncategorized as base
                        },
                        onTryAgain: {
                            regenerateAISuggestions()
                        },
                        pendingSubtasks: pendingSubtasks,
                        isRegenerating: isRegeneratingAI
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
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
                    id: UUID(),
                    title: viewModel.title,
                    notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
                    dueDate: viewModel.hasDueDate ? viewModel.dueDate : nil,
                    dueTime: viewModel.hasDueTime ? viewModel.dueTime : nil,
                    reminderDate: nil,
                    isCompleted: false,
                    isArchived: false,
                    priority: viewModel.priority,
                    listID: viewModel.selectedListID,
                    linkedEventID: nil,
                    estimatedDuration: nil,
                    completedAt: nil,
                    createdAt: Date(),
                    updatedAt: Date(),
                    recurringRule: nil
                )

                let analysis = try await llmService.analyzeTask(tempTask)

                await MainActor.run {
                    aiAnalysis = analysis
                    showAISuggestions = true
                    isAnalyzing = false
                    aiSuggestionsWereShown = true
                    AILearningService.shared.recordImpression()
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
                    id: UUID(),
                    title: viewModel.title,
                    notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
                    dueDate: viewModel.hasDueDate ? viewModel.dueDate : nil,
                    dueTime: viewModel.hasDueTime ? viewModel.dueTime : nil,
                    reminderDate: nil,
                    isCompleted: false,
                    isArchived: false,
                    priority: viewModel.priority,
                    listID: viewModel.selectedListID,
                    linkedEventID: nil,
                    estimatedDuration: nil,
                    completedAt: nil,
                    createdAt: Date(),
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

    // MARK: - AI Feedback Recording

    /// Records corrections when user modifies AI suggestions (implicit feedback)
    private func recordAICorrections() {
        // Only record if AI suggestions were shown and we have analysis data
        guard aiSuggestionsWereShown, let analysis = aiAnalysis else { return }

        let learningService = AILearningService.shared
        let taskTitle = viewModel.title

        // Compare AI suggested category with user's final choice (including custom categories)
        let aiCategoryName: String?
        let userCategoryName: String

        if let aiCustomID = analysis.suggestedCustomCategoryID,
           let aiCustomCategory = categoryService.getCategory(byID: aiCustomID) {
            aiCategoryName = aiCustomCategory.name
        } else if analysis.suggestedCategory != .uncategorized {
            aiCategoryName = analysis.suggestedCategory.displayName
        } else {
            aiCategoryName = nil
        }

        if let userCustomID = viewModel.customCategoryID,
           let userCustomCategory = categoryService.getCategory(byID: userCustomID) {
            userCategoryName = userCustomCategory.name
        } else {
            userCategoryName = viewModel.category.displayName
        }

        if let aiCategory = aiCategoryName, aiCategory != userCategoryName {
            learningService.recordCorrection(
                field: .category,
                originalSuggestion: aiCategory,
                userChoice: userCategoryName,
                taskTitle: taskTitle
            )
        }

        // Compare AI suggested priority with user's final choice
        if analysis.suggestedPriority != viewModel.priority {
            learningService.recordCorrection(
                field: .priority,
                originalSuggestion: analysis.suggestedPriority.displayName,
                userChoice: viewModel.priority.displayName,
                taskTitle: taskTitle
            )
        }

        // Compare AI suggested duration with user's final choice
        let suggestedDuration = TimeInterval(analysis.estimatedMinutes * 60)
        if let userDuration = viewModel.estimatedDuration,
           suggestedDuration != userDuration {
            let suggestedMinutes = analysis.estimatedMinutes
            let userMinutes = Int(userDuration / 60)
            learningService.recordCorrection(
                field: .duration,
                originalSuggestion: "\(suggestedMinutes) min",
                userChoice: "\(userMinutes) min",
                taskTitle: taskTitle
            )
        } else if viewModel.estimatedDuration == nil && analysis.estimatedMinutes > 0 {
            // User cleared the duration that AI suggested
            learningService.recordCorrection(
                field: .duration,
                originalSuggestion: "\(analysis.estimatedMinutes) min",
                userChoice: "none",
                taskTitle: taskTitle
            )
        }
    }

    // MARK: - Natural Language Date Detection

    private func detectDateInTitle(_ title: String) {
        // Don't detect if already has a due date set
        guard !viewModel.hasDueDate else {
            detectedDate = nil
            return
        }

        // Parse date from title
        withAnimation(.easeInOut(duration: 0.2)) {
            detectedDate = Date.parse(from: title)
        }
    }

    private func applyDetectedDate(_ detected: Date.ParsedDateResult) {
        withAnimation {
            // Set the due date
            viewModel.hasDueDate = true
            viewModel.dueDate = detected.date

            // Set time if detected
            if let time = detected.time {
                viewModel.hasDueTime = true
                viewModel.dueTime = time
            }

            // Clean the title by removing the date portion
            viewModel.title = detected.cleanedTitle(from: viewModel.title)

            // Clear the detection
            detectedDate = nil
        }
    }

    // MARK: - Display Helpers

    var dateButtonTitle: String {
        guard viewModel.hasDueDate, let date = viewModel.dueDate else { return "Date" }
        return date.shortFormatted
    }

    var timeBlockButtonTitle: String {
        let hasTime = viewModel.hasDueTime
        let hasDuration = viewModel.estimatedDuration != nil

        if hasTime, let time = viewModel.dueTime, hasDuration, let duration = viewModel.estimatedDuration {
            let tf = DateFormatter()
            tf.timeStyle = .short
            tf.dateStyle = .none
            return "\(tf.string(from: time)) · \(formatDuration(duration))"
        } else if hasTime, let time = viewModel.dueTime {
            let tf = DateFormatter()
            tf.timeStyle = .short
            tf.dateStyle = .none
            return tf.string(from: time)
        } else if hasDuration, let duration = viewModel.estimatedDuration {
            return formatDuration(duration)
        }
        return "Time Block"
    }

    func dateChipTitle(date: Date) -> String {
        return date.relativeFormatted
    }

    var timeBlockChipTitle: String {
        var parts: [String] = []
        if viewModel.hasDueTime, let time = viewModel.dueTime {
            let tf = DateFormatter()
            tf.timeStyle = .short
            tf.dateStyle = .none
            parts.append(tf.string(from: time))
        }
        if let duration = viewModel.estimatedDuration {
            parts.append(formatDuration(duration))
        }
        return parts.joined(separator: " · ")
    }

    var selectedListName: String {
        if let listID = viewModel.selectedListID,
           let list = listService.lists.first(where: { $0.id == listID }) {
            return list.name
        }
        return "List"
    }

    // MARK: - Category Display

    var categoryDisplayName: String {
        // Custom category takes precedence
        if let customID = viewModel.customCategoryID,
           let custom = categoryService.getCategory(byID: customID) {
            return custom.displayName
        }
        return viewModel.category == .uncategorized ? "Category" : viewModel.category.displayName
    }

    var categoryDisplayIcon: String {
        if let customID = viewModel.customCategoryID,
           let custom = categoryService.getCategory(byID: customID) {
            return custom.iconName
        }
        return viewModel.category.iconName
    }

    var categoryDisplayColor: Color {
        if let customID = viewModel.customCategoryID,
           let custom = categoryService.getCategory(byID: customID) {
            return custom.color
        }
        return viewModel.category.color
    }

    // MARK: - Selected Options

    var hasSelectedOptions: Bool {
        viewModel.hasDueDate || viewModel.priority != .none || viewModel.hasReminder ||
        viewModel.hasCategorySelected || viewModel.estimatedDuration != nil ||
        viewModel.isRecurring || !pendingSubtasks.isEmpty
    }

    var recurringDisplayTitle: String {
        switch viewModel.recurringFrequency {
        case .hourly:
            return "Every \(viewModel.hourInterval)h"
        case .timesPerDay:
            return "\(viewModel.timesPerDay)x/day"
        default:
            return viewModel.recurringFrequency.displayName
        }
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
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

    func formatReminderTime(_ date: Date?) -> String {
        guard let date = date else { return "Remind" }
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)

        // If today, just show time
        if Calendar.current.isDateInToday(date) {
            return timeString
        }
        // If tomorrow, show "Tomorrow" + time
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow \(timeString)"
        }
        // Otherwise show short date + time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        return "\(dateFormatter.string(from: date)) \(timeString)"
    }
}

// MARK: - Preview

#Preview {
    AddTaskView()
}
