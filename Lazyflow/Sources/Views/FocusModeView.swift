import SwiftUI

/// Full-screen immersive focus experience for a single task.
/// "Calm Precision" design: dark background, centered title, progress ring.
/// Includes collapsible subtasks/notes panels and Pomodoro timer mode.
struct FocusModeView: View {
    @EnvironmentObject private var coordinator: FocusSessionCoordinator
    @StateObject private var taskService = TaskService.shared

    @State private var showSuccess = false
    @State private var showSwitchSheet = false
    @State private var showTaskDetail = false
    @State private var breatheOpacity: Double = 0.55
    @State private var focusActionToast: ActionToastData?
    @State private var showSubtasks = false
    @State private var showNotes = false

    // Dark immersive background color
    private let immersiveBackground = Color(red: 0.067, green: 0.075, blue: 0.075) // #111313

    var body: some View {
        ZStack {
            immersiveBackground.ignoresSafeArea()

            // Subtle ambient gradient
            RadialGradient(
                colors: [
                    Color.Lazyflow.accent.opacity(0.06),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.45),
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.35
            )
            .ignoresSafeArea()

            if let task = coordinator.focusedTask {
                focusContent(task)
            }

            if showSuccess {
                successOverlay
            }
        }
        .preferredColorScheme(.dark)
        .actionToast($focusActionToast)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showSwitchSheet) {
            SwitchFocusTaskSheet()
                .environmentObject(coordinator)
        }
        .onChange(of: coordinator.focusTaskID) { oldValue, newValue in
            if let newValue, oldValue != nil, oldValue != newValue,
               let newTask = coordinator.focusedTask {
                let truncated = String(newTask.title.prefix(30))
                focusActionToast = ActionToastData(
                    message: "Switched to: \(truncated)",
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: Color.Lazyflow.accent
                )
            }
        }
    }

    // MARK: - Focus Content

    private func focusContent(_ task: Task) -> some View {
        VStack(spacing: 0) {
            topBar(task)

            ScrollView {
                Spacer(minLength: DesignSystem.Spacing.xl)

                // Center block: title + ring grouped
                VStack(spacing: 0) {
                    taskTitleArea(task)
                    timerRing(task)
                }

                // Subtasks panel (collapsed by default)
                if task.hasSubtasks {
                    subtasksPanel(task)
                }

                // Notes panel (collapsed by default)
                if let notes = task.notes, !notes.isEmpty {
                    notesPanel(notes)
                }

                Spacer(minLength: DesignSystem.Spacing.xl)
            }
            .scrollIndicators(.hidden)

            actionBar(task)
        }
        .sheet(isPresented: $showTaskDetail) {
            NavigationStack {
                TaskDetailView(task: task)
            }
        }
    }

    // MARK: - Top Bar

    private func topBar(_ task: Task) -> some View {
        HStack {
            Button {
                coordinator.dismissFocus()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
            }
            .accessibilityLabel("Close Focus Mode")

            Spacer()

            // Timer mode picker
            Menu {
                ForEach(FocusSessionCoordinator.TimerMode.allCases) { mode in
                    Button {
                        coordinator.setTimerMode(mode)
                    } label: {
                        Label(
                            mode.displayName,
                            systemImage: mode == .stopwatch ? "stopwatch" : "timer"
                        )
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: coordinator.timerMode == .stopwatch ? "stopwatch" : "timer")
                        .font(.system(size: 13, weight: .semibold))
                    Text(coordinator.timerMode.displayName)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.45))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
            .accessibilityLabel("Timer mode: \(coordinator.timerMode.displayName)")

            Menu {
                Button {
                    showTaskDetail = true
                } label: {
                    Label("Open Task Details", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
            }
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    // MARK: - Task Title Area (centered, minimal)

    private func taskTitleArea(_ task: Task) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(task.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            let subtitle = subtitleText(for: task)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xl)
    }

    private func subtitleText(for task: Task) -> String {
        var parts: [String] = []
        if let dueDate = task.dueDate {
            if Calendar.current.isDateInToday(dueDate) {
                parts.append("Due \(dueDate.formatted(date: .omitted, time: .shortened))")
            } else {
                parts.append("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        if let duration = task.estimatedDuration, duration > 0 {
            let mins = Int(duration / 60)
            if mins >= 60 {
                parts.append("Est. \(mins / 60)h \(mins % 60) min")
            } else {
                parts.append("Est. \(mins) min")
            }
        }
        if coordinator.timerMode == .pomodoro {
            parts.append("Pomodoro \(coordinator.pomodoroCompletedIntervals + 1)")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Timer Ring (240pt, 6pt stroke)

    private let ringSize: CGFloat = 240
    private let ringStrokeWidth: CGFloat = 6

    private func timerRing(_ task: Task) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let progress = ringProgress(for: task)
            let paused = coordinator.isPaused
            let isPomodoro = coordinator.timerMode == .pomodoro
            let isPomBreak = coordinator.isPomodoroBreak
            let ringColor = isPomBreak ? Color.orange : Color.Lazyflow.accent

            ZStack {
                // Track circle
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: ringStrokeWidth)
                    .frame(width: ringSize, height: ringSize)

                // Progress arc (butt linecap — glow dots handle endpoints)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: ringStrokeWidth, lineCap: .butt)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.25), radius: 4)
                    .opacity(paused ? 0.4 : 1.0)

                // Start dot — fixed at 12 o'clock
                Circle()
                    .fill(ringColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: ringColor.opacity(0.4), radius: 4)
                    .offset(y: -(ringSize / 2))
                    .opacity(paused ? 0 : 1)

                // Progress tip dot — moves with elapsed time
                if progress > 0.005 {
                    let angle = Double(progress) * 2 * .pi - .pi / 2
                    let radius = Double(ringSize / 2)
                    Circle()
                        .fill(ringColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: ringColor.opacity(0.4), radius: 4)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                        .opacity(paused ? 0 : 1)
                }

                // Timer text inside ring
                VStack(spacing: 10) {
                    Text(timerDisplayString(for: task))
                        .font(.system(size: 52, weight: .light))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.95))
                        .tracking(-2)
                        .accessibilityLabel("Timer: \(timerDisplayString(for: task))")

                    Text(timerStatusLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(statusLabelColor)
                        .tracking(0.3)
                        .opacity(paused ? 1.0 : breatheOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                breatheOpacity = 1.0
                            }
                        }
                }
            }
            .padding(.bottom, DesignSystem.Spacing.xxxl)
            .contentShape(Circle())
            .onTapGesture {
                if isPomodoro && coordinator.isPomodoroIntervalComplete {
                    // Tapping when interval complete transitions to next phase
                    if isPomBreak {
                        coordinator.endPomodoroBreak()
                        focusActionToast = ActionToastData(
                            message: "Work interval started",
                            icon: "flame.fill",
                            iconColor: Color.Lazyflow.accent
                        )
                    } else {
                        coordinator.startPomodoroBreak()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        focusActionToast = ActionToastData(
                            message: "Break time! \(Int(coordinator.pomodoroBreakInterval / 60)) min",
                            icon: "cup.and.saucer.fill",
                            iconColor: .orange
                        )
                    }
                } else {
                    coordinator.togglePause()
                    focusActionToast = ActionToastData(
                        message: coordinator.isPaused ? "Timer paused" : "Timer resumed",
                        icon: coordinator.isPaused ? "pause.fill" : "play.fill",
                        iconColor: coordinator.isPaused ? .orange : Color.Lazyflow.accent
                    )
                }
            }
            .accessibilityHint(pomodoroTapHint)
        }
    }

    private var timerStatusLabel: String {
        if coordinator.isPaused { return "Paused" }
        if coordinator.timerMode == .pomodoro {
            if coordinator.isPomodoroIntervalComplete {
                return coordinator.isPomodoroBreak ? "Tap to resume" : "Tap for break"
            }
            return coordinator.isPomodoroBreak ? "Break" : "Focusing"
        }
        return "Focusing"
    }

    private var statusLabelColor: Color {
        if coordinator.isPaused { return .orange }
        if coordinator.isPomodoroBreak { return .orange }
        if coordinator.timerMode == .pomodoro && coordinator.isPomodoroIntervalComplete {
            return Color.Lazyflow.success
        }
        return Color.Lazyflow.accent
    }

    private var pomodoroTapHint: String {
        if coordinator.timerMode == .pomodoro && coordinator.isPomodoroIntervalComplete {
            return coordinator.isPomodoroBreak ? "Tap to start next work interval" : "Tap to take a break"
        }
        return "Tap to \(coordinator.isPaused ? "resume" : "pause") timer"
    }

    private func ringProgress(for task: Task) -> CGFloat {
        if coordinator.timerMode == .pomodoro {
            let interval = coordinator.isPomodoroBreak
                ? coordinator.pomodoroBreakInterval
                : coordinator.pomodoroWorkInterval
            guard interval > 0 else { return 0 }
            let remaining = coordinator.pomodoroRemainingSeconds
            return min(CGFloat(1.0 - remaining / interval), 1.0)
        }

        let elapsed = task.elapsedTime ?? (task.accumulatedDuration > 0 ? task.accumulatedDuration : 0)
        guard let estimate = task.estimatedDuration, estimate > 0, elapsed > 0 else {
            return 0
        }
        return min(CGFloat(elapsed / estimate), 1.0)
    }

    private func timerDisplayString(for task: Task) -> String {
        if coordinator.timerMode == .pomodoro {
            let remaining = max(0, coordinator.pomodoroRemainingSeconds)
            return Task.formatDurationAsTimer(remaining)
        }

        if let elapsed = task.elapsedTime {
            return Task.formatDurationAsTimer(elapsed)
        }
        if task.accumulatedDuration > 0 {
            return Task.formatDurationAsTimer(task.accumulatedDuration)
        }
        return "0:00"
    }

    // MARK: - Subtasks Panel

    private func subtasksPanel(_ task: Task) -> some View {
        VStack(spacing: 0) {
            // Header button
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    showSubtasks.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 14))
                    Text("Subtasks")
                        .font(.system(size: 14, weight: .medium))
                    Text(task.subtaskProgressString ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Image(systemName: showSubtasks ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if showSubtasks {
                VStack(spacing: 0) {
                    ForEach(task.subtasks) { subtask in
                        focusSubtaskRow(subtask)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(.white.opacity(0.04))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.md)
    }

    private func focusSubtaskRow(_ subtask: Task) -> some View {
        Button {
            taskService.toggleSubtaskCompletion(subtask)
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Checkbox
                ZStack {
                    Circle()
                        .strokeBorder(
                            subtask.isCompleted ? Color.Lazyflow.success : .white.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)

                    if subtask.isCompleted {
                        Circle()
                            .fill(Color.Lazyflow.success)
                            .frame(width: 18, height: 18)

                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(subtask.title)
                    .font(.system(size: 14))
                    .foregroundColor(
                        subtask.isCompleted
                            ? .white.opacity(0.3)
                            : .white.opacity(0.75)
                    )
                    .strikethrough(subtask.isCompleted, color: .white.opacity(0.3))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes Panel

    private func notesPanel(_ notes: String) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    showNotes.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 14))
                    Text("Notes")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: showNotes ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            if showNotes {
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(.white.opacity(0.04))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Action Bar

    private func actionBar(_ task: Task) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Pomodoro break banner
            if coordinator.timerMode == .pomodoro && coordinator.isPomodoroIntervalComplete && !coordinator.isPomodoroBreak {
                Button {
                    coordinator.startPomodoroBreak()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    focusActionToast = ActionToastData(
                        message: "Break time! \(Int(coordinator.pomodoroBreakInterval / 60)) min",
                        icon: "cup.and.saucer.fill",
                        iconColor: .orange
                    )
                } label: {
                    Label("Take Pomodoro Break", systemImage: "cup.and.saucer.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignSystem.TouchTarget.minimum)
                        .background(Color.orange)
                        .cornerRadius(DesignSystem.CornerRadius.large)
                }
                .buttonStyle(.plain)
            }

            // Mark Complete — primary CTA
            Button {
                performCompletion(task)
            } label: {
                Label("Mark Complete", systemImage: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .background(Color.Lazyflow.accent)
                    .cornerRadius(DesignSystem.CornerRadius.large)
            }
            .buttonStyle(.plain)

            // Secondary row: Take a Break, Switch Task
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    coordinator.takeBreak()
                } label: {
                    Label("Take a Break", systemImage: "moon.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(coordinator.isPomodoroBreak ? 0.3 : 0.7))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignSystem.TouchTarget.minimum)
                        .background(.white.opacity(0.08))
                        .cornerRadius(DesignSystem.CornerRadius.large)
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isPomodoroBreak)

                Button {
                    showSwitchSheet = true
                } label: {
                    Label("Switch Task", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignSystem.TouchTarget.minimum)
                        .background(.white.opacity(0.08))
                        .cornerRadius(DesignSystem.CornerRadius.large)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            // Green circle with checkmark (matches prototype)
            ZStack {
                Circle()
                    .fill(Color.Lazyflow.success)
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.Lazyflow.success.opacity(0.3), radius: 20)

                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(showSuccess ? 1.0 : 0.3)
            .opacity(showSuccess ? 1.0 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showSuccess)
        }
        .accessibilityLabel("Task completed")
    }

    // MARK: - Completion

    private func performCompletion(_ task: Task) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSuccess = true
        coordinator.markComplete()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            coordinator.finishCompletion()
        }
    }
}
