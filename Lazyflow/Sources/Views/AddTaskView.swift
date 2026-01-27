import SwiftUI

/// View for creating a new task
struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskViewModel
    @StateObject private var listService = TaskListService()
    @StateObject private var categoryService = CategoryService.shared
    @StateObject private var llmService = LLMService.shared
    @FocusState private var isTitleFocused: Bool

    @AppStorage("aiAutoSuggest") private var aiAutoSuggest: Bool = true

    @State private var showDatePicker = false
    @State private var showPriorityPicker = false
    @State private var showListPicker = false
    @State private var showAISuggestions = false
    @State private var aiAnalysis: TaskAnalysis?
    @State private var isAnalyzing = false
    @State private var detectedDate: Date.ParsedDateResult?
    @State private var pendingSubtasks: [String] = []
    @State private var showAddSubtaskField = false
    @State private var newSubtaskTitle = ""
    @State private var showDurationPicker = false
    @State private var showRecurringOptions = false
    @State private var showReminderPicker = false

    // Store original values before AI analysis for un-apply
    @State private var originalTitleBeforeAI: String = ""
    @State private var originalNotesBeforeAI: String = ""
    @State private var originalCategoryBeforeAI: TaskCategory = .uncategorized
    @State private var originalDurationBeforeAI: TimeInterval?
    @State private var originalPriorityBeforeAI: Priority = .none

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
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                    // Quick action buttons (2-row grid, no horizontal scroll)
                    quickActionsGrid
                        .padding(.horizontal)

                    // Duration and Recurring options (Row 3)
                    optionalActionsRow
                        .padding(.horizontal)

                    // Duration picker (expandable)
                    if showDurationPicker {
                        durationPickerSection
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Recurring options (expandable)
                    if showRecurringOptions {
                        recurringOptionsSection
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Reminder picker (expandable)
                    if showReminderPicker {
                        reminderPickerSection
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

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

                Spacer()
            }
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
                        pendingSubtasks: pendingSubtasks
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    // MARK: - Quick Actions Grid (2-row layout, no scroll)

    private var quickActionsGrid: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Row 1: Date options
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Due Date picker - shows actual date format to avoid confusion
                QuickActionButton(
                    icon: "calendar",
                    title: viewModel.hasDueDate ? (viewModel.dueDate?.shortFormatted ?? "Date") : "Date",
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

            // Row 2: Other options
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

                // Reminder
                QuickActionButton(
                    icon: "bell",
                    title: viewModel.hasReminder ? formatReminderTime(viewModel.reminderDate) : "Remind",
                    isSelected: viewModel.hasReminder || showReminderPicker,
                    color: Color.Lazyflow.info
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showReminderPicker.toggle()
                        if showReminderPicker {
                            showDurationPicker = false
                            showRecurringOptions = false
                            if !viewModel.hasReminder {
                                viewModel.hasReminder = true
                                viewModel.reminderDate = viewModel.dueDate ?? Date()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Optional Actions Row (Duration, Recurring)

    private var optionalActionsRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Duration
            QuickActionButton(
                icon: "clock",
                title: viewModel.estimatedDuration != nil ? formatDuration(viewModel.estimatedDuration!) : "Duration",
                isSelected: viewModel.estimatedDuration != nil || showDurationPicker,
                color: Color.Lazyflow.accent
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDurationPicker.toggle()
                    if showDurationPicker {
                        showRecurringOptions = false
                        showReminderPicker = false
                    }
                }
            }

            // Recurring
            QuickActionButton(
                icon: "repeat",
                title: viewModel.isRecurring ? viewModel.recurringFrequency.displayName : "Repeat",
                isSelected: viewModel.isRecurring || showRecurringOptions,
                color: Color.Lazyflow.info
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRecurringOptions.toggle()
                    if showRecurringOptions {
                        showDurationPicker = false
                        showReminderPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Duration Picker Section

    private var durationPickerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Estimated Duration")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(TaskViewModel.durationPresets, id: \.0) { preset in
                        DurationChip(
                            title: preset.0,
                            isSelected: viewModel.estimatedDuration == preset.1,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if viewModel.estimatedDuration == preset.1 {
                                        viewModel.estimatedDuration = nil
                                    } else {
                                        viewModel.estimatedDuration = preset.1
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Recurring Options Section

    private var recurringOptionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Toggle
            Toggle("Repeat this task", isOn: $viewModel.isRecurring.animation())
                .font(DesignSystem.Typography.subheadline)

            if viewModel.isRecurring {
                // Frequency picker
                HStack {
                    Text("Frequency")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textSecondary)

                    Spacer()

                    Picker("Frequency", selection: $viewModel.recurringFrequency) {
                        ForEach(RecurringFrequency.allCases) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Custom interval (for custom frequency)
                if viewModel.recurringFrequency == .custom {
                    Stepper(
                        "Every \(viewModel.recurringInterval) day\(viewModel.recurringInterval == 1 ? "" : "s")",
                        value: $viewModel.recurringInterval,
                        in: 1...365
                    )
                    .font(DesignSystem.Typography.subheadline)
                }

                // Weekday picker (for weekly frequency)
                if viewModel.recurringFrequency == .weekly {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("On days")
                            .font(DesignSystem.Typography.caption1)
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

                // Hourly options
                if viewModel.recurringFrequency == .hourly {
                    hourlyOptionsView
                }

                // Times per day options
                if viewModel.recurringFrequency == .timesPerDay {
                    timesPerDayOptionsView
                }

                // Active hours (for intraday frequencies)
                if viewModel.recurringFrequency == .hourly || viewModel.recurringFrequency == .timesPerDay {
                    activeHoursView
                }

                // End date
                Toggle("End Date", isOn: Binding(
                    get: { viewModel.recurringEndDate != nil },
                    set: { newValue in
                        if newValue {
                            viewModel.recurringEndDate = Date().addingDays(30)
                        } else {
                            viewModel.recurringEndDate = nil
                        }
                    }
                ))
                .font(DesignSystem.Typography.subheadline)

                if viewModel.recurringEndDate != nil {
                    DatePicker(
                        "Ends on",
                        selection: Binding(
                            get: { viewModel.recurringEndDate ?? Date() },
                            set: { viewModel.recurringEndDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .font(DesignSystem.Typography.subheadline)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Hourly Options View

    private var hourlyOptionsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Repeat Interval")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Every")
                    .font(DesignSystem.Typography.subheadline)

                Picker("Hours", selection: $viewModel.hourInterval) {
                    ForEach(1...12, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 60)

                Text("hour\(viewModel.hourInterval == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.subheadline)

                Spacer()
            }

            Text("e.g., \"Drink water\", \"Take a break\"")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
    }

    // MARK: - Times Per Day Options View

    private var timesPerDayOptionsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Picker("Times", selection: $viewModel.timesPerDay) {
                    ForEach(2...12, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 60)

                Text("times per day")
                    .font(DesignSystem.Typography.subheadline)

                Spacer()
            }

            // Toggle for specific times vs auto-distribute
            Toggle("Set specific times", isOn: $viewModel.useSpecificTimes.animation())
                .font(DesignSystem.Typography.subheadline)

            if viewModel.useSpecificTimes {
                specificTimesEditor
            } else {
                Text("Reminders will be evenly distributed during active hours")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
    }

    // MARK: - Specific Times Editor

    private var specificTimesEditor: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<viewModel.timesPerDay, id: \.self) { index in
                HStack {
                    Text("Time \(index + 1)")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .frame(width: 60, alignment: .leading)

                    DatePicker(
                        "",
                        selection: specificTimeBinding(for: index),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.xs)
    }

    private func specificTimeBinding(for index: Int) -> Binding<Date> {
        Binding(
            get: {
                if index < viewModel.specificTimes.count {
                    return viewModel.specificTimes[index]
                }
                // Default times distributed throughout the day
                let calendar = Calendar.current
                var components = DateComponents()
                components.hour = 8 + (index * (12 / max(viewModel.timesPerDay, 1)))
                components.minute = 0
                return calendar.date(from: components) ?? Date()
            },
            set: { newValue in
                // Ensure array has enough elements
                while viewModel.specificTimes.count <= index {
                    let calendar = Calendar.current
                    var components = DateComponents()
                    let nextIndex = viewModel.specificTimes.count
                    components.hour = 8 + (nextIndex * (12 / max(viewModel.timesPerDay, 1)))
                    components.minute = 0
                    viewModel.specificTimes.append(calendar.date(from: components) ?? Date())
                }
                viewModel.specificTimes[index] = newValue
            }
        )
    }

    // MARK: - Active Hours View

    private var activeHoursView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Active Hours")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(Color.Lazyflow.textSecondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(Color.Lazyflow.textTertiary)

                    DatePicker(
                        "",
                        selection: $viewModel.activeHoursStart,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("To")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(Color.Lazyflow.textTertiary)

                    DatePicker(
                        "",
                        selection: $viewModel.activeHoursEnd,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                Spacer()
            }

            Text("Reminders only during these hours")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Reminder Picker Section

    private var reminderPickerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Toggle
            Toggle("Set Reminder", isOn: $viewModel.hasReminder.animation())
                .font(DesignSystem.Typography.subheadline)

            if viewModel.hasReminder {
                // Date and Time picker
                DatePicker(
                    "Remind at",
                    selection: Binding(
                        get: { viewModel.reminderDate ?? Date() },
                        set: { viewModel.reminderDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(DesignSystem.Typography.subheadline)

                // Quick options
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Quick Options")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ReminderQuickOption(title: "Morning", time: "9:00 AM") {
                            setReminderTime(hour: 9, minute: 0)
                        }
                        ReminderQuickOption(title: "Noon", time: "12:00 PM") {
                            setReminderTime(hour: 12, minute: 0)
                        }
                        ReminderQuickOption(title: "Evening", time: "6:00 PM") {
                            setReminderTime(hour: 18, minute: 0)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func setReminderTime(hour: Int, minute: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: viewModel.reminderDate ?? Date())
        components.hour = hour
        components.minute = minute
        if let newDate = calendar.date(from: components) {
            viewModel.reminderDate = newDate
        }
    }

    // MARK: - Subtasks Section

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header with add button
            HStack {
                Label("Subtasks", systemImage: "list.bullet.indent")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                Spacer()

                if !showAddSubtaskField {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddSubtaskField = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.Lazyflow.accent)
                    }
                }
            }

            // Add subtask field
            if showAddSubtaskField {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("Add subtask", text: $newSubtaskTitle)
                        .font(DesignSystem.Typography.body)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            addSubtask()
                        }

                    Button {
                        addSubtask()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(newSubtaskTitle.isEmpty ? Color.Lazyflow.textTertiary : Color.Lazyflow.accent)
                    }
                    .disabled(newSubtaskTitle.isEmpty)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddSubtaskField = false
                            newSubtaskTitle = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }

            // List of pending subtasks
            if !pendingSubtasks.isEmpty {
                VStack(spacing: 4) {
                    ForEach(pendingSubtasks, id: \.self) { subtask in
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "circle")
                                .font(.system(size: 14))
                                .foregroundColor(Color.Lazyflow.textTertiary)

                            Text(subtask)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    pendingSubtasks.removeAll { $0 == subtask }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.Lazyflow.textTertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            pendingSubtasks.append(trimmed)
            newSubtaskTitle = ""
        }
    }

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
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                }
            }
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

    private var selectedListName: String {
        if let listID = viewModel.selectedListID,
           let list = listService.lists.first(where: { $0.id == listID }) {
            return list.name
        }
        return "List"
    }

    // MARK: - Category Display

    private var categoryDisplayName: String {
        // Custom category takes precedence
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

    // MARK: - Selected Options

    private var hasSelectedOptions: Bool {
        viewModel.hasDueDate || viewModel.priority != .none || viewModel.hasReminder ||
        viewModel.hasCategorySelected || viewModel.estimatedDuration != nil ||
        viewModel.isRecurring || !pendingSubtasks.isEmpty
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

    private var selectedOptionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if viewModel.hasDueDate, let date = viewModel.dueDate {
                    SelectedOptionChip(
                        icon: "calendar",
                        title: date.relativeFormatted,
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

                if !pendingSubtasks.isEmpty {
                    SelectedOptionChip(
                        icon: "list.bullet",
                        title: "\(pendingSubtasks.count) subtask\(pendingSubtasks.count == 1 ? "" : "s")",
                        color: Color.Lazyflow.accent,
                        onRemove: { pendingSubtasks.removeAll() }
                    )
                }
            }
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

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionButtonContent(icon: icon, title: title, isSelected: isSelected, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickActionButtonContent: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(isSelected ? color : Color.Lazyflow.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            isSelected
                ? color.opacity(0.15)
                : Color.secondary.opacity(0.1)
        )
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

// MARK: - Selected Option Chip

struct SelectedOptionChip: View {
    let icon: String
    let title: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .font(DesignSystem.Typography.caption1)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(DesignSystem.CornerRadius.full)
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date?
    @Binding var hasDate: Bool
    @Binding var selectedTime: Date?
    @Binding var hasTime: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Quick options
                HStack(spacing: DesignSystem.Spacing.md) {
                    DateQuickOption(title: "Today", date: Date()) {
                        selectedDate = Date()
                        hasDate = true
                    }
                    DateQuickOption(title: "Tomorrow", date: Date().addingDays(1)) {
                        selectedDate = Date().addingDays(1)
                        hasDate = true
                    }
                    DateQuickOption(title: "Next Week", date: Date().addingDays(7)) {
                        selectedDate = Date().addingDays(7)
                        hasDate = true
                    }
                }
                .padding(.horizontal)

                Divider()

                // Date picker
                DatePicker(
                    "Select Date",
                    selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: {
                            selectedDate = $0
                            hasDate = true
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                // Time toggle
                Toggle("Add Time", isOn: $hasTime)
                    .padding(.horizontal)

                if hasTime {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { selectedTime ?? Date() },
                            set: { selectedTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasDate {
                        Button("Clear") {
                            selectedDate = nil
                            hasDate = false
                            selectedTime = nil
                            hasTime = false
                            dismiss()
                        }
                        .foregroundColor(Color.Lazyflow.error)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct DateQuickOption: View {
    let title: String
    let date: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Text(date.shortFormatted)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - List Picker Sheet

struct ListPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedListID: UUID?
    let lists: [TaskList]

    var body: some View {
        NavigationStack {
            List {
                ForEach(lists) { list in
                    Button {
                        selectedListID = list.id
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: list.icon)
                                .foregroundColor(list.color)
                                .frame(width: 28)

                            Text(list.name)
                                .foregroundColor(Color.Lazyflow.textPrimary)

                            Spacer()

                            if selectedListID == list.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.Lazyflow.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select List")
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
}

// MARK: - AI Suggestions Sheet

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
    let pendingSubtasks: [String]  // Initial value from parent

    @State private var titleApplied = false
    @State private var descriptionApplied = false
    @State private var categoryApplied = false
    @State private var durationApplied = false
    @State private var priorityApplied = false
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

struct SuggestionCard<Action: View>: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)

                    Text(value)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                }
            }

            Spacer()

            action()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal)
    }
}

// MARK: - Apply Button

struct ApplyButton: View {
    let isApplied: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isApplied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(isApplied ? "Applied" : "Apply")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isApplied ? .white : color)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isApplied ? color : color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .disabled(isApplied)
        .animation(.easeInOut(duration: 0.2), value: isApplied)
        .accessibilityIdentifier(isApplied ? "Applied" : "Apply")
    }
}

// MARK: - Toggle Apply Button (can un-apply)

struct ToggleApplyButton: View {
    @Binding var isApplied: Bool
    let color: Color
    let onApply: () -> Void
    let onUnapply: () -> Void

    var body: some View {
        Button {
            if isApplied {
                onUnapply()
                isApplied = false
            } else {
                onApply()
                isApplied = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isApplied ? "checkmark" : "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(isApplied ? "Applied" : "Apply")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isApplied ? .white : color)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isApplied ? color : color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .animation(.easeInOut(duration: 0.2), value: isApplied)
        .accessibilityLabel(isApplied ? "Un-apply suggestion" : "Apply suggestion")
    }
}

// MARK: - Detected Date Banner

struct DetectedDateBanner: View {
    let date: Date
    let time: Date?
    let matchedText: String
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16))
                .foregroundColor(Color.Lazyflow.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Date detected: \"\(matchedText)\"")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                HStack(spacing: 4) {
                    Text(date.relativeFormatted)
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)

                    if let time = time {
                        Text("at \(time.timeFormatted)")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            }

            Spacer()

            Button(action: onApply) {
                Text("Apply")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(Color.Lazyflow.accent)
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.Lazyflow.accent.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
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

// MARK: - Reminder Quick Option

struct ReminderQuickOption: View {
    let title: String
    let time: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.medium)
                Text(time)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    AddTaskView()
}
