import SwiftUI

/// Reusable task row component
struct TaskRowView: View {
    let task: Task
    let onToggle: () -> Void
    let onTap: () -> Void
    var isDraggable: Bool = true
    var onSchedule: ((Task) -> Void)?
    var onPushToTomorrow: ((Task) -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Checkbox
                TaskCheckbox(
                    isCompleted: task.isCompleted,
                    priority: task.priority,
                    action: onToggle
                )

                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Title
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(
                            task.isCompleted
                                ? Color.Taskweave.textTertiary
                                : Color.Taskweave.textPrimary
                        )
                        .strikethrough(task.isCompleted, color: Color.Taskweave.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Metadata row
                    if hasMetadata {
                        metadataRow
                    }
                }

                Spacer()

                // Recurring indicator
                if task.isRecurring {
                    Image(systemName: "repeat")
                        .font(.system(size: 12))
                        .foregroundColor(Color.Taskweave.textTertiary)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .contextMenu {
            contextMenuContent
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                // Delete will be handled by parent
            } label: {
                Label("Delete", systemImage: "trash")
            }

            if !task.isCompleted {
                Button {
                    onPushToTomorrow?(task)
                } label: {
                    Label("Tomorrow", systemImage: "arrow.right.to.line")
                }
                .tint(.orange)
                .accessibilityIdentifier("PushToTomorrowSwipe")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label(
                    task.isCompleted ? "Uncomplete" : "Complete",
                    systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(Color.Taskweave.success)
        }
        .if(isDraggable) { view in
            view.draggable(task) {
                // Drag preview
                TaskDragPreview(task: task)
            }
        }
    }

    // MARK: - Metadata

    private var hasMetadata: Bool {
        task.dueDate != nil || task.priority != .none || task.category != .uncategorized || task.notes != nil || task.estimatedDuration != nil
    }

    private var metadataRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Category
            if task.category != .uncategorized && !task.isCompleted {
                CategoryBadge(category: task.category)
            }

            // Due date
            if let dueDate = task.dueDate {
                DueDateBadge(date: dueDate, isOverdue: task.isOverdue)
            }

            // Priority
            if task.priority != .none && !task.isCompleted {
                PriorityBadge(priority: task.priority)
            }

            // Duration
            if let duration = task.formattedDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(duration)
                        .font(DesignSystem.Typography.caption2)
                }
                .foregroundColor(Color.Taskweave.textTertiary)
            }

            // Notes indicator
            if task.notes != nil {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundColor(Color.Taskweave.textTertiary)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onToggle()
        } label: {
            Label(
                task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                systemImage: task.isCompleted ? "circle" : "checkmark.circle"
            )
        }

        Divider()

        Menu {
            ForEach(Priority.allCases) { priority in
                Button {
                    // Priority change handled by parent
                } label: {
                    Label(priority.displayName, systemImage: priority.iconName)
                }
            }
        } label: {
            Label("Priority", systemImage: "flag")
        }

        Menu {
            Button {
                // Set due today
            } label: {
                Label("Today", systemImage: "star")
            }

            Button {
                // Set due tomorrow
            } label: {
                Label("Tomorrow", systemImage: "sunrise")
            }

            Button {
                // Set due next week
            } label: {
                Label("Next Week", systemImage: "calendar")
            }

            if task.dueDate != nil {
                Divider()
                Button(role: .destructive) {
                    // Remove due date
                } label: {
                    Label("Remove Date", systemImage: "xmark")
                }
            }
        } label: {
            Label("Due Date", systemImage: "calendar")
        }

        // Schedule to Calendar
        if !task.isCompleted {
            Button {
                onSchedule?(task)
            } label: {
                Label("Schedule to Calendar", systemImage: "calendar.badge.plus")
            }

            Button {
                onPushToTomorrow?(task)
            } label: {
                Label("Push to Tomorrow", systemImage: "arrow.right.to.line")
            }
        }

        Divider()

        Button(role: .destructive) {
            // Delete handled by parent
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Compact Task Row

struct CompactTaskRowView: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            TaskCheckbox(
                isCompleted: task.isCompleted,
                priority: task.priority,
                action: onToggle
            )

            Text(task.title)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(
                    task.isCompleted
                        ? Color.Taskweave.textTertiary
                        : Color.Taskweave.textPrimary
                )
                .strikethrough(task.isCompleted)
                .lineLimit(1)

            Spacer()

            if let date = task.dueDate {
                Text(date.shortFormatted)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(
                        task.isOverdue
                            ? Color.Taskweave.error
                            : Color.Taskweave.textTertiary
                    )
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Drag Preview

struct TaskDragPreview: View {
    let task: Task

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .foregroundColor(Color.Taskweave.accent)

            Text(task.title)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            if let duration = task.formattedDuration {
                Text("• \(duration)")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.Taskweave.accent.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(Color.Taskweave.accent, lineWidth: 2)
        )
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview("Task Row") {
    VStack(spacing: 8) {
        TaskRowView(
            task: Task.sample,
            onToggle: {},
            onTap: {}
        )

        TaskRowView(
            task: Task(title: "Completed task", isCompleted: true),
            onToggle: {},
            onTap: {}
        )

        TaskRowView(
            task: Task(
                title: "Overdue task with notes",
                notes: "Some notes here",
                dueDate: Date().addingDays(-1),
                priority: .urgent
            ),
            onToggle: {},
            onTap: {}
        )
    }
    .padding()
    .background(Color.adaptiveBackground)
}

#Preview("Drag Preview") {
    TaskDragPreview(task: Task.sample)
        .padding()
}
