import SwiftUI
import UIKit

/// Main Today view showing overdue and today's tasks
struct TodayView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var viewModel = TodayViewModel()
    @State private var prioritizationService = PrioritizationService.shared
    @State var conflictService = ConflictDetectionService.shared
    @StateObject var rescheduleService = SmartRescheduleService.shared
    @State var showAddTask = false
    @State var taskToSchedule: Task?
    @State var selectedConflict: TaskConflict?
    @State var showBatchReschedule = false
    @State var optimisticallyCompletedIDs: Set<UUID> = []
    @State var showNotNowDialog = false
    @State var snoozeSkipTarget: TaskSuggestion?
    @State var undoAction: UndoAction?
    @State var undoSnapshot: Task?
    @State var showDailySummary = false
    @State var showMorningBriefing = false
    @State private var showAddSubtask = false
    @State var parentTaskForSubtask: Task?
    @State private var showAutoCompleteCelebration = false
    @State private var autoCompletedParentTitle = ""
    @State var summaryService = DailySummaryService.shared
    @State var listService = TaskListService.shared
    @AppStorage(AppConstants.StorageKey.summaryPromptHour) var summaryPromptHour: Int = AppConstants.Defaults.summaryPromptHour
    @AppStorage(AppConstants.StorageKey.morningBriefingEnabled) var morningBriefingEnabled: Bool = true
    @AppStorage(AppConstants.StorageKey.lastMorningBriefingDate) var lastMorningBriefingDate: Double = 0
    @AppStorage(AppConstants.StorageKey.lastPlanYourDayDate) var lastPlanYourDayDate: Double = 0
    @State var showPlanYourDay = false
    @State var actionToast: ActionToastData?
    @State var highlightedTaskID: UUID?
    @State var isNextUpPulsing = false
    @State var optimisticInProgressID: UUID?
    @State var optimisticPausedID: UUID?
    @Environment(FocusSessionCoordinator.self) var focusCoordinator

    // Internal accessors for viewModel (used by extensions in other files)
    var todayViewModel: TodayViewModel { viewModel }
    var todayPrioritizationService: PrioritizationService { prioritizationService }

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
        .onReceive(NotificationCenter.default.publisher(for: .linkedEventDeletedExternally)) { notification in
            if let title = notification.userInfo?["taskTitle"] as? String {
                actionToast = ActionToastData(
                    message: "Calendar event removed for \"\(title)\"",
                    icon: "calendar.badge.minus",
                    iconColor: .orange
                )
            }
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
    var shouldShowPlanYourDayPrompt: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        let isMorning = hour >= 5 && hour < 12

        // Check if already viewed today
        let lastViewedDate = Date(timeIntervalSince1970: lastPlanYourDayDate)
        let alreadyViewedToday = Calendar.current.isDateInToday(lastViewedDate)

        return isMorning && CalendarService.shared.hasCalendarAccess && !alreadyViewedToday
    }

    // MARK: - Morning Briefing Prompt

    /// Show morning briefing prompt between 5 AM and 12 PM when there are tasks
    var shouldShowMorningBriefingPrompt: Bool {
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
    var shouldShowSummaryPrompt: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= summaryPromptHour && viewModel.completedTaskCount > 0 && !summaryService.hasTodaySummary
    }

    // MARK: - Undo Handling

    func handleUndo(_ action: UndoAction) {
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
    func onUndoToastDismissed() {
        // Commit any pending changes (e.g., from delete with allowUndo)
        viewModel.commitPendingChanges()
    }

    func showUndoToast(_ action: UndoAction, snapshot: Task) {
        undoSnapshot = snapshot
        undoAction = action
    }

    @ToolbarContentBuilder
    var addTaskToolbar: some ToolbarContent {
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

    // MARK: - Conflict Handling

    func scanForConflicts() {
        let allTasks = viewModel.overdueTasks + viewModel.todayTasks
        _ = conflictService.scanForConflicts(tasks: allTasks)
    }

    func applyReschedule(option: RescheduleOption, to task: Task) {
        _ = rescheduleService.applyReschedule(option: option, to: task, taskService: TaskService.shared)
        scanForConflicts()
    }

    func applyBatchReschedule(_ batchSuggestion: BatchRescheduleSuggestion) {
        _ = rescheduleService.applyBatchReschedule(batch: batchSuggestion, taskService: TaskService.shared)
        scanForConflicts()
    }

    func listColorHex(for task: Task) -> String? {
        guard let listID = task.listID,
              let list = listService.getList(byID: listID),
              !list.isDefault else { return nil }
        return list.colorHex
    }

    func pushToTomorrow(_ task: Task) {
        _ = rescheduleService.pushTaskToTomorrow(task, taskService: TaskService.shared)
        scanForConflicts()
    }

    func moveToToday(_ task: Task) {
        viewModel.updateTaskDueDate(task, dueDate: Date())
        scanForConflicts()
    }

    // MARK: - Scheduling

    func scheduleTaskAction(_ task: Task) {
        taskToSchedule = task
    }

    func defaultScheduleTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        // Default to next hour
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        if let nextHour = calendar.date(from: components)?.addingTimeInterval(3600) {
            return nextHour
        }
        return now
    }

    func scheduleTask(_ task: Task, startTime: Date, duration: TimeInterval) {
        try? TaskService.shared.createCalendarEvent(for: task, startDate: startTime, duration: duration)
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environment(FocusSessionCoordinator())
}

// MARK: - Test Support

#if DEBUG
extension TodayView {
    /// Test-only initializer for snapshot tests with injected ViewModel.
    init(viewModel: TodayViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
}
#endif
