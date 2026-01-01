import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen presentation for Task Live Activity - Elegant centered design
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TaskActivityAttributes>

    private var state: TaskActivityAttributes.ContentState {
        context.state
    }

    var body: some View {
        VStack(spacing: 0) {
            // Centered progress section
            VStack(spacing: 6) {
                LiveActivityProgressRing(progress: state.progress)
                    .frame(width: 36, height: 36)

                Text("\(state.completedCount) of \(state.totalCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
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
    private var taskHierarchy: some View {
        if state.remainingCount == 0 {
            // Celebration state
            VStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(WidgetDesign.accentColor)
                Text("All complete!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetDesign.accentColor)
            }
        } else {
            VStack(alignment: .center, spacing: 6) {
                // Current task - Hero prominence
                if let currentTask = state.currentTaskTitle {
                    Text(currentTask)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                // Next task - Secondary
                if let nextTask = state.nextTaskTitle {
                    Text(nextTask)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Remaining count - Tertiary fade
                if state.remainingCount > 2 {
                    Text("+\(state.remainingCount - 1) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

/// Compact progress ring for Live Activity header
struct LiveActivityProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    WidgetDesign.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(WidgetDesign.accentColor)
            }
        }
    }
}
