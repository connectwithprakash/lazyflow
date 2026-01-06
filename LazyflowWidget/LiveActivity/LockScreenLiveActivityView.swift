import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen presentation for Task Live Activity - Elegant centered design
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TaskActivityAttributes>

    private var state: TaskActivityAttributes.ContentState {
        context.state
    }

    private var progressColor: Color {
        if state.hasInProgressTask {
            return WidgetDesign.priorityColor(for: state.inProgressPriority)
        }
        return WidgetDesign.accentColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: Progress + Status
            headerSection
                .padding(.bottom, 12)

            // Subtle divider
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // Task hierarchy with natural fade
            taskHierarchy
        }
        .padding(16)
        .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Progress ring
            LiveActivityProgressRing(progress: state.progress, accentColor: progressColor)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                if state.hasInProgressTask, let startedAt = state.inProgressStartedAt {
                    // Show "Working" status with timer
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text("Working")
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(progressColor)

                    Text(startedAt, style: .timer)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                } else {
                    // Show task count
                    Text("Today's Tasks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text("\(state.completedCount) of \(state.totalCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var taskHierarchy: some View {
        if state.remainingCount == 0 {
            // Celebration state
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(WidgetDesign.accentColor)
                Text("All complete!")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetDesign.accentColor)
            }
            .frame(maxWidth: .infinity)
        } else if state.hasInProgressTask, let inProgressTask = state.inProgressTaskTitle {
            // Show in-progress task prominently
            VStack(alignment: .leading, spacing: 8) {
                // Current in-progress task
                HStack(spacing: 8) {
                    LockScreenPriorityDot(priority: state.inProgressPriority)

                    Text(inProgressTask)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                // Remaining tasks
                if state.remainingCount > 1 {
                    Text("\(state.remainingCount - 1) more task\(state.remainingCount > 2 ? "s" : "") remaining")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Normal task list
            VStack(alignment: .leading, spacing: 6) {
                // Current task - Hero prominence
                if let currentTask = state.currentTaskTitle {
                    HStack(spacing: 8) {
                        LockScreenPriorityDot(priority: state.currentTaskPriority)

                        Text(currentTask)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }

                // Next task - Secondary
                if let nextTask = state.nextTaskTitle {
                    HStack(spacing: 8) {
                        LockScreenPriorityDot(priority: state.nextTaskPriority, size: 6)
                            .opacity(0.7)

                        Text(nextTask)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Remaining count - Tertiary fade
                if state.remainingCount > 2 {
                    Text("+\(state.remainingCount - 2) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Priority dot for lock screen
struct LockScreenPriorityDot: View {
    let priority: Int16
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(WidgetDesign.priorityColor(for: priority))
            .frame(width: size, height: size)
    }
}

/// Compact progress ring for Live Activity header
struct LiveActivityProgressRing: View {
    let progress: Double
    var accentColor: Color = WidgetDesign.accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
    }
}
