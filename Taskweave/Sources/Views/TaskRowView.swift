import SwiftUI
import UIKit

/// Reusable task row component
struct TaskRowView: View {
    let task: Task
    let onToggle: () -> Void
    let onTap: () -> Void
    var isDraggable: Bool = true
    var onSchedule: ((Task) -> Void)?
    var onPushToTomorrow: ((Task) -> Void)?
    var onMoveToToday: ((Task) -> Void)?
    var onPriorityChange: ((Task, Priority) -> Void)?
    var onDueDateChange: ((Task, Date?) -> Void)?
    var onDelete: ((Task) -> Void)?
    var onStartWorking: ((Task) -> Void)?
    var onStopWorking: ((Task) -> Void)?

    @State private var isPressed = false
    @State private var isPulsing = false

    // MARK: - Haptic Feedback
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        HStack(spacing: 0) {
            // Priority edge strip
            if task.priority != .none && !task.isCompleted {
                Rectangle()
                    .fill(task.priority.color)
                    .frame(width: 4)
                    .accessibilityHidden(true) // Color info is conveyed via label
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                // Checkbox - independently tappable
                Button {
                    notificationFeedback.notificationOccurred(.success)
                    onToggle()
                } label: {
                    checkboxView
                }
                .buttonStyle(.plain)

                // Content - tappable area for edit
                Button {
                    onTap()
                } label: {
                    HStack(spacing: 0) {
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

                        // Recurring indicator with frequency
                        if task.isRecurring {
                            HStack(spacing: 2) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 12))
                                if let rule = task.recurringRule {
                                    Text(rule.compactDisplayFormat)
                                        .font(.system(size: 11))
                                }
                            }
                            .foregroundColor(Color.Taskweave.textTertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.quick, value: isPressed)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view details")
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .contextMenu {
            contextMenuContent
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                notificationFeedback.notificationOccurred(.warning)
                onDelete?(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            if !task.isCompleted {
                if task.isOverdue || (!task.isDueToday && task.dueDate != nil) {
                    Button {
                        impactMedium.impactOccurred()
                        onMoveToToday?(task)
                    } label: {
                        Label("Today", systemImage: "star.fill")
                    }
                    .tint(.blue)
                }

                if task.isDueToday || task.isOverdue {
                    Button {
                        impactMedium.impactOccurred()
                        onPushToTomorrow?(task)
                    } label: {
                        Label("Tomorrow", systemImage: "arrow.right.to.line")
                    }
                    .tint(.orange)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                notificationFeedback.notificationOccurred(.success)
                onToggle()
            } label: {
                Label(task.isCompleted ? "Undo" : "Done", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(Color.Taskweave.success)

            if !task.isCompleted {
                // Start/Stop Working action
                if task.isInProgress {
                    Button {
                        impactMedium.impactOccurred()
                        onStopWorking?(task)
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .tint(.orange)
                } else {
                    Button {
                        impactMedium.impactOccurred()
                        onStartWorking?(task)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(Color.Taskweave.accent)
                }

                Button {
                    impactLight.impactOccurred()
                    onSchedule?(task)
                } label: {
                    Label("Schedule", systemImage: "calendar.badge.plus")
                }
                .tint(.purple)
            }
        }
        .if(isDraggable) { view in
            view.draggable(task) {
                // Drag preview
                TaskDragPreview(task: task)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var components: [String] = []

        // Status
        if task.isCompleted {
            components.append("Completed")
        }

        // Title
        components.append(task.title)

        // Priority
        if task.priority != .none && !task.isCompleted {
            components.append("\(task.priority.displayName) priority")
        }

        // Due date
        if let dueDate = task.dueDate {
            if task.isOverdue {
                components.append("Overdue, was due \(dueDate.relativeFormatted)")
            } else {
                components.append("Due \(dueDate.relativeFormatted)")
            }
        }

        // Category
        if task.category != .uncategorized {
            components.append(task.category.displayName)
        }

        return components.joined(separator: ", ")
    }

    // MARK: - Checkbox View

    private var checkboxView: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    task.isCompleted ? Color.Taskweave.success :
                    task.isInProgress ? Color.Taskweave.accent :
                    task.priority.color,
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)

            if task.isCompleted {
                Circle()
                    .fill(Color.Taskweave.success)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            } else if task.isInProgress {
                // Filled dot indicator - universal "active/current" state
                Circle()
                    .fill(Color.Taskweave.accent)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isPulsing ? 1.0 : 0.85)
                    .opacity(isPulsing ? 1.0 : 0.7)
            }
        }
        .frame(minWidth: DesignSystem.TouchTarget.minimum, minHeight: DesignSystem.TouchTarget.minimum)
        .contentShape(Rectangle())
        .accessibilityLabel(
            task.isCompleted ? "Mark incomplete" :
            task.isInProgress ? "Stop working" :
            "Mark complete"
        )
        .onAppear {
            if task.isInProgress {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: task.isInProgress) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }

    // MARK: - Metadata

    private var hasMetadata: Bool {
        task.dueDate != nil || task.category != .uncategorized || task.notes != nil || task.estimatedDuration != nil
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

        // Start/Stop Working
        if !task.isCompleted {
            if task.isInProgress {
                Button {
                    onStopWorking?(task)
                } label: {
                    Label("Pause Working", systemImage: "pause.fill")
                }
            } else {
                Button {
                    onStartWorking?(task)
                } label: {
                    Label("Start Working", systemImage: "play.fill")
                }
            }
        }

        Divider()

        Menu {
            ForEach(Priority.allCases) { priority in
                Button {
                    onPriorityChange?(task, priority)
                } label: {
                    Label(priority.displayName, systemImage: priority.iconName)
                }
            }
        } label: {
            Label("Priority", systemImage: "flag")
        }

        Menu {
            Button {
                onDueDateChange?(task, Date())
            } label: {
                Label("Today", systemImage: "star")
            }

            Button {
                onDueDateChange?(task, Date().addingDays(1))
            } label: {
                Label("Tomorrow", systemImage: "sunrise")
            }

            Button {
                onDueDateChange?(task, Date().addingDays(7))
            } label: {
                Label("Next Week", systemImage: "calendar")
            }

            if task.dueDate != nil {
                Divider()
                Button(role: .destructive) {
                    onDueDateChange?(task, nil)
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

            // Move to Today (for overdue or upcoming tasks)
            if task.isOverdue || (!task.isDueToday && task.dueDate != nil) {
                Button {
                    onMoveToToday?(task)
                } label: {
                    Label("Move to Today", systemImage: "star.fill")
                }
            }

            Button {
                onPushToTomorrow?(task)
            } label: {
                Label("Push to Tomorrow", systemImage: "arrow.right.to.line")
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete?(task)
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
        HStack(spacing: 0) {
            // Priority edge strip
            if task.priority != .none && !task.isCompleted {
                Rectangle()
                    .fill(task.priority.color)
                    .frame(width: 3)
            }

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
            .padding(.leading, task.priority != .none && !task.isCompleted ? DesignSystem.Spacing.sm : 0)
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
