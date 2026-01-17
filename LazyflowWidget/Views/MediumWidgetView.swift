import SwiftUI
import WidgetKit

/// Medium widget (4x2) showing today's task list with priority indicators
struct MediumWidgetView: View {
    let entry: TaskEntry

    private var displayTasks: [WidgetTask] {
        let combined = entry.overdueTasks + entry.todayTasks
        return Array(combined.prefix(4))
    }

    private var remainingCount: Int {
        let total = entry.overdueTasks.count + entry.todayTasks.count
        return max(0, total - 4)
    }

    private var hasOverdue: Bool {
        !entry.overdueTasks.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    if hasOverdue {
                        Text("\(entry.overdueTasks.count) overdue")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetDesign.urgentColor)
                    }
                }
                Spacer()
                ProgressRing(progress: entry.totalCount > 0 ? Double(entry.completedCount) / Double(entry.totalCount) : 0)
                    .frame(width: 32, height: 32)
            }
            .padding(.bottom, 10)

            if displayTasks.isEmpty {
                Spacer()
                EmptyStateView(compact: true)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(displayTasks) { task in
                        TaskRowView(
                            task: task,
                            isOverdue: entry.overdueTasks.contains { $0.id == task.id }
                        )
                    }

                    if remainingCount > 0 {
                        Text("+\(remainingCount) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 10)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "lazyflow://view/today"))
    }
}

/// Single task row with priority color bar
struct TaskRowView: View {
    let task: WidgetTask
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Priority color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(task.priorityColor)
                .frame(width: 3, height: 20)

            // Checkbox circle
            Circle()
                .strokeBorder(task.priorityColor.opacity(0.6), lineWidth: 1.5)
                .frame(width: 16, height: 16)

            // Task title
            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(isOverdue ? WidgetDesign.urgentColor : .primary)

            Spacer()

            // Subtask progress badge
            if task.hasSubtasks {
                HStack(spacing: 2) {
                    WidgetSubtaskProgressRing(progress: task.subtaskProgress)
                        .frame(width: 12, height: 12)
                    Text(task.subtaskProgressString ?? "")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Mini progress ring for subtask progress in widget
struct WidgetSubtaskProgressRing: View {
    let progress: Double

    private var isComplete: Bool {
        progress >= 1.0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isComplete ? Color.green : WidgetDesign.accentColor,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(Color.green)
            }
        }
    }
}

/// Compact progress ring for header
struct ProgressRing: View {
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidgetDesign.accentColor)
            }
        }
    }
}

/// Empty state view
struct EmptyStateView: View {
    var compact: Bool = false

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: compact ? 4 : 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: compact ? 20 : 28))
                    .foregroundStyle(WidgetDesign.accentColor)
                Text("All clear!")
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(.primary)
                if !compact {
                    Text("No tasks due today")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

#Preview(as: .systemMedium) {
    LazyflowWidget()
} timeline: {
    TaskEntry.placeholder
}
