import SwiftUI

/// Full-screen immersive focus experience for a single task.
struct FocusModeView: View {
    @EnvironmentObject private var coordinator: FocusSessionCoordinator

    @State private var showSuccess = false
    @State private var showSwitchSheet = false
    @State private var showTaskDetail = false

    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()

            if let task = coordinator.focusedTask {
                focusContent(task)
            }

            if showSuccess {
                successOverlay
            }
        }
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
    }

    // MARK: - Focus Content

    private func focusContent(_ task: Task) -> some View {
        VStack(spacing: 0) {
            topBar(task)

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    taskIdentityCard(task)
                    timerBlock(task)
                }
                .padding(.top, DesignSystem.Spacing.xl)
            }

            Spacer(minLength: 0)

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
                    .foregroundColor(Color.Lazyflow.textSecondary)
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
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - Task Identity Card

    private func taskIdentityCard(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if task.priority != .none {
                PriorityBadge(priority: task.priority)
            }

            Text(task.title)
                .font(DesignSystem.Typography.title2)
                .foregroundColor(Color.Lazyflow.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DesignSystem.Spacing.sm) {
                if let dueDate = task.dueDate {
                    DueDateBadge(
                        date: dueDate,
                        isOverdue: task.isOverdue,
                        isDueToday: Calendar.current.isDateInToday(dueDate)
                    )
                }

                if let duration = task.estimatedDuration, duration > 0 {
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
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Timer Block

    private func timerBlock(_ task: Task) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(elapsedTimeString(for: task))
                    .font(DesignSystem.Typography.title1)
                    .monospacedDigit()
                    .foregroundColor(Color.Lazyflow.textPrimary)
                    .accessibilityLabel("Timer: \(elapsedTimeString(for: task))")

                Text("Focusing")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.accent)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxxl)
    }

    private func elapsedTimeString(for task: Task) -> String {
        guard let elapsed = task.elapsedTime else { return "0:00" }
        return Task.formatDurationAsTimer(elapsed)
    }

    // MARK: - Action Bar

    private func actionBar(_ task: Task) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                performCompletion(task)
            } label: {
                Label("Mark Complete", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    coordinator.takeBreak()
                } label: {
                    Label("Take a Break", systemImage: "moon.fill")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    showSwitchSheet = true
                } label: {
                    Label("Switch Task", systemImage: "arrow.triangle.2.circlepath")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.TouchTarget.comfortable)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.Lazyflow.success)
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
