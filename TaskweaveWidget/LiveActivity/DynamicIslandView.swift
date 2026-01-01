import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Dynamic Island Compact Views

/// Compact leading view - Progress ring only
struct DynamicIslandCompactLeading: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        CompactProgressRing(progress: state.progress)
            .frame(width: 24, height: 24)
    }
}

/// Compact trailing view - Subtle progress bar
struct DynamicIslandCompactTrailing: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(WidgetDesign.accentColor)
                    .frame(width: geometry.size.width * state.progress)
            }
        }
        .frame(width: 44, height: 4)
    }
}

// MARK: - Dynamic Island Expanded Views

/// Expanded leading region - Progress ring
struct DynamicIslandExpandedLeading: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        CompactProgressRing(progress: state.progress)
            .frame(width: 28, height: 28)
    }
}

/// Expanded trailing region - Count
struct DynamicIslandExpandedTrailing: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        Text("\(state.completedCount) of \(state.totalCount)")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

/// Expanded bottom region - Task details
struct DynamicIslandExpandedView: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current task (hero)
            if let currentTask = state.currentTaskTitle {
                Text(currentTask)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
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
        if let nextTask = state.nextTaskTitle {
            HStack(spacing: 4) {
                Text(nextTask)
                    .lineLimit(1)

                if state.remainingCount > 2 {
                    Text("·")
                    Text("+\(state.remainingCount - 1) more")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        } else if state.remainingCount == 0 {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Text("All complete!")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(WidgetDesign.accentColor)
        }
    }
}

// MARK: - Dynamic Island Minimal View

/// Minimal view - Just progress ring
struct DynamicIslandMinimal: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        CompactProgressRing(progress: state.progress)
    }
}

// MARK: - Shared Components

/// Elegant progress ring used across all views
struct CompactProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    WidgetDesign.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Checkmark when complete
            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidgetDesign.accentColor)
            }
        }
    }
}
