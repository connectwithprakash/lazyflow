import SwiftUI
import UIKit

// MARK: - ConfidenceLevel View Helpers

extension ConfidenceLevel {
    var color: Color {
        switch self {
        case .recommended: return Color.Lazyflow.success
        case .goodFit: return Color.Lazyflow.accent
        case .consider: return Color.Lazyflow.textSecondary
        }
    }
}

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
    @State private var selectedConflict: TaskConflict?
    @State private var showBatchReschedule = false
    @AppStorage("nextUpShowAlternatives") private var showAlternatives = false
    @State private var showSnoozeDialog = false
    @State private var showSkipDialog = false
    @State private var snoozeSkipTarget: TaskSuggestion?
    @State private var undoAction: UndoAction?
    @State private var undoSnapshot: Task?
    @State private var showDailySummary = false
    @State private var showMorningBriefing = false
    @State private var showAddSubtask = false
    @State private var parentTaskForSubtask: Task?
    @State private var showAutoCompleteCelebration = false
    @State private var autoCompletedParentTitle = ""
    @StateObject private var summaryService = DailySummaryService.shared
    @StateObject private var listService = TaskListService.shared
    @AppStorage("summaryPromptHour") private var summaryPromptHour: Int = 18
    @AppStorage("morningBriefingEnabled") private var morningBriefingEnabled: Bool = true
    @AppStorage("lastMorningBriefingDate") private var lastMorningBriefingDate: Double = 0
    @AppStorage("lastPlanYourDayDate") private var lastPlanYourDayDate: Double = 0
    @State private var showPlanYourDay = false

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
        .onAppear {
            scanForConflicts()
            viewModel.autoExpandTasksWithSubtasks()
        }
        .sheet(item: $selectedConflict) { conflict in
            ConflictResolutionSheet(
                conflict: conflict,
                onReschedule: { option in
                    applyReschedule(option: option, to: conflict.task)
                    selectedConflict = nil
                },
                onPushToTomorrow: {
                    pushToTomorrow(conflict.task)
                    selectedConflict = nil
                },
                onDismiss: {
                    selectedConflict = nil
                }
            )
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(defaultDueDate: Date())
        }
        .sheet(item: $viewModel.selectedTask) { task in
            if task.isSubtask {
                SubtaskDetailView(subtask: task)
            } else {
                TaskDetailView(task: task)
            }
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
        .sheet(isPresented: $showBatchReschedule) {
            BatchRescheduleSheet(
                conflicts: conflictService.detectedConflicts,
                onResolveAll: { batchSuggestion in
                    applyBatchReschedule(batchSuggestion)
                    showBatchReschedule = false
                },
                onDismiss: {
                    showBatchReschedule = false
                }
            )
        }
        .undoToast(action: $undoAction) { action in
            handleUndo(action)
        } onDismissWithoutUndo: {
            onUndoToastDismissed()
        }
        .sheet(isPresented: $showDailySummary) {
            DailySummaryView()
        }
        .sheet(isPresented: $showMorningBriefing) {
            MorningBriefingView()
        }
        .sheet(isPresented: $showPlanYourDay) {
            PlanYourDayView()
        }
        .sheet(item: $parentTaskForSubtask) { task in
            AddSubtaskSheet(parentTaskID: task.id) { subtaskTitle in
                TaskService.shared.createSubtask(title: subtaskTitle, parentTaskID: task.id)
                viewModel.refreshTasks()
            }
        }
        .sheet(item: $taskSuggestion) { suggestion in
            NextTaskSuggestionSheet(
                suggestion: suggestion,
                onViewDetails: {
                    // Mild positive feedback (engagement signal only)
                    prioritizationService.recordSuggestionFeedback(
                        task: suggestion.task, action: .viewedDetails, score: suggestion.score
                    )
                    viewModel.selectedTask = suggestion.task
                    taskSuggestion = nil
                },
                onSchedule: {
                    taskToSchedule = suggestion.task
                    taskSuggestion = nil
                },
                onStart: {
                    prioritizationService.recordSuggestionFeedback(
                        task: suggestion.task, action: .startedImmediately, score: suggestion.score
                    )
                    viewModel.startWorking(on: suggestion.task)
                    taskSuggestion = nil
                },
                onSnooze: {
                    snoozeSkipTarget = suggestion
                    showSnoozeDialog = true
                },
                onSkip: {
                    snoozeSkipTarget = suggestion
                    showSkipDialog = true
                }
            )
        }
        .confirmationDialog("Snooze suggestion", isPresented: $showSnoozeDialog, presenting: snoozeSkipTarget) { target in
            Button("In 1 Hour") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .snoozed1Hour, score: target.score
                )
                taskSuggestion = nil
            }
            Button("This Evening (6 PM)") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .snoozedEvening, score: target.score
                )
                taskSuggestion = nil
            }
            Button("Tomorrow Morning (9 AM)") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .snoozedTomorrow, score: target.score
                )
                taskSuggestion = nil
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Skip suggestion", isPresented: $showSkipDialog, presenting: snoozeSkipTarget) { target in
            Button("Not relevant right now") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .skippedNotRelevant, score: target.score
                )
                taskSuggestion = nil
            }
            Button("Wrong time of day") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .skippedWrongTime, score: target.score
                )
                taskSuggestion = nil
            }
            Button("Needs more focus time") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .skippedNeedsFocus, score: target.score
                )
                taskSuggestion = nil
            }
            Button("Cancel", role: .cancel) {}
        }
        .autoCompleteCelebration(isPresented: $showAutoCompleteCelebration, parentTitle: autoCompletedParentTitle)
        .onReceive(NotificationCenter.default.publisher(for: .parentTaskAutoCompleted)) { notification in
            if let title = notification.userInfo?["parentTitle"] as? String {
                autoCompletedParentTitle = title
                showAutoCompleteCelebration = true
                viewModel.refreshTasks()
            }
        }
        .onChange(of: showMorningBriefing) { _, newValue in
            if !newValue {
                // Mark as viewed when sheet is dismissed
                lastMorningBriefingDate = Date().timeIntervalSince1970
            }
        }
        .onChange(of: showPlanYourDay) { _, newValue in
            if !newValue {
                // Mark as viewed when sheet is dismissed
                lastPlanYourDayDate = Date().timeIntervalSince1970
            }
        }
    }

    // MARK: - Plan Your Day Prompt

    /// Show Plan Your Day prompt between 5 AM and 12 PM when not yet reviewed today
    private var shouldShowPlanYourDayPrompt: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        let isMorning = hour >= 5 && hour < 12

        // Check if already viewed today
        let lastViewedDate = Date(timeIntervalSince1970: lastPlanYourDayDate)
        let alreadyViewedToday = Calendar.current.isDateInToday(lastViewedDate)

        return isMorning && CalendarService.shared.hasCalendarAccess && !alreadyViewedToday
    }

    // MARK: - Morning Briefing Prompt

    /// Show morning briefing prompt between 5 AM and 12 PM when there are tasks
    private var shouldShowMorningBriefingPrompt: Bool {
        // Check if user has enabled the prompt in Settings
        guard morningBriefingEnabled else { return false }

        let hour = Calendar.current.component(.hour, from: Date())
        let isMorning = hour >= 5 && hour < 12

        // Check if already viewed today
        let lastViewedDate = Date(timeIntervalSince1970: lastMorningBriefingDate)
        let alreadyViewedToday = Calendar.current.isDateInToday(lastViewedDate)

        return isMorning && viewModel.totalTaskCount > 0 && !alreadyViewedToday
    }

    // MARK: - Daily Summary Prompt

    /// Show summary prompt after configured hour when tasks are completed
    private var shouldShowSummaryPrompt: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= summaryPromptHour && viewModel.completedTaskCount > 0 && !summaryService.hasTodaySummary
    }

    // MARK: - Undo Handling

    private func handleUndo(_ action: UndoAction) {
        guard let snapshot = undoSnapshot else { return }
        let taskService = TaskService.shared

        switch action {
        case .deleted:
            // Undo delete by rolling back uncommitted changes
            // This restores the task AND all its subtasks
            viewModel.discardPendingChanges()
        case .completed:
            // Restore to uncompleted state
            var restoredTask = snapshot
            restoredTask.isCompleted = false
            restoredTask.completedAt = nil
            taskService.updateTask(restoredTask)
        case .movedToToday, .pushedToTomorrow:
            // Restore original due date
            taskService.updateTask(snapshot)
        case .createdFromEvent(let task):
            // For tasks created from events, we need to delete them
            taskService.deleteTask(task)
        }
        undoSnapshot = nil
        viewModel.refreshTasks()
    }

    /// Called when the undo toast dismisses without undo being tapped
    private func onUndoToastDismissed() {
        // Commit any pending changes (e.g., from delete with allowUndo)
        viewModel.commitPendingChanges()
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
                    .foregroundColor(Color.Lazyflow.accent)
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
            } else {
                // ALWAYS show taskListView - never switch views during deletion animation
                // Empty state is handled INSIDE the List to prevent UICollectionView crash
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

    private func applyBatchReschedule(_ batchSuggestion: BatchRescheduleSuggestion) {
        _ = rescheduleService.applyBatchReschedule(batch: batchSuggestion, taskService: TaskService.shared)
        scanForConflicts()
    }

    private func listColorHex(for task: Task) -> String? {
        guard let listID = task.listID,
              let list = listService.getList(byID: listID),
              !list.isDefault else { return nil }
        return list.colorHex
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
            } else {
                showBatchReschedule = true
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: highSeverityCount > 0 ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(highSeverityCount > 0 ? Color.Lazyflow.error : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(conflicts.count) Schedule Conflict\(conflicts.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)

                    if let first = conflicts.first {
                        Text(first.conflictDescription)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text("Resolve")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.accent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(highSeverityCount > 0 ? Color.Lazyflow.error.opacity(0.1) : Color.orange.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(highSeverityCount > 0 ? Color.Lazyflow.error.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
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

    /// The primary suggested task ID (used for deduplication from Today/Overdue)
    /// Only deduplicate when Next Up is visible (3+ tasks)
    /// IDs of all tasks visible in Next Up (used for deduplication from Today/Overdue)
    private var nextUpVisibleTaskIDs: Set<UUID> {
        let incompleteCount = viewModel.totalTaskCount
        guard incompleteCount >= 3 else { return [] }
        let suggestions = prioritizationService.topThreeSuggestions
        guard !suggestions.isEmpty else { return [] }
        if incompleteCount >= 5, showAlternatives {
            // Primary + alternatives all visible
            return Set(suggestions.map(\.id))
        } else {
            // Only primary visible
            return suggestions.first.map { Set([$0.id]) } ?? []
        }
    }

    /// Overdue tasks with visible Next Up tasks filtered out
    private func overdueTasks(excluding ids: Set<UUID>) -> [Task] {
        guard !ids.isEmpty else { return viewModel.overdueTasks }
        return viewModel.overdueTasks.filter { !ids.contains($0.id) }
    }

    /// Today tasks with visible Next Up tasks filtered out
    private func todayTasks(excluding ids: Set<UUID>) -> [Task] {
        guard !ids.isEmpty else { return viewModel.todayTasks }
        return viewModel.todayTasks.filter { !ids.contains($0.id) }
    }

    private var taskListView: some View {
        List {
            // Section 1: Progress header
            Section {
                progressHeader
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 2: Next Up - ALWAYS present (even when empty)
            // Gating: 0-2 tasks = hidden, 3-4 = primary only, 5+ = primary + alternatives
            Section {
                let incompleteCount = viewModel.totalTaskCount
                let suggestions = prioritizationService.getTopThreeSuggestions()
                if incompleteCount >= 3, !suggestions.isEmpty {
                    // Primary card: TaskRowView wrapped with suggestion chrome
                    if let primary = suggestions.first {
                        nextUpPrimaryCard(primary)
                    }

                    // Alternatives (5+ tasks, collapsible)
                    let alternatives = incompleteCount >= 5 ? Array(suggestions.dropFirst()) : []
                    if !alternatives.isEmpty {
                        if showAlternatives {
                            ForEach(alternatives) { alt in
                                nextUpAlternativeRow(suggestion: alt)
                            }
                        }

                        Button {
                            withAnimation(DesignSystem.Animation.standard) {
                                showAlternatives.toggle()
                            }
                        } label: {
                            Text(showAlternatives
                                ? "Hide alternatives"
                                : "Show \(alternatives.count) more")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.accent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(minHeight: DesignSystem.TouchTarget.minimum)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .accessibilityLabel(showAlternatives ? "Hide alternative suggestions" : "Show \(alternatives.count) more suggestions")
                        .accessibilityValue(showAlternatives ? "Expanded" : "Collapsed")
                        .accessibilityHint("Double tap to \(showAlternatives ? "hide" : "show") alternatives")
                    }
                }
            } header: {
                if viewModel.totalTaskCount >= 3, !prioritizationService.topThreeSuggestions.isEmpty {
                    nextUpSectionHeader
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 3: Prompt cards - ALWAYS present
            Section {
                if shouldShowPlanYourDayPrompt {
                    planYourDayPromptCard
                }
                if shouldShowMorningBriefingPrompt {
                    morningBriefingPromptCard
                }
                if shouldShowSummaryPrompt {
                    dailySummaryPromptCard
                }
                if !conflictService.detectedConflicts.isEmpty {
                    conflictsBanner
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 4: Overdue tasks - ALWAYS present (even when empty)
            Section {
                let filteredOverdue = overdueTasks(excluding: nextUpVisibleTaskIDs)
                ForEach(filteredOverdue) { task in
                    flatTaskRows(task: task, isCompleted: false)
                        .id(task.id)
                }
            } header: {
                let filteredOverdue = overdueTasks(excluding: nextUpVisibleTaskIDs)
                if !filteredOverdue.isEmpty {
                    taskSectionHeader(title: "Overdue", color: Color.Lazyflow.error, count: filteredOverdue.count)
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 5: Today tasks - ALWAYS present (even when empty)
            Section {
                let filteredToday = todayTasks(excluding: nextUpVisibleTaskIDs)
                ForEach(filteredToday) { task in
                    flatTaskRows(task: task, isCompleted: false)
                        .id(task.id)
                }
            } header: {
                let filteredToday = todayTasks(excluding: nextUpVisibleTaskIDs)
                if !filteredToday.isEmpty {
                    taskSectionHeader(title: "Today", color: Color.Lazyflow.accent, count: filteredToday.count)
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 6: Completed tasks - ALWAYS present (even when empty)
            Section {
                ForEach(viewModel.completedTodayTasks) { task in
                    flatTaskRows(task: task, isCompleted: true)
                        .id(task.id)
                }
            } header: {
                if !viewModel.completedTodayTasks.isEmpty {
                    completedSectionHeader(count: viewModel.completedTodayTasks.count)
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 7: Empty state - ALWAYS present
            Section {
                if viewModel.totalTaskCount == 0 && viewModel.completedTaskCount == 0 {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "All Clear!",
                        message: "You have no tasks due today.\nEnjoy your day or add a new task.",
                        actionTitle: "Add Task"
                    ) {
                        showAddTask = true
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 40, leading: 16, bottom: 40, trailing: 16))
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground)
    }

    private func taskSectionHeader(title: String, color: Color, count: Int) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Text("\(count)")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Spacer()
        }
    }

    private func completedSectionHeader(count: Int) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.Lazyflow.success)

            Text("Completed")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Text("\(count)")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textTertiary)

            Spacer()
        }
    }

    /// Creates a flat list of rows for a task (parent + optional subtasks)
    /// Each view returned becomes a separate list row, fixing the swipe actions issue
    @ViewBuilder
    private func flatTaskRows(task: Task, isCompleted: Bool) -> some View {
        // Parent task row
        TaskRowView(
            task: task,
            onToggle: {
                if !isCompleted {
                    showUndoToast(.completed(task), snapshot: task)
                }
                viewModel.toggleTaskCompletion(task)
            },
            onTap: { viewModel.selectedTask = task },
            onSchedule: isCompleted ? nil : { scheduleTaskAction($0) },
            onPushToTomorrow: isCompleted ? nil : { task in
                showUndoToast(.pushedToTomorrow(task), snapshot: task)
                pushToTomorrow(task)
            },
            onMoveToToday: isCompleted ? nil : { task in
                showUndoToast(.movedToToday(task), snapshot: task)
                moveToToday(task)
            },
            onPriorityChange: { viewModel.updateTaskPriority($0, priority: $1) },
            onDueDateChange: { viewModel.updateTaskDueDate($0, dueDate: $1) },
            onDelete: { task in
                if !isCompleted {
                    showUndoToast(.deleted(task), snapshot: task)
                    // Use allowUndo: true to delay save and allow rollback
                    viewModel.deleteTask(task, allowUndo: true)
                } else {
                    // Completed tasks don't need undo
                    viewModel.deleteTask(task, allowUndo: false)
                }
            },
            onStartWorking: isCompleted ? nil : { viewModel.startWorking(on: $0) },
            onStopWorking: isCompleted ? nil : { viewModel.stopWorking(on: $0) },
            hideSubtaskBadge: true,
            showProgressRing: task.hasSubtasks,
            showListIndicator: true,
            listColorHex: listColorHex(for: task)
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: task.hasSubtasks ? 0 : 4, trailing: 16))

        // Subtasks section (if task has subtasks)
        if task.hasSubtasks {
            // Expansion header
            SubtaskExpansionHeader(
                task: task,
                isExpanded: viewModel.isExpanded(task.id),
                onToggle: {
                    withAnimation(DesignSystem.Animation.quick) {
                        viewModel.toggleExpansion(task.id)
                    }
                }
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 16))
            .listRowBackground(Color.adaptiveBackground)

            // Subtask rows (if expanded)
            if viewModel.isExpanded(task.id) {
                ForEach(Array(task.subtasks.enumerated()), id: \.element.id) { index, subtask in
                    SubtaskRowView(
                        subtask: subtask,
                        onToggle: {
                            TaskService.shared.toggleSubtaskCompletion(subtask)
                            viewModel.refreshTasks()
                            // Auto-collapse when all subtasks completed
                            if task.subtasks.filter({ !$0.isCompleted }).count <= 1 && !subtask.isCompleted {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(DesignSystem.Animation.standard) {
                                        viewModel.setExpanded(task.id, expanded: false)
                                    }
                                }
                            }
                        },
                        onTap: { viewModel.selectedTask = subtask },
                        onDelete: { subtask in
                            // Show undo toast and delete with allowUndo
                            showUndoToast(.deleted(subtask), snapshot: subtask)
                            TaskService.shared.deleteTask(subtask, allowUndo: true)
                            viewModel.refreshTasks()
                        },
                        onPromote: { subtask in
                            TaskService.shared.promoteSubtaskToTask(subtask)
                            viewModel.refreshTasks()
                        },
                        index: index,
                        isLast: index == task.subtasks.count - 1
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: index == task.subtasks.count - 1 && task.isCompleted ? 4 : 0, trailing: 16))
                    .listRowBackground(Color.adaptiveBackground)
                }

                // Add subtask button (only for incomplete tasks)
                if !task.isCompleted {
                    AddSubtaskInlineButton {
                        parentTaskForSubtask = task
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 4, trailing: 16))
                    .listRowBackground(Color.adaptiveBackground)
                }
            }
        }
    }

    // MARK: - Next Up Section

    private var nextUpSectionHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(Color.Lazyflow.accent)

            Text("Next Up")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Spacer()
        }
    }

    @ViewBuilder
    private func nextUpPrimaryCard(_ suggestion: TaskSuggestion) -> some View {
        // Suggestion chrome: confidence badge + top reason
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Confidence badge
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(suggestion.confidence.color)
                    .frame(width: 6, height: 6)
                Text(suggestion.confidence.rawValue)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(suggestion.confidence.color)
                    .lineLimit(1)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(suggestion.confidence.color.opacity(0.12))
            .cornerRadius(DesignSystem.CornerRadius.small)
            .fixedSize()

            if let topReason = suggestion.reasons.first {
                Text(topReason)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.accent)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                fetchSuggestionDetails(for: suggestion.task)
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(Color.Lazyflow.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View suggestion details")
            .accessibleTouchTarget()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Suggested: \(suggestion.confidence.rawValue) pick\(suggestion.reasons.first.map { ", \($0)" } ?? "")")

        // Full TaskRowView for the task (reactive, with built-in swipe actions)
        flatTaskRows(task: suggestion.task, isCompleted: false)
    }

    @ViewBuilder
    private func nextUpAlternativeRow(suggestion: TaskSuggestion) -> some View {
        // Bare TaskRowView — no chrome for alternatives, keeps section compact
        flatTaskRows(task: suggestion.task, isCompleted: false)
    }

    private func fetchSuggestionDetails(for task: Task) {
        _Concurrency.Task {
            let suggestion = await prioritizationService.getSuggestion(for: task)
            await MainActor.run {
                taskSuggestion = suggestion
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(Date().fullFormatted)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                Spacer()

                Text("\(viewModel.completedTaskCount)/\(viewModel.totalTaskCount + viewModel.completedTaskCount) done")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Lazyflow.accent)
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

    private var planYourDayPromptCard: some View {
        Button {
            showPlanYourDay = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.Lazyflow.accent.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(Color.Lazyflow.accent)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Plan Your Day")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)

                    Text("Review calendar events and add tasks")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
            .padding()
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
        }
        .buttonStyle(.plain)
    }

    private var morningBriefingPromptCard: some View {
        Button {
            showMorningBriefing = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Start Your Day")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)

                    Text("You have \(viewModel.totalTaskCount) task\(viewModel.totalTaskCount == 1 ? "" : "s") planned for today")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
            .padding()
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
        }
        .buttonStyle(.plain)
    }

    private var dailySummaryPromptCard: some View {
        Button {
            showDailySummary = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("View Daily Summary")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)

                    Text("See your productivity stats for today")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
            .padding()
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Next Task Suggestion Sheet

struct NextTaskSuggestionSheet: View {
    let suggestion: TaskSuggestion
    let onViewDetails: () -> Void
    let onSchedule: () -> Void
    let onStart: () -> Void
    var onSnooze: (() -> Void)?
    var onSkip: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Task card (top of sheet)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Header: priority icon + title + confidence badge
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: suggestion.task.priority.iconName)
                                .foregroundColor(suggestion.task.priority.color)
                                .font(.system(size: 16))

                            Text(suggestion.task.title)
                                .font(DesignSystem.Typography.title3)
                                .foregroundColor(Color.Lazyflow.textPrimary)

                            Spacer()

                            // Confidence badge
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Circle()
                                    .fill(suggestion.confidence.color)
                                    .frame(width: 6, height: 6)
                                Text(suggestion.confidence.rawValue)
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundColor(suggestion.confidence.color)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(suggestion.confidence.color.opacity(0.12))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        }

                        // Metadata badges
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if let dueDate = suggestion.task.dueDate {
                                DueDateBadge(
                                    date: dueDate,
                                    isOverdue: dueDate < Date(),
                                    isDueToday: Calendar.current.isDateInToday(dueDate)
                                )
                            }

                            if let duration = suggestion.task.estimatedDuration {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text("\(Int(duration / 60)) min")
                                        .font(DesignSystem.Typography.caption2)
                                }
                                .foregroundColor(Color.Lazyflow.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .fixedSize()
                            }

                            if suggestion.task.category != .uncategorized {
                                CategoryBadge(category: suggestion.task.category)
                            }
                        }

                        // Subtitle
                        Text("Based on priority, deadlines, and your patterns")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.adaptiveSurface)
                    .cornerRadius(DesignSystem.CornerRadius.large)
                    .padding(.horizontal)
                    .padding(.top, DesignSystem.Spacing.sm)

                    // Reason chips (wrapped multi-line)
                    if !suggestion.reasons.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Why this task?")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(Color.Lazyflow.textPrimary)

                            ReasonChipsView(reasons: suggestion.reasons)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // AI Insight
                    if let insight = suggestion.aiInsight {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color.Lazyflow.accent)
                                Text("AI Insight")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(Color.Lazyflow.textPrimary)
                            }

                            Text(insight)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                                .italic()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.Lazyflow.accent.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)

                    // Action buttons (consolidated to 2 rows)
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        // Row 1: Start Now
                        Button {
                            onStart()
                        } label: {
                            Label("Start Now", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        // Row 2: Schedule + More menu
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Button {
                                onSchedule()
                            } label: {
                                Label("Schedule", systemImage: "calendar.badge.plus")
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Menu {
                                Button {
                                    onViewDetails()
                                } label: {
                                    Label("View Details", systemImage: "info.circle")
                                }

                                if onSnooze != nil {
                                    Button {
                                        onSnooze?()
                                    } label: {
                                        Label("Snooze...", systemImage: "moon.fill")
                                    }
                                }

                                if onSkip != nil {
                                    Button {
                                        onSkip?()
                                    } label: {
                                        Label("Skip...", systemImage: "forward.fill")
                                    }
                                }
                            } label: {
                                Text("More")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(Color.Lazyflow.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: DesignSystem.TouchTarget.comfortable)
                                    .background(Color.Lazyflow.accent.opacity(0.1))
                                    .cornerRadius(DesignSystem.CornerRadius.large)
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

// MARK: - Reason Chips View

struct ReasonChipsView: View {
    let reasons: [String]

    var body: some View {
        // Use LazyVGrid with flexible columns for wrapping chips
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: DesignSystem.Spacing.sm)], alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(reasons, id: \.self) { reason in
                Text(reason)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.accent)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(Color.Lazyflow.accent.opacity(0.15))
                    .cornerRadius(DesignSystem.CornerRadius.full)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Next Up Swipe Actions

private struct NextUpSwipeActionsModifier: ViewModifier {
    let task: Task
    let onToggle: () -> Void
    let onPushToTomorrow: ((Task) -> Void)?
    let onMoveToToday: ((Task) -> Void)?
    let onDelete: ((Task) -> Void)?
    let onStartWorking: ((Task) -> Void)?
    let onStopWorking: ((Task) -> Void)?
    let onSchedule: ((Task) -> Void)?

    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    notificationFeedback.notificationOccurred(.warning)
                    onDelete?(task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                if task.isOverdue || (!task.isDueToday && task.dueDate != nil) {
                    Button {
                        impactMedium.impactOccurred()
                        onMoveToToday?(task)
                    } label: {
                        Label("Today", systemImage: "star.fill")
                    }
                    .tint(.blue)
                }

                if task.isDueToday || task.isOverdue {
                    Button {
                        impactMedium.impactOccurred()
                        onPushToTomorrow?(task)
                    } label: {
                        Label("Tomorrow", systemImage: "arrow.right.to.line")
                    }
                    .tint(.orange)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    notificationFeedback.notificationOccurred(.success)
                    onToggle()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .tint(Color.Lazyflow.success)

                if task.isInProgress {
                    Button {
                        impactMedium.impactOccurred()
                        onStopWorking?(task)
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .tint(.orange)
                } else {
                    Button {
                        impactMedium.impactOccurred()
                        onStartWorking?(task)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(Color.Lazyflow.accent)
                }

                Button {
                    impactLight.impactOccurred()
                    onSchedule?(task)
                } label: {
                    Label("Schedule", systemImage: "calendar.badge.plus")
                }
                .tint(.purple)
            }
    }
}

extension View {
    func nextUpSwipeActions(
        task: Task,
        onToggle: @escaping () -> Void,
        onPushToTomorrow: ((Task) -> Void)? = nil,
        onMoveToToday: ((Task) -> Void)? = nil,
        onDelete: ((Task) -> Void)? = nil,
        onStartWorking: ((Task) -> Void)? = nil,
        onStopWorking: ((Task) -> Void)? = nil,
        onSchedule: ((Task) -> Void)? = nil
    ) -> some View {
        modifier(NextUpSwipeActionsModifier(
            task: task,
            onToggle: onToggle,
            onPushToTomorrow: onPushToTomorrow,
            onMoveToToday: onMoveToToday,
            onDelete: onDelete,
            onStartWorking: onStartWorking,
            onStopWorking: onStopWorking,
            onSchedule: onSchedule
        ))
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
                    .foregroundColor(Color.Lazyflow.accent)
                VStack(alignment: .leading) {
                    Text("Task")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textTertiary)
                    Text(conflict.task.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
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
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        Text(event.title)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                        Text(event.formattedTimeRange)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                    Spacer()
                }
            }

            // Conflicting task info (for task-to-task conflicts)
            if let conflictingTask = conflict.conflictingTask {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Conflicts with task")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        Text(conflictingTask.title)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                        if let dueTime = conflictingTask.dueTime {
                            Text(dueTime.formatted(date: .omitted, time: .shortened))
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                    Spacer()
                }
            }

            // Overlap info
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(Color.Lazyflow.error)
                Text(conflict.formattedOverlap)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
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
                    .foregroundColor(Color.Lazyflow.accent)
                Text("Recommended")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.accent)
            }

            Button {
                onReschedule(option)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.formattedTime)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                        Text(option.reason)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.Lazyflow.accent)
                }
                .padding()
                .background(Color.Lazyflow.accent.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .buttonStyle(.plain)
        }
    }

    private var otherOptionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Other Options")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            ForEach(suggestion.options.dropFirst().prefix(3)) { option in
                Button {
                    onReschedule(option)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.formattedTime)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                            Text(option.reason)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.Lazyflow.textTertiary)
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
                .foregroundColor(Color.Lazyflow.textPrimary)

            Button {
                onPushToTomorrow()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.to.line")
                        .foregroundColor(Color.Lazyflow.accent)
                    Text("Push to Tomorrow")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
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
        case .high: return Color.Lazyflow.error
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
                .foregroundColor(Color.Lazyflow.textPrimary)

            let highCount = conflicts.filter { $0.severity == .high }.count
            if highCount > 0 {
                Text("\(highCount) high severity")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.error)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var autoResolveCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("Smart Reschedule")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
            }

            Text("Automatically reschedule all \(conflicts.count) tasks to their optimal times.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Button {
                onResolveAll(batchSuggestion)
            } label: {
                Text("Resolve All Conflicts")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Lazyflow.accent)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .accessibilityIdentifier("ResolveAllConflicts")
        }
        .padding()
        .background(Color.Lazyflow.accent.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private var conflictsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Individual Conflicts")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

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
                    .foregroundColor(Color.Lazyflow.textPrimary)
                    .lineLimit(1)

                Text(suggestion.conflict.conflictDescription)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .lineLimit(1)

                if let recommended = suggestion.recommendedOption {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                        Text(recommended.formattedTime)
                            .font(DesignSystem.Typography.caption1)
                    }
                    .foregroundColor(Color.Lazyflow.accent)
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
        case .high: return Color.Lazyflow.error
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}

// MARK: - Subtask Expansion Header

/// Header row for expanding/collapsing subtasks in the flat list structure
struct SubtaskExpansionHeader: View {
    let task: Task
    let isExpanded: Bool
    let onToggle: () -> Void

    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Button {
            impactLight.impactOccurred()
            onToggle()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Left spacing for thread connector alignment (matches SubtaskRowView)
                Spacer()
                    .frame(width: 16 + DesignSystem.Spacing.sm)

                Text("\(task.completedSubtaskCount)/\(task.subtasks.count) subtasks")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textTertiary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.trailing, DesignSystem.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            // Vertical thread line - matches SubtaskThreadConnector positioning
            Canvas { context, size in
                let xPos: CGFloat = 2
                var path = Path()
                path.move(to: CGPoint(x: xPos, y: 0))
                path.addLine(to: CGPoint(x: xPos, y: size.height))
                context.stroke(path, with: .color(Color.Lazyflow.textTertiary.opacity(0.4)), lineWidth: 1.5)
            }
            .frame(width: 16)
            .padding(.leading, DesignSystem.Spacing.sm)
        }
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
