import SwiftUI
import WidgetKit

/// Large widget (4x4) showing overdue, today, and upcoming sections
struct LargeWidgetView: View {
    let entry: TaskEntry

    private var totalPendingCount: Int {
        entry.overdueTasks.count + entry.todayTasks.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            LargeWidgetHeader(entry: entry)
                .padding(.bottom, 12)

            if totalPendingCount == 0 {
                Spacer()
                EmptyStateView(compact: false)
                Spacer()
            } else {
                // Sections (no ScrollView - widgets don't support scrolling)
                VStack(alignment: .leading, spacing: 10) {
                    // Overdue section
                    if !entry.overdueTasks.isEmpty {
                        TaskSectionView(
                            title: "Overdue",
                            icon: "exclamationmark.circle.fill",
                            iconColor: WidgetDesign.urgentColor,
                            tasks: Array(entry.overdueTasks.prefix(2)),
                            remainingCount: max(0, entry.overdueTasks.count - 2),
                            isOverdue: true
                        )
                    }

                    // Today section
                    if !entry.todayTasks.isEmpty {
                        let maxTodayTasks = entry.overdueTasks.isEmpty ? 4 : 2
                        TaskSectionView(
                            title: "Today",
                            icon: "calendar",
                            iconColor: WidgetDesign.accentColor,
                            tasks: Array(entry.todayTasks.prefix(maxTodayTasks)),
                            remainingCount: max(0, entry.todayTasks.count - maxTodayTasks),
                            isOverdue: false
                        )
                    }

                    // Upcoming section (only if space available)
                    if !entry.upcomingTasks.isEmpty && entry.overdueTasks.isEmpty && entry.todayTasks.count <= 2 {
                        TaskSectionView(
                            title: "Upcoming",
                            icon: "clock",
                            iconColor: .secondary,
                            tasks: Array(entry.upcomingTasks.prefix(2)),
                            remainingCount: max(0, entry.upcomingTasks.count - 2),
                            isOverdue: false
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "taskweave://view/today"))
    }
}

/// Header for large widget
struct LargeWidgetHeader: View {
    let entry: TaskEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.completedCount) / Double(entry.totalCount)
    }

    var body: some View {
        HStack(alignment: .center) {
            // App branding
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(WidgetDesign.accentColor)
                Text("Taskweave")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Progress indicator
            HStack(spacing: 8) {
                Text("\(entry.completedCount)/\(entry.totalCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                ProgressRing(progress: progress)
                    .frame(width: 28, height: 28)
            }
        }
    }
}

/// Section view for large widget
struct TaskSectionView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let tasks: [WidgetTask]
    let remainingCount: Int
    let isOverdue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(iconColor)
                Text("(\(tasks.count + remainingCount))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            // Task list in card
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    LargeTaskRowView(task: task, isOverdue: isOverdue)

                    if index < tasks.count - 1 {
                        Divider()
                            .padding(.leading, 28)
                    }
                }

                if remainingCount > 0 {
                    Divider()
                        .padding(.leading, 28)
                    HStack {
                        Text("+\(remainingCount) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 28)
                            .padding(.vertical, 6)
                        Spacer()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

/// Task row for large widget
struct LargeTaskRowView: View {
    let task: WidgetTask
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Priority indicator
            Circle()
                .fill(task.priorityColor)
                .frame(width: 8, height: 8)

            // Checkbox
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1.5)
                .frame(width: 18, height: 18)

            // Task title
            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(isOverdue ? WidgetDesign.urgentColor : .primary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

#Preview(as: .systemLarge) {
    TaskweaveWidget()
} timeline: {
    TaskEntry.placeholder
}
