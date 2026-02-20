import SwiftUI
import UIKit

/// Main Today view showing overdue and today's tasks
struct TodayView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = TodayViewModel()
    @StateObject private var prioritizationService = PrioritizationService.shared
    @StateObject private var conflictService = ConflictDetectionService.shared
    @StateObject private var rescheduleService = SmartRescheduleService.shared
    @State private var showAddTask = false
    @State private var taskToSchedule: Task?
    @State private var selectedConflict: TaskConflict?
    @State private var showBatchReschedule = false
    @State private var optimisticallyCompletedIDs: Set<UUID> = []
    @State private var showNotNowDialog = false
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
    @State private var actionToast: ActionToastData?
    @State private var highlightedTaskID: UUID?
    @State private var isNextUpPulsing = false
    @State private var optimisticInProgressID: UUID?
    @State private var optimisticPausedID: UUID?
    @EnvironmentObject private var focusCoordinator: FocusSessionCoordinator

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
        .onChange(of: viewModel.taskData) {
            // Prune stale optimistic IDs — remove IDs for tasks that are now persisted as completed
            if !optimisticallyCompletedIDs.isEmpty {
                let allTasks = viewModel.overdueTasks + viewModel.todayTasks
                optimisticallyCompletedIDs = optimisticallyCompletedIDs.filter { id in
                    allTasks.contains { $0.id == id && !$0.isCompleted }
                }
            }
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
        .actionToast($actionToast)
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
        .confirmationDialog("Not now", isPresented: $showNotNowDialog, presenting: snoozeSkipTarget) { target in
            // Snooze options
            Button("Snooze 1 Hour") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .snoozed1Hour, score: target.score
                )
            }
            Button("Snooze to Evening (6 PM)") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .snoozedEvening, score: target.score
                )
            }
            Button("Snooze to Tomorrow (9 AM)") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .snoozedTomorrow, score: target.score
                )
            }
            // Skip options
            Button("Skip — Not relevant") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .skippedNotRelevant, score: target.score
                )
                showSkipHighlight(for: target.task)
            }
            Button("Skip — Wrong time") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .skippedWrongTime, score: target.score
                )
                showSkipHighlight(for: target.task)
            }
            Button("Skip — Needs more focus") {
                prioritizationService.recordSuggestionFeedback(
                    task: target.task, action: .skippedNeedsFocus, score: target.score
                )
                showSkipHighlight(for: target.task)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Snooze for later or skip to see a different suggestion")
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
            optimisticallyCompletedIDs.remove(snapshot.id)
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

    private var taskListView: some View {
        ScrollViewReader { scrollProxy in
        List {
            // Section 1: Progress header
            Section {
                progressHeader
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 2: Prompt cards - ALWAYS present (orient before action)
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

            // Section 3: Next Up - ALWAYS present (even when empty)
            Section {
                if let suggestion = effectiveNextUpSuggestion {
                    nextUpCard(for: suggestion)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            } header: {
                if effectiveNextUpSuggestion != nil {
                    nextUpSectionHeader
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 4: Overdue tasks - ALWAYS present (even when empty)
            Section {
                ForEach(viewModel.overdueTasks) { task in
                    flatTaskRows(task: task, isCompleted: false)
                        .id(task.id)
                }
            } header: {
                if !viewModel.overdueTasks.isEmpty {
                    taskSectionHeader(title: "Overdue", color: Color.Lazyflow.error, count: viewModel.overdueTasks.count)
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 5: Today tasks - ALWAYS present (even when empty)
            Section {
                ForEach(viewModel.todayTasks) { task in
                    flatTaskRows(task: task, isCompleted: false)
                        .id(task.id)
                }
            } header: {
                if !viewModel.todayTasks.isEmpty {
                    taskSectionHeader(title: "Today", color: Color.Lazyflow.accent, count: viewModel.todayTasks.count)
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
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground)
        .onChange(of: highlightedTaskID) { _, newValue in
            if let id = newValue {
                withAnimation { scrollProxy.scrollTo(id, anchor: .center) }
            }
        }
        } // ScrollViewReader
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
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.Lazyflow.accent.opacity(highlightedTaskID == task.id ? 0.15 : 0))
                .animation(.easeInOut(duration: 0.3), value: highlightedTaskID)
                .allowsHitTesting(false)
        )

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

    /// The effective Next Up suggestion, filtering out optimistically completed and already-completed tasks
    private var effectiveNextUpSuggestion: TaskSuggestion? {
        prioritizationService.cachedSuggestions.first {
            !$0.task.isCompleted && !optimisticallyCompletedIDs.contains($0.task.id)
        }
    }

    /// Resolve the live task from TaskService (Core Data) instead of stale suggestion snapshot
    private func liveTask(for suggestion: TaskSuggestion) -> Task {
        TaskService.shared.tasks.first { $0.id == suggestion.task.id } ?? suggestion.task
    }

    /// Whether the Next Up task is effectively in progress (optimistic or persisted)
    private func isNextUpInProgress(_ task: Task) -> Bool {
        if task.id == optimisticInProgressID { return true }
        if task.id == optimisticPausedID { return false }
        return task.isInProgress
    }

    @ViewBuilder
    private func nextUpCard(for suggestion: TaskSuggestion) -> some View {
        let task = liveTask(for: suggestion)
        let inProgress = isNextUpInProgress(task)

        VStack(spacing: 0) {
            // Card body: checkbox + task info
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Checkbox — with progress ring for subtasks
                Button {
                    optimisticallyComplete(task, suggestion: suggestion)
                } label: {
                    ZStack {
                        // Subtask progress ring (outermost)
                        if task.hasSubtasks {
                            Circle()
                                .stroke(Color.Lazyflow.accent.opacity(0.35), lineWidth: 3)
                                .frame(width: 32, height: 32)

                            if task.subtaskProgress > 0 {
                                Circle()
                                    .trim(from: 0, to: task.subtaskProgress)
                                    .stroke(
                                        task.allSubtasksCompleted ? Color.Lazyflow.success : Color.Lazyflow.accent,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 32, height: 32)
                                    .rotationEffect(.degrees(-90))
                            }
                        }

                        // Inner checkbox circle
                        Circle()
                            .strokeBorder(
                                inProgress ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary.opacity(0.5),
                                lineWidth: 2.5
                            )
                            .frame(width: 26, height: 26)
                            .animation(.easeInOut(duration: 0.3), value: inProgress)

                        // Pulsing dot when in progress
                        if inProgress {
                            Circle()
                                .fill(Color.Lazyflow.accent)
                                .frame(width: 10, height: 10)
                                .scaleEffect(isNextUpPulsing ? 1.0 : 0.85)
                                .opacity(isNextUpPulsing ? 1.0 : 0.7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
                .accessibilityLabel("Complete \(task.title)")
                .accessibilityHint("Marks task as done")

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Title
                    Text(task.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Meta badges
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if let dueDate = task.dueDate {
                            DueDateBadge(
                                date: dueDate,
                                isOverdue: task.isOverdue,
                                isDueToday: Calendar.current.isDateInToday(dueDate)
                            )
                        }

                        // Live timer when in progress, estimated duration otherwise
                        if inProgress {
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "timer")
                                        .font(.caption2)
                                    Text(task.formattedElapsedTime ?? "0:00")
                                        .font(DesignSystem.Typography.caption2)
                                        .monospacedDigit()
                                }
                                .foregroundColor(Color.Lazyflow.success)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(Color.Lazyflow.success.opacity(0.1))
                                .cornerRadius(DesignSystem.CornerRadius.small)
                            }
                            .transition(.opacity)
                        } else if let duration = task.estimatedDuration, duration > 0 {
                            let mins = Int(duration / 60)
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m")
                                    .font(DesignSystem.Typography.caption2)
                            }
                            .foregroundColor(Color.Lazyflow.textTertiary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(Color.Lazyflow.textTertiary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        }

                        // Subtask progress badge
                        if task.hasSubtasks {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "list.bullet")
                                    .font(.caption2)
                                Text("\(task.completedSubtaskCount)/\(task.subtasks.count)")
                                    .font(DesignSystem.Typography.caption2)
                            }
                            .foregroundColor(Color.Lazyflow.textTertiary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(Color.Lazyflow.textTertiary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        }
                    }

                    // Reason line — always present, derived from live task state
                    Group {
                        if inProgress {
                            Text("In progress")
                                .foregroundColor(Color.Lazyflow.success)
                        } else if task.isOverdue {
                            Text("Overdue — consider finishing today")
                                .foregroundColor(Color.Lazyflow.error)
                        } else if let topReason = suggestion.reasons.first(where: {
                            !$0.lowercased().contains("overdue")
                        }) {
                            Text(topReason)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        } else {
                            Text("Suggested for you")
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }
                    .font(DesignSystem.Typography.caption1)
                    .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedTask = task
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens task details")
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)

            // Divider
            Rectangle()
                .fill(Color.Lazyflow.textTertiary.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            // Time progress bar when in progress and has estimated duration
            if inProgress, let estimated = task.estimatedDuration, estimated > 0 {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let elapsed = task.elapsedTime ?? 0
                    let progress = min(elapsed / estimated, 1.0)
                    let overBudget = elapsed > estimated

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(overBudget ? Color.Lazyflow.warning : Color.Lazyflow.success)
                                    .frame(width: geometry.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            let elapsedMins = Int(elapsed / 60)
                            let estimatedMins = Int(estimated / 60)
                            Text("\(elapsedMins)m of \(estimatedMins)m")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(overBudget ? Color.Lazyflow.warning : Color.Lazyflow.textTertiary)
                            Spacer()
                            if overBudget {
                                Text("Over estimate")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundColor(Color.Lazyflow.warning)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.sm)
                .transition(.opacity)
            }

            // Action row — single row, layout changes based on state
            HStack(spacing: DesignSystem.Spacing.sm) {
                if inProgress {
                    // Pause + Focus
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            optimisticInProgressID = nil
                            optimisticPausedID = task.id
                        }
                        viewModel.stopWorking(on: task)
                        actionToast = ActionToastData(
                            message: "Timer paused",
                            icon: "pause.fill",
                            iconColor: .orange
                        )
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                            Text("Pause")
                        }
                    }
                    .buttonStyle(NextUpActionButtonStyle(
                        isPrimary: true,
                        overrideBackground: Color.Lazyflow.success.opacity(0.15),
                        overrideForeground: Color.Lazyflow.success
                    ))
                    .accessibilityLabel("Pause timer")
                    .transition(.opacity)

                    Button {
                        prioritizationService.recordSuggestionFeedback(
                            task: task, action: .startedImmediately, score: suggestion.score
                        )
                        focusCoordinator.enterFocus(task: task)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "scope")
                            Text("Focus")
                        }
                    }
                    .buttonStyle(NextUpActionButtonStyle(isPrimary: false))
                    .transition(.opacity)
                } else {
                    // Start/Resume + Focus + Later
                    let hasWorkedBefore = task.accumulatedDuration > 0
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            optimisticPausedID = nil
                            optimisticInProgressID = task.id
                        }
                        prioritizationService.recordSuggestionFeedback(
                            task: task, action: .startedImmediately, score: suggestion.score
                        )
                        viewModel.startWorking(on: task)
                        actionToast = ActionToastData(
                            message: hasWorkedBefore ? "Timer resumed" : "Timer started",
                            icon: "play.fill",
                            iconColor: Color.Lazyflow.success
                        )
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text(hasWorkedBefore ? "Resume" : "Start")
                        }
                    }
                    .buttonStyle(NextUpActionButtonStyle(isPrimary: true))
                    .accessibilityLabel(hasWorkedBefore ? "Resume working" : "Start working")
                    .transition(.opacity)

                    Button {
                        prioritizationService.recordSuggestionFeedback(
                            task: task, action: .startedImmediately, score: suggestion.score
                        )
                        focusCoordinator.enterFocus(task: task)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "scope")
                            Text("Focus")
                        }
                    }
                    .buttonStyle(NextUpActionButtonStyle(isPrimary: false))
                    .transition(.opacity)

                    Button {
                        snoozeSkipTarget = suggestion
                        showNotNowDialog = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Later")
                        }
                    }
                    .buttonStyle(NextUpActionButtonStyle(isPrimary: false))
                    .accessibilityLabel("Snooze or skip suggestion")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Next up: \(task.title)")
        .onAppear {
            if inProgress && !reduceMotion {
                isNextUpPulsing = false
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isNextUpPulsing = true
                }
            } else if inProgress {
                isNextUpPulsing = true
            }
        }
        .onChange(of: optimisticInProgressID) { _, newID in
            let active = newID == task.id
            if active && !reduceMotion {
                isNextUpPulsing = false
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isNextUpPulsing = true
                }
            } else if active {
                isNextUpPulsing = true
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isNextUpPulsing = false
                }
            }
        }
        .onChange(of: task.isInProgress) { _, persisted in
            // Clear optimistic state once Core Data catches up
            if optimisticInProgressID == task.id && persisted {
                optimisticInProgressID = nil
            }
            if optimisticPausedID == task.id && !persisted {
                optimisticPausedID = nil
            }
            if !persisted && optimisticInProgressID != task.id {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isNextUpPulsing = false
                }
            }
        }
    }

    /// Optimistically complete a task from the Next Up card
    private func optimisticallyComplete(_ task: Task, suggestion: TaskSuggestion) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        _ = withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
            optimisticallyCompletedIDs.insert(task.id)
        }

        showUndoToast(.completed(task), snapshot: task)
        viewModel.toggleTaskCompletion(task)
    }

    private func showSkipHighlight(for task: Task) {
        actionToast = ActionToastData(
            message: "Suggestion skipped",
            icon: "forward.fill",
            iconColor: Color.Lazyflow.textSecondary
        )
        highlightedTaskID = task.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { highlightedTaskID = nil }
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

// MARK: - Next Up Button Styles

/// Compact action button for the Next Up card (Start / Focus)
struct NextUpActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    var overrideBackground: Color? = nil
    var overrideForeground: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        let bgColor = overrideBackground
            ?? (isPrimary ? Color.Lazyflow.accent : Color.Lazyflow.accent.opacity(0.1))
        let fgColor: Color = overrideForeground
            ?? ((overrideBackground != nil || isPrimary) ? .white : Color.Lazyflow.accent)

        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(fgColor)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.TouchTarget.minimum)
            .background(bgColor)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

/// Icon-only button for snooze/skip in the Next Up card
struct NextUpIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.Lazyflow.textSecondary)
            .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
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
        .environmentObject(FocusSessionCoordinator())
}
