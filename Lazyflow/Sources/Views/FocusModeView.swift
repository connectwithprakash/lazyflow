import SwiftUI

/// Full-screen immersive focus experience for a single task.
/// "Calm Precision" design: dark background, centered title, progress ring.
struct FocusModeView: View {
    @EnvironmentObject private var coordinator: FocusSessionCoordinator

    @State private var showSuccess = false
    @State private var showSwitchSheet = false
    @State private var showTaskDetail = false
    @State private var breatheOpacity: Double = 0.55
    @State private var focusActionToast: ActionToastData?

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
        return parts.joined(separator: " · ")
    }

    // MARK: - Timer Ring (240pt, 6pt stroke)

    private let ringSize: CGFloat = 240
    private let ringStrokeWidth: CGFloat = 6

    private func timerRing(_ task: Task) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let progress = ringProgress(for: task)
            let paused = coordinator.isPaused

            ZStack {
                // Track circle
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: ringStrokeWidth)
                    .frame(width: ringSize, height: ringSize)

                // Progress arc (butt linecap — glow dots handle endpoints)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.Lazyflow.accent,
                        style: StrokeStyle(lineWidth: ringStrokeWidth, lineCap: .butt)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.Lazyflow.accent.opacity(0.25), radius: 4)
                    .opacity(paused ? 0.4 : 1.0)

                // Start dot — fixed at 12 o'clock
                Circle()
                    .fill(Color.Lazyflow.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.Lazyflow.accent.opacity(0.4), radius: 4)
                    .offset(y: -(ringSize / 2))
                    .opacity(paused ? 0 : 1)

                // Progress tip dot — moves with elapsed time
                if progress > 0.005 {
                    let angle = Double(progress) * 2 * .pi - .pi / 2
                    let radius = Double(ringSize / 2)
                    Circle()
                        .fill(Color.Lazyflow.accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.Lazyflow.accent.opacity(0.4), radius: 4)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                        .opacity(paused ? 0 : 1)
                }

                // Timer text inside ring
                VStack(spacing: 10) {
                    Text(elapsedTimeString(for: task))
                        .font(.system(size: 52, weight: .light))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.95))
                        .tracking(-2)
                        .accessibilityLabel("Timer: \(elapsedTimeString(for: task))")

                    Text(paused ? "Paused" : "Focusing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(paused ? .orange : Color.Lazyflow.accent)
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
                coordinator.togglePause()
                focusActionToast = ActionToastData(
                    message: coordinator.isPaused ? "Timer paused" : "Timer resumed",
                    icon: coordinator.isPaused ? "pause.fill" : "play.fill",
                    iconColor: coordinator.isPaused ? .orange : Color.Lazyflow.accent
                )
            }
            .accessibilityHint("Tap to \(paused ? "resume" : "pause") timer")
        }
    }

    private func ringProgress(for task: Task) -> CGFloat {
        let elapsed = task.elapsedTime ?? (task.accumulatedDuration > 0 ? task.accumulatedDuration : 0)
        guard let estimate = task.estimatedDuration, estimate > 0, elapsed > 0 else {
            return 0
        }
        return min(CGFloat(elapsed / estimate), 1.0)
    }

    private func elapsedTimeString(for task: Task) -> String {
        if let elapsed = task.elapsedTime {
            return Task.formatDurationAsTimer(elapsed)
        }
        if task.accumulatedDuration > 0 {
            return Task.formatDurationAsTimer(task.accumulatedDuration)
        }
        return "0:00"
    }

    // MARK: - Action Bar

    private func actionBar(_ task: Task) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
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
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignSystem.TouchTarget.minimum)
                        .background(.white.opacity(0.08))
                        .cornerRadius(DesignSystem.CornerRadius.large)
                }
                .buttonStyle(.plain)

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
