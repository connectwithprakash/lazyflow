import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Priority Colors

extension WidgetDesign {
    static func priorityColor(for priority: Int16) -> Color {
        switch priority {
        case 4: return urgentColor
        case 3: return highColor
        case 2: return mediumColor
        case 1: return lowColor
        default: return Color.gray.opacity(0.5)
        }
    }
}

// MARK: - Dynamic Island Compact Views

/// Compact leading view - Progress ring with in-progress indicator
struct DynamicIslandCompactLeading: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        ZStack {
            CompactProgressRing(
                progress: state.progress,
                accentColor: state.hasInProgressTask
                    ? WidgetDesign.priorityColor(for: state.inProgressPriority)
                    : WidgetDesign.accentColor
            )
            .frame(width: 24, height: 24)

            // Show play indicator when task is in progress
            if state.hasInProgressTask {
                Circle()
                    .fill(WidgetDesign.priorityColor(for: state.inProgressPriority))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

/// Compact trailing view - Task count
struct DynamicIslandCompactTrailing: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 2) {
            if state.hasInProgressTask {
                // Show elapsed time when working
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(WidgetDesign.priorityColor(for: state.inProgressPriority))
            }

            Text("\(state.completedCount)/\(state.totalCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Dynamic Island Expanded Views

/// Expanded leading region - Progress ring with in-progress state
struct DynamicIslandExpandedLeading: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        ZStack {
            CompactProgressRing(
                progress: state.progress,
                accentColor: state.hasInProgressTask
                    ? WidgetDesign.priorityColor(for: state.inProgressPriority)
                    : WidgetDesign.accentColor
            )
            .frame(width: 28, height: 28)

            if state.hasInProgressTask {
                Image(systemName: "play.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(WidgetDesign.priorityColor(for: state.inProgressPriority))
            }
        }
    }
}

/// Expanded trailing region - Count or elapsed time
struct DynamicIslandExpandedTrailing: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        if state.hasInProgressTask, let startedAt = state.inProgressStartedAt {
            // Show elapsed time when working
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 10))
                Text(startedAt, style: .timer)
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(WidgetDesign.priorityColor(for: state.inProgressPriority))
            .monospacedDigit()
        } else {
            Text("\(state.completedCount) of \(state.totalCount)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

/// Expanded bottom region - Task details with priority
struct DynamicIslandExpandedView: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // In-progress task (hero) or current task
            if let inProgressTask = state.inProgressTaskTitle {
                // Show in-progress task prominently
                HStack(spacing: 8) {
                    PriorityDot(priority: state.inProgressPriority)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Working on")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }

                        Text(inProgressTask)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
            } else if let currentTask = state.currentTaskTitle {
                // Show next task to work on
                HStack(spacing: 8) {
                    PriorityDot(priority: state.currentTaskPriority)

                    Text(currentTask)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            // Upcoming tasks breadcrumb
            upcomingTasksBreadcrumb
        }
    }

    @ViewBuilder
    private var upcomingTasksBreadcrumb: some View {
        if state.remainingCount == 0 {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Text("All complete!")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(WidgetDesign.accentColor)
        } else if state.hasInProgressTask {
            // When working, show remaining count
            if state.remainingCount > 1 {
                HStack(spacing: 4) {
                    Text("\(state.remainingCount - 1) more task\(state.remainingCount > 2 ? "s" : "") remaining")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }
        } else if let nextTask = state.nextTaskTitle {
            HStack(spacing: 6) {
                PriorityDot(priority: state.nextTaskPriority, size: 6)

                Text(nextTask)
                    .lineLimit(1)

                if state.remainingCount > 2 {
                    Text("·")
                    Text("+\(state.remainingCount - 2) more")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }
}

/// Small priority indicator dot
struct PriorityDot: View {
    let priority: Int16
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(WidgetDesign.priorityColor(for: priority))
            .frame(width: size, height: size)
    }
}

// MARK: - Dynamic Island Minimal View

/// Minimal view - Progress ring with in-progress indicator
struct DynamicIslandMinimal: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        ZStack {
            CompactProgressRing(
                progress: state.progress,
                accentColor: state.hasInProgressTask
                    ? WidgetDesign.priorityColor(for: state.inProgressPriority)
                    : WidgetDesign.accentColor
            )

            // Subtle play indicator when in progress
            if state.hasInProgressTask {
                Circle()
                    .fill(WidgetDesign.priorityColor(for: state.inProgressPriority))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Shared Components

/// Elegant progress ring used across all views
struct CompactProgressRing: View {
    let progress: Double
    var accentColor: Color = WidgetDesign.accentColor

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Checkmark when complete
            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
    }
}
