import SwiftUI

/// Main Today view showing overdue and today's tasks
struct TodayView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = TodayViewModel()
    @StateObject private var prioritizationService = PrioritizationService.shared
    @StateObject private var conflictService = ConflictDetectionService.shared
    @StateObject private var rescheduleService = SmartRescheduleService.shared
    @State private var showAddTask = false
    @State private var taskToSchedule: Task?
    @State private var taskSuggestion: TaskSuggestion?
    @State private var showConflictSheet = false
    @State private var selectedConflict: TaskConflict?
    @State private var showBatchReschedule = false
    @State private var undoAction: UndoAction?
    @State private var undoSnapshot: Task?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: No NavigationStack (provided by split view)
                todayContent
                    .navigationTitle("Today")
                    .toolbar { addTaskToolbar }
            } else {
                // iPhone: Full NavigationStack
                NavigationStack {
                    todayContent
                        .navigationTitle("Today")
                        .toolbar { addTaskToolbar }
                }
            }
        }
        .onAppear { scanForConflicts() }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(defaultDueDate: Date())
        }
        .sheet(item: $viewModel.selectedTask) { task in
            TaskDetailView(task: task)
        }
        .sheet(item: $taskToSchedule) { task in
            TimeBlockSheet(
                task: task,
                startTime: defaultScheduleTime(),
                onConfirm: { startTime, duration in
                    scheduleTask(task, startTime: startTime, duration: duration)
                }
            )
        }
        .sheet(isPresented: $showConflictSheet) {
            if let conflict = selectedConflict {
                ConflictResolutionSheet(
                    conflict: conflict,
                    onReschedule: { option in
                        applyReschedule(option: option, to: conflict.task)
                        showConflictSheet = false
                    },
                    onPushToTomorrow: {
                        pushToTomorrow(conflict.task)
                        showConflictSheet = false
                    },
                    onDismiss: {
                        showConflictSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showBatchReschedule) {
            BatchRescheduleSheet(
                conflicts: conflictService.detectedConflicts,
                onResolveAll: { batch in
                    _ = rescheduleService.applyBatchReschedule(batch: batch, taskService: TaskService.shared)
                    showBatchReschedule = false
                    scanForConflicts()
                },
                onDismiss: {
                    showBatchReschedule = false
                }
            )
        }
        .undoToast(action: $undoAction) { action in
            handleUndo(action)
        }
    }

    // MARK: - Undo Handling

    private func handleUndo(_ action: UndoAction) {
        guard let snapshot = undoSnapshot else { return }
        let taskService = TaskService.shared

        switch action {
        case .completed:
            // Restore to uncompleted state
            var restoredTask = snapshot
            restoredTask.isCompleted = false
            taskService.updateTask(restoredTask)
        case .deleted:
            // Re-add the deleted task
            taskService.createTask(
                title: snapshot.title,
                notes: snapshot.notes,
                dueDate: snapshot.dueDate,
                dueTime: snapshot.dueTime,
                reminderDate: snapshot.reminderDate,
                priority: snapshot.priority,
                category: snapshot.category,
                listID: snapshot.listID,
                estimatedDuration: snapshot.estimatedDuration,
                recurringRule: snapshot.recurringRule
            )
        case .movedToToday, .pushedToTomorrow:
            // Restore original due date
            taskService.updateTask(snapshot)
        }
        undoSnapshot = nil
        viewModel.refreshTasks()
    }

    private func showUndoToast(_ action: UndoAction, snapshot: Task) {
        undoSnapshot = snapshot
        undoAction = action
    }

    @ToolbarContentBuilder
    private var addTaskToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showAddTask = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.Taskweave.accent)
            }
            .accessibilityLabel("Add task")
        }
    }

    private var todayContent: some View {
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.totalTaskCount == 0 && viewModel.completedTaskCount == 0 {
                emptyStateView
            } else {
                taskListView
            }
        }
        .refreshable {
            viewModel.refreshTasks()
            scanForConflicts()
        }
    }

    // MARK: - Conflict Handling

    private func scanForConflicts() {
        let allTasks = viewModel.overdueTasks + viewModel.todayTasks
        _ = conflictService.scanForConflicts(tasks: allTasks)
    }

    private func applyReschedule(option: RescheduleOption, to task: Task) {
        _ = rescheduleService.applyReschedule(option: option, to: task, taskService: TaskService.shared)
        scanForConflicts()
    }

    private func pushToTomorrow(_ task: Task) {
        _ = rescheduleService.pushTaskToTomorrow(task, taskService: TaskService.shared)
        scanForConflicts()
    }

    private func moveToToday(_ task: Task) {
        viewModel.updateTaskDueDate(task, dueDate: Date())
        scanForConflicts()
    }

    // MARK: - Conflicts Banner

    private var conflictsBanner: some View {
        let conflicts = conflictService.detectedConflicts
        let highSeverityCount = conflicts.filter { $0.severity == .high }.count

        return Button {
            if conflicts.count == 1, let first = conflicts.first {
                selectedConflict = first
                showConflictSheet = true
            } else {
                showBatchReschedule = true
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: highSeverityCount > 0 ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(highSeverityCount > 0 ? Color.Taskweave.error : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(conflicts.count) Schedule Conflict\(conflicts.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Taskweave.textPrimary)

                    if let first = conflicts.first {
                        Text(first.conflictDescription)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Taskweave.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text("Resolve")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.accent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(highSeverityCount > 0 ? Color.Taskweave.error.opacity(0.1) : Color.orange.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(highSeverityCount > 0 ? Color.Taskweave.error.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ConflictsBanner")
    }

    // MARK: - Scheduling

    private func scheduleTaskAction(_ task: Task) {
        taskToSchedule = task
    }

    private func defaultScheduleTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        // Default to next hour
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        if let nextHour = calendar.date(from: components)?.addingTimeInterval(3600) {
            return nextHour
        }
        return now
    }

    private func scheduleTask(_ task: Task, startTime: Date, duration: TimeInterval) {
        do {
            _ = try CalendarService.shared.createTimeBlock(for: task, startDate: startTime, duration: duration)
        } catch {
            print("Failed to create time block: \(error)")
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "All Clear!",
            message: "You have no tasks due today.\nEnjoy your day or add a new task.",
            actionTitle: "Add Task"
        ) {
            showAddTask = true
        }
    }

    private var taskListView: some View {
        List {
            // Progress header
            Section {
                progressHeader
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Conflicts banner
            if !conflictService.detectedConflicts.isEmpty {
                Section {
                    conflictsBanner
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.adaptiveBackground)
                .listRowSeparator(.hidden)
            }

            // What should I do next?
            if let suggestedTask = prioritizationService.suggestedNextTask {
                Section {
                    nextTaskSuggestionCard(suggestedTask)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.adaptiveBackground)
                .listRowSeparator(.hidden)
            }

            // Overdue section
            if !viewModel.overdueTasks.isEmpty {
                taskSection(
                    title: "Overdue",
                    tasks: viewModel.overdueTasks,
                    accentColor: Color.Taskweave.error
                )
            }

            // Today section
            if !viewModel.todayTasks.isEmpty {
                taskSection(
                    title: "Today",
                    tasks: viewModel.todayTasks,
                    accentColor: Color.Taskweave.accent
                )
            }

            // Completed section
            if !viewModel.completedTodayTasks.isEmpty {
                completedSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground)
    }

    // MARK: - Next Task Suggestion Card

    private func nextTaskSuggestionCard(_ task: Task) -> some View {
        Button {
            fetchSuggestionDetails(for: task)
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color.Taskweave.accent)

                    Text("What should I do next?")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Taskweave.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Taskweave.textTertiary)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(task.priority.color)
                        .frame(width: 8, height: 8)

                    Text(task.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textPrimary)
                        .lineLimit(1)
                }

                if let dueDate = task.dueDate {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(dueDate.relativeFormatted)
                            .font(DesignSystem.Typography.caption1)
                    }
                    .foregroundColor(dueDate < Date() ? Color.Taskweave.error : Color.Taskweave.textSecondary)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.Taskweave.accent.opacity(0.1), Color.Taskweave.accent.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(DesignSystem.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(Color.Taskweave.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(item: $taskSuggestion) { suggestion in
            NextTaskSuggestionSheet(suggestion: suggestion) {
                viewModel.selectedTask = suggestion.task
                taskSuggestion = nil
            } onSchedule: {
                taskToSchedule = suggestion.task
                taskSuggestion = nil
            } onStart: {
                // Mark as started / start timer
                taskSuggestion = nil
            }
        }
    }

    private func fetchSuggestionDetails(for task: Task) {
        _Concurrency.Task {
            if let suggestion = await prioritizationService.getNextTaskSuggestion() {
                await MainActor.run {
                    taskSuggestion = suggestion
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(Date().fullFormatted)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)

                Spacer()

                Text("\(viewModel.completedTaskCount)/\(viewModel.totalTaskCount + viewModel.completedTaskCount) done")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Taskweave.accent)
                        .frame(width: geometry.size.width * viewModel.progressPercentage, height: 8)
                        .animation(.spring(), value: viewModel.progressPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func taskSection(title: String, tasks: [Task], accentColor: Color) -> some View {
        Section {
            ForEach(tasks) { task in
                TaskRowView(
                    task: task,
                    onToggle: {
                        showUndoToast(.completed(task), snapshot: task)
                        viewModel.toggleTaskCompletion(task)
                    },
                    onTap: { viewModel.selectedTask = task },
                    onSchedule: { scheduleTaskAction($0) },
                    onPushToTomorrow: { task in
                        showUndoToast(.pushedToTomorrow(task), snapshot: task)
                        pushToTomorrow(task)
                    },
                    onMoveToToday: { task in
                        showUndoToast(.movedToToday(task), snapshot: task)
                        moveToToday(task)
                    },
                    onPriorityChange: { viewModel.updateTaskPriority($0, priority: $1) },
                    onDueDateChange: { viewModel.updateTaskDueDate($0, dueDate: $1) },
                    onDelete: { task in
                        showUndoToast(.deleted(task), snapshot: task)
                        viewModel.deleteTask(task)
                    },
                    onStartWorking: { viewModel.startWorking(on: $0) },
                    onStopWorking: { viewModel.stopWorking(on: $0) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.adaptiveBackground)
                .listRowSeparator(.hidden)
            }
        } header: {
            HStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textPrimary)

                Text("\(tasks.count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)

                Spacer()
            }
        }
    }

    private var completedSection: some View {
        Section {
            ForEach(viewModel.completedTodayTasks) { task in
                TaskRowView(
                    task: task,
                    onToggle: { viewModel.toggleTaskCompletion(task) },
                    onTap: { viewModel.selectedTask = task },
                    onSchedule: nil,
                    onPushToTomorrow: nil,
                    onPriorityChange: { viewModel.updateTaskPriority($0, priority: $1) },
                    onDueDateChange: { viewModel.updateTaskDueDate($0, dueDate: $1) },
                    onDelete: { viewModel.deleteTask($0) },
                    onStartWorking: nil,
                    onStopWorking: nil
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.adaptiveBackground)
                .listRowSeparator(.hidden)
            }
        } header: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.Taskweave.success)

                Text("Completed")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textSecondary)

                Text("\(viewModel.completedTodayTasks.count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textTertiary)

                Spacer()
            }
        }
    }

}

// MARK: - Next Task Suggestion Sheet

struct NextTaskSuggestionSheet: View {
    let suggestion: TaskSuggestion
    let onViewDetails: () -> Void
    let onSchedule: () -> Void
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Score indicator
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ZStack {
                            Circle()
                                .stroke(Color.Taskweave.accent.opacity(0.2), lineWidth: 8)
                                .frame(width: 100, height: 100)

                            Circle()
                                .trim(from: 0, to: CGFloat(suggestion.score) / 100)
                                .stroke(Color.Taskweave.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 0) {
                                Text("\(suggestion.scorePercentage)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color.Taskweave.accent)
                                Text("Priority")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundColor(Color.Taskweave.textSecondary)
                            }
                        }

                        Text("This is your top priority right now")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.lg)

                    // Task card
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: suggestion.task.priority.iconName)
                                .foregroundColor(suggestion.task.priority.color)
                            Text(suggestion.task.title)
                                .font(DesignSystem.Typography.title3)
                                .foregroundColor(Color.Taskweave.textPrimary)
                        }

                        if let dueDate = suggestion.task.dueDate {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "calendar")
                                Text(dueDate.relativeFormatted)
                            }
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(dueDate < Date() ? Color.Taskweave.error : Color.Taskweave.textSecondary)
                        }

                        if let duration = suggestion.task.estimatedDuration {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "clock")
                                Text("\(Int(duration / 60)) min")
                            }
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Taskweave.textSecondary)
                        }

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: suggestion.task.category.iconName)
                            Text(suggestion.task.category.displayName)
                        }
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Taskweave.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.adaptiveSurface)
                    .cornerRadius(DesignSystem.CornerRadius.large)
                    .padding(.horizontal)

                    // Reasons
                    if !suggestion.reasons.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Why this task?")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(Color.Taskweave.textPrimary)

                            ForEach(suggestion.reasons, id: \.self) { reason in
                                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.Taskweave.success)
                                        .font(.system(size: 14))
                                    Text(reason)
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(Color.Taskweave.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // AI Insight
                    if let insight = suggestion.aiInsight {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color.Taskweave.accent)
                                Text("AI Insight")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(Color.Taskweave.textPrimary)
                            }

                            Text(insight)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Taskweave.textSecondary)
                                .italic()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.Taskweave.accent.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)

                    // Action buttons
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Button {
                            onStart()
                        } label: {
                            Label("Start Now", systemImage: "play.fill")
                                .font(DesignSystem.Typography.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.Taskweave.accent)
                                .foregroundColor(.white)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                        }

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Button {
                                onSchedule()
                            } label: {
                                Label("Schedule", systemImage: "calendar.badge.plus")
                                    .font(DesignSystem.Typography.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.adaptiveSurface)
                                    .foregroundColor(Color.Taskweave.textPrimary)
                                    .cornerRadius(DesignSystem.CornerRadius.medium)
                            }

                            Button {
                                onViewDetails()
                            } label: {
                                Label("Details", systemImage: "info.circle")
                                    .font(DesignSystem.Typography.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.adaptiveSurface)
                                    .foregroundColor(Color.Taskweave.textPrimary)
                                    .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Next Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Conflict Resolution Sheet

struct ConflictResolutionSheet: View {
    let conflict: TaskConflict
    let onReschedule: (RescheduleOption) -> Void
    let onPushToTomorrow: () -> Void
    let onDismiss: () -> Void

    @StateObject private var rescheduleService = SmartRescheduleService.shared
    @Environment(\.dismiss) private var dismiss

    private var suggestion: RescheduleSuggestion {
        rescheduleService.suggestReschedule(for: conflict)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Conflict summary
                    conflictSummaryCard

                    // Recommended action
                    if let recommended = suggestion.recommendedOption {
                        recommendedActionCard(recommended)
                    }

                    // Other options
                    if suggestion.options.count > 1 {
                        otherOptionsSection
                    }

                    // Quick actions
                    quickActionsSection

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var conflictSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Severity indicator
            HStack {
                Image(systemName: conflict.severity.systemImage)
                    .foregroundColor(severityColor)
                Text("\(conflict.severity.displayName) Severity")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(severityColor)
                Spacer()
            }

            Divider()

            // Task info
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(Color.Taskweave.accent)
                VStack(alignment: .leading) {
                    Text("Task")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Taskweave.textTertiary)
                    Text(conflict.task.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textPrimary)
                }
                Spacer()
            }

            // Conflicting event info
            if let event = conflict.conflictingEvent {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Conflicts with")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Taskweave.textTertiary)
                        Text(event.title)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Taskweave.textPrimary)
                        Text(event.formattedTimeRange)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }
                    Spacer()
                }
            }

            // Overlap info
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(Color.Taskweave.error)
                Text(conflict.formattedOverlap)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textSecondary)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func recommendedActionCard(_ option: RescheduleOption) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Color.Taskweave.accent)
                Text("Recommended")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.accent)
            }

            Button {
                onReschedule(option)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.formattedTime)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(Color.Taskweave.textPrimary)
                        Text(option.reason)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Taskweave.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.Taskweave.accent)
                }
                .padding()
                .background(Color.Taskweave.accent.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .buttonStyle(.plain)
        }
    }

    private var otherOptionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Other Options")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Taskweave.textPrimary)

            ForEach(suggestion.options.dropFirst().prefix(3)) { option in
                Button {
                    onReschedule(option)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.formattedTime)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Taskweave.textPrimary)
                            Text(option.reason)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Taskweave.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.Taskweave.textTertiary)
                    }
                    .padding()
                    .background(Color.adaptiveSurface)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Quick Actions")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Taskweave.textPrimary)

            Button {
                onPushToTomorrow()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.to.line")
                        .foregroundColor(Color.Taskweave.accent)
                    Text("Push to Tomorrow")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Taskweave.textPrimary)
                    Spacer()
                }
                .padding()
                .background(Color.adaptiveSurface)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("PushToTomorrow")
        }
    }

    private var severityColor: Color {
        switch conflict.severity {
        case .high: return Color.Taskweave.error
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}

// MARK: - Batch Reschedule Sheet

struct BatchRescheduleSheet: View {
    let conflicts: [TaskConflict]
    let onResolveAll: (BatchRescheduleSuggestion) -> Void
    let onDismiss: () -> Void

    @StateObject private var rescheduleService = SmartRescheduleService.shared
    @Environment(\.dismiss) private var dismiss

    private var batchSuggestion: BatchRescheduleSuggestion {
        rescheduleService.suggestBatchReschedule(for: conflicts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Summary header
                    summaryHeader

                    // Auto-resolve option
                    if batchSuggestion.canAutoResolve {
                        autoResolveCard
                    }

                    // Individual conflicts
                    conflictsList
                }
                .padding()
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Schedule Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var summaryHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("\(conflicts.count) Conflicts Found")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(Color.Taskweave.textPrimary)

            let highCount = conflicts.filter { $0.severity == .high }.count
            if highCount > 0 {
                Text("\(highCount) high severity")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.error)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var autoResolveCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(Color.Taskweave.accent)
                Text("Smart Reschedule")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Taskweave.textPrimary)
            }

            Text("Automatically reschedule all \(conflicts.count) tasks to their optimal times.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Taskweave.textSecondary)

            Button {
                onResolveAll(batchSuggestion)
            } label: {
                Text("Resolve All Conflicts")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Taskweave.accent)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .accessibilityIdentifier("ResolveAllConflicts")
        }
        .padding()
        .background(Color.Taskweave.accent.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private var conflictsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Individual Conflicts")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Taskweave.textPrimary)

            ForEach(batchSuggestion.suggestions, id: \.conflict.id) { suggestion in
                conflictRow(suggestion)
            }
        }
    }

    private func conflictRow(_ suggestion: RescheduleSuggestion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.conflict.task.title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Taskweave.textPrimary)
                    .lineLimit(1)

                Text(suggestion.conflict.conflictDescription)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Taskweave.textSecondary)
                    .lineLimit(1)

                if let recommended = suggestion.recommendedOption {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                        Text(recommended.formattedTime)
                            .font(DesignSystem.Typography.caption1)
                    }
                    .foregroundColor(Color.Taskweave.accent)
                }
            }

            Spacer()

            Image(systemName: suggestion.conflict.severity.systemImage)
                .foregroundColor(severityColor(for: suggestion.conflict.severity))
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func severityColor(for severity: ConflictSeverity) -> Color {
        switch severity {
        case .high: return Color.Taskweave.error
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
