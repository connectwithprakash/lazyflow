import SwiftUI
import LazyflowCore
import LazyflowUI

extension TodayView {

    var todayContent: some View {
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()

            if todayViewModel.isLoading {
                ProgressView()
            } else {
                // ALWAYS show taskListView - never switch views during deletion animation
                // Empty state is handled INSIDE the List to prevent UICollectionView crash
                taskListView
            }
        }
        .refreshable {
            todayViewModel.refreshTasks()
            scanForConflicts()
        }
    }

    // MARK: - Conflicts Banner

    var conflictsBanner: some View {
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

    // MARK: - Task List

    var taskListView: some View {
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
            // Exclude the Next Up task to avoid duplicate display
            Section {
                ForEach(overdueTasksExcludingNextUp) { task in
                    flatTaskRows(task: task, isCompleted: false)
                        .id(task.id)
                }
            } header: {
                if !overdueTasksExcludingNextUp.isEmpty {
                    taskSectionHeader(title: "Overdue", color: Color.Lazyflow.error, count: overdueTasksExcludingNextUp.count)
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 5: Today tasks - ALWAYS present (even when empty)
            // Exclude the Next Up task to avoid duplicate display
            Section {
                ForEach(todayTasksExcludingNextUp) { task in
                    flatTaskRows(task: task, isCompleted: false)
                        .id(task.id)
                }
            } header: {
                if !todayTasksExcludingNextUp.isEmpty {
                    taskSectionHeader(title: "Today", color: Color.Lazyflow.accent, count: todayTasksExcludingNextUp.count)
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 6: Completed tasks - ALWAYS present (even when empty)
            Section {
                ForEach(todayViewModel.completedTodayTasks) { task in
                    flatTaskRows(task: task, isCompleted: true)
                        .id(task.id)
                }
            } header: {
                if !todayViewModel.completedTodayTasks.isEmpty {
                    completedSectionHeader(count: todayViewModel.completedTodayTasks.count)
                }
            }
            .listRowBackground(Color.adaptiveBackground)
            .listRowSeparator(.hidden)

            // Section 7: Empty state - ALWAYS present
            Section {
                if todayViewModel.totalTaskCount == 0 && todayViewModel.completedTaskCount == 0 {
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

    func taskSectionHeader(title: String, color: Color, count: Int) -> some View {
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

    func completedSectionHeader(count: Int) -> some View {
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
    func flatTaskRows(task: Task, isCompleted: Bool) -> some View {
        // Parent task row
        TaskRowView(
            task: task,
            onToggle: {
                if !isCompleted {
                    showUndoToast(.completed(task), snapshot: task)
                }
                todayViewModel.toggleTaskCompletion(task)
            },
            onTap: { todayViewModel.selectedTask = task },
            onSchedule: isCompleted ? nil : { scheduleTaskAction($0) },
            onPushToTomorrow: isCompleted ? nil : { task in
                showUndoToast(.pushedToTomorrow(task), snapshot: task)
                pushToTomorrow(task)
            },
            onMoveToToday: isCompleted ? nil : { task in
                showUndoToast(.movedToToday(task), snapshot: task)
                moveToToday(task)
            },
            onPriorityChange: { todayViewModel.updateTaskPriority($0, priority: $1) },
            onDueDateChange: { todayViewModel.updateTaskDueDate($0, dueDate: $1) },
            onDelete: { task in
                if !isCompleted {
                    showUndoToast(.deleted(task), snapshot: task)
                    // Use allowUndo: true to delay save and allow rollback
                    todayViewModel.deleteTask(task, allowUndo: true)
                } else {
                    // Completed tasks don't need undo
                    todayViewModel.deleteTask(task, allowUndo: false)
                }
            },
            onStartWorking: isCompleted ? nil : {
                if $0.accumulatedDuration > 0 {
                    todayViewModel.resumeWorking(on: $0)
                } else {
                    todayViewModel.startWorking(on: $0)
                }
            },
            onStopWorking: isCompleted ? nil : { todayViewModel.stopWorking(on: $0) },
            onEnterFocus: isCompleted ? nil : { focusCoordinator.enterFocus(task: $0) },
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
                isExpanded: todayViewModel.isExpanded(task.id),
                onToggle: {
                    withAnimation(DesignSystem.Animation.quick) {
                        todayViewModel.toggleExpansion(task.id)
                    }
                }
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 16))
            .listRowBackground(Color.adaptiveBackground)

            // Subtask rows (if expanded)
            if todayViewModel.isExpanded(task.id) {
                ForEach(Array(task.subtasks.enumerated()), id: \.element.id) { index, subtask in
                    SubtaskRowView(
                        subtask: subtask,
                        onToggle: {
                            TaskService.shared.toggleSubtaskCompletion(subtask)
                            todayViewModel.refreshTasks()
                            // Auto-collapse when all subtasks completed
                            if task.subtasks.filter({ !$0.isCompleted }).count <= 1 && !subtask.isCompleted {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(DesignSystem.Animation.standard) {
                                        todayViewModel.setExpanded(task.id, expanded: false)
                                    }
                                }
                            }
                        },
                        onTap: { todayViewModel.selectedTask = subtask },
                        onDelete: { subtask in
                            // Show undo toast and delete with allowUndo
                            showUndoToast(.deleted(subtask), snapshot: subtask)
                            TaskService.shared.deleteTask(subtask, allowUndo: true)
                            todayViewModel.refreshTasks()
                        },
                        onPromote: { subtask in
                            TaskService.shared.promoteSubtaskToTask(subtask)
                            todayViewModel.refreshTasks()
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

    // MARK: - Progress Header

    var progressHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(Date().fullFormatted)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                Spacer()

                Text("\(todayViewModel.completedTaskCount)/\(todayViewModel.totalTaskCount + todayViewModel.completedTaskCount) done")
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
                        .frame(width: geometry.size.width * todayViewModel.progressPercentage, height: 8)
                        .animation(.spring(), value: todayViewModel.progressPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    // MARK: - Prompt Cards

    var planYourDayPromptCard: some View {
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

    var morningBriefingPromptCard: some View {
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

                    Text("You have \(todayViewModel.totalTaskCount) task\(todayViewModel.totalTaskCount == 1 ? "" : "s") planned for today")
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

    var dailySummaryPromptCard: some View {
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
