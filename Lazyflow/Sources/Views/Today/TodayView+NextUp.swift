import SwiftUI
import UIKit

extension TodayView {

    // MARK: - Next Up Section

    var nextUpSectionHeader: some View {
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
    var effectiveNextUpSuggestion: TaskSuggestion? {
        todayPrioritizationService.cachedSuggestions.first {
            !$0.task.isCompleted && !optimisticallyCompletedIDs.contains($0.task.id)
        }
    }

    /// Overdue tasks excluding the Next Up task to avoid duplicate display
    var overdueTasksExcludingNextUp: [Task] {
        let nextUpID = effectiveNextUpSuggestion?.task.id
        return todayViewModel.overdueTasks.filter { $0.id != nextUpID }
    }

    /// Today tasks excluding the Next Up task to avoid duplicate display
    var todayTasksExcludingNextUp: [Task] {
        let nextUpID = effectiveNextUpSuggestion?.task.id
        return todayViewModel.todayTasks.filter { $0.id != nextUpID }
    }

    /// Resolve the live task from TaskService (Core Data) instead of stale suggestion snapshot
    func liveTask(for suggestion: TaskSuggestion) -> Task {
        TaskService.shared.tasks.first { $0.id == suggestion.task.id } ?? suggestion.task
    }

    /// Whether the Next Up task is effectively in progress (optimistic or persisted)
    func isNextUpInProgress(_ task: Task) -> Bool {
        if task.id == optimisticInProgressID { return true }
        if task.id == optimisticPausedID { return false }
        return task.isInProgress
    }

    /// Effective elapsed time accounting for optimistic state.
    /// When optimistic resume is active but Core Data hasn't set startedAt yet,
    /// falls back to accumulatedDuration so the timer doesn't flicker to 0:00.
    func effectiveElapsedTime(for task: Task) -> TimeInterval {
        if let elapsed = task.elapsedTime {
            return elapsed
        }
        // Optimistic in-progress but startedAt not yet persisted — show accumulated time
        if task.id == optimisticInProgressID {
            return task.accumulatedDuration
        }
        return 0
    }

    @ViewBuilder
    func nextUpCard(for suggestion: TaskSuggestion) -> some View {
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
                                let elapsed = effectiveElapsedTime(for: task)
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "timer")
                                        .font(.caption2)
                                    Text(Task.formatDurationAsTimer(elapsed))
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
                    todayViewModel.selectedTask = task
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
                    let elapsed = effectiveElapsedTime(for: task)
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
            nextUpActionRow(task: task, suggestion: suggestion, inProgress: inProgress)
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
            // Update pulsing based on final persisted state
            if persisted && !reduceMotion {
                isNextUpPulsing = false
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isNextUpPulsing = true
                }
            } else if persisted {
                isNextUpPulsing = true
            } else if optimisticInProgressID != task.id {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isNextUpPulsing = false
                }
            }
        }
    }

    // MARK: - Next Up Action Row

    @ViewBuilder
    func nextUpActionRow(task: Task, suggestion: TaskSuggestion, inProgress: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if inProgress {
                // Pause + Focus
                Button {
                    let taskID = task.id
                    withAnimation(.easeInOut(duration: 0.3)) {
                        optimisticInProgressID = nil
                        optimisticPausedID = taskID
                    }
                    todayViewModel.stopWorking(on: task)
                    // Safety: clear stuck optimistic state after 2s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if optimisticPausedID == taskID { optimisticPausedID = nil }
                    }
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
                    todayPrioritizationService.recordSuggestionFeedback(
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
                    let taskID = task.id
                    withAnimation(.easeInOut(duration: 0.3)) {
                        optimisticPausedID = nil
                        optimisticInProgressID = taskID
                    }
                    todayPrioritizationService.recordSuggestionFeedback(
                        task: task, action: .startedImmediately, score: suggestion.score
                    )
                    if hasWorkedBefore {
                        todayViewModel.resumeWorking(on: task)
                    } else {
                        todayViewModel.startWorking(on: task)
                    }
                    // Safety: clear stuck optimistic state after 2s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if optimisticInProgressID == taskID { optimisticInProgressID = nil }
                    }
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
                    todayPrioritizationService.recordSuggestionFeedback(
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

    /// Optimistically complete a task from the Next Up card
    func optimisticallyComplete(_ task: Task, suggestion: TaskSuggestion) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        _ = withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
            optimisticallyCompletedIDs.insert(task.id)
        }

        showUndoToast(.completed(task), snapshot: task)
        todayViewModel.toggleTaskCompletion(task)
    }

    func showSkipHighlight(for task: Task) {
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
