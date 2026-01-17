import SwiftUI
import UIKit

/// Task row that can expand to show subtasks with edge progress indicator
struct ExpandableTaskRowView: View {
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
    var onSubtaskToggle: ((Task) -> Void)?
    var onSubtaskTap: ((Task) -> Void)?
    var onSubtaskDelete: ((Task) -> Void)?
    var onSubtaskPromote: ((Task) -> Void)?
    var onAddSubtask: ((Task) -> Void)?

    @State private var isExpanded: Bool = true
    @State private var isPressed = false
    @State private var previousAllCompleted: Bool = false

    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 0) {
            // Task row with progress ring on checkbox
            TaskRowView(
                task: task,
                onToggle: onToggle,
                onTap: onTap,
                isDraggable: isDraggable,
                onSchedule: onSchedule,
                onPushToTomorrow: onPushToTomorrow,
                onMoveToToday: onMoveToToday,
                onPriorityChange: onPriorityChange,
                onDueDateChange: onDueDateChange,
                onDelete: onDelete,
                onStartWorking: onStartWorking,
                onStopWorking: onStopWorking,
                hideSubtaskBadge: true,
                showProgressRing: task.hasSubtasks
            )

            // Subtasks section
            if task.hasSubtasks {
                if isExpanded {
                    // Expanded: show all subtasks with staggered animation
                    VStack(spacing: 0) {
                        // Collapse header - integrated with thread
                        Button {
                            impactLight.impactOccurred()
                            withAnimation(DesignSystem.Animation.quick) {
                                isExpanded = false
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Text("\(task.completedSubtaskCount)/\(task.subtasks.count) subtasks")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundColor(Color.Lazyflow.textTertiary)

                                Spacer()

                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color.Lazyflow.textTertiary)
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .padding(.trailing, DesignSystem.Spacing.md)
                            .padding(.leading, 16 + DesignSystem.Spacing.sm + DesignSystem.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .leading) {
                            // Vertical thread line - matches SubtaskThreadConnector positioning
                            Canvas { context, size in
                                let xPos: CGFloat = 2
                                var path = Path()
                                path.move(to: CGPoint(x: xPos, y: 0))
                                path.addLine(to: CGPoint(x: xPos, y: size.height))
                                context.stroke(path, with: .color(Color.Lazyflow.textTertiary.opacity(0.4)), lineWidth: 1.5)
                            }
                            .frame(width: 16)
                            .padding(.leading, DesignSystem.Spacing.sm)
                        }

                        ForEach(Array(task.subtasks.enumerated()), id: \.element.id) { index, subtask in
                            SubtaskRowView(
                                subtask: subtask,
                                onToggle: { onSubtaskToggle?(subtask) },
                                onTap: { onSubtaskTap?(subtask) },
                                onDelete: onSubtaskDelete,
                                onPromote: onSubtaskPromote,
                                index: index,
                                isLast: index == task.subtasks.count - 1
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: -4)),
                                removal: .opacity
                            ))
                            .animation(
                                .easeOut(duration: 0.2).delay(Double(index) * 0.03),
                                value: isExpanded
                            )
                        }

                        // Add subtask button with fade-in
                        if !task.isCompleted {
                            AddSubtaskInlineButton {
                                onAddSubtask?(task)
                            }
                            .transition(.opacity)
                            .animation(
                                .easeOut(duration: 0.2).delay(Double(task.subtasks.count) * 0.03),
                                value: isExpanded
                            )
                        }
                    }
                    .padding(.leading, DesignSystem.Spacing.sm)
                } else {
                    // Collapsed: show peek preview
                    SubtaskPeekPreview(
                        task: task,
                        isExpanded: isExpanded,
                        onToggle: {
                            impactLight.impactOccurred()
                            withAnimation(DesignSystem.Animation.quick) {
                                isExpanded = true
                            }
                        }
                    )
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            }
        }
        .id("\(task.id)-\(isExpanded)-\(task.subtasks.count)")
        .onChange(of: task.allSubtasksCompleted) { _, allCompleted in
            // Auto-collapse when all subtasks become completed
            if allCompleted && !previousAllCompleted && isExpanded {
                withAnimation(DesignSystem.Animation.standard) {
                    isExpanded = false
                }
            }
            previousAllCompleted = allCompleted
        }
        .onAppear {
            previousAllCompleted = task.allSubtasksCompleted
            // Start collapsed if all subtasks are already completed
            if task.allSubtasksCompleted {
                isExpanded = false
            }
        }
    }
}

/// Inline button to add a subtask
struct AddSubtaskInlineButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color.Lazyflow.accent)

                Text("Add subtask")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.accent)

                Spacer()
            }
            .padding(.leading, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.trailing, DesignSystem.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add subtask")
    }
}

// MARK: - Preview

#Preview("Expandable Task Row") {
    VStack(spacing: 8) {
        // Task with subtasks (some completed)
        ExpandableTaskRowView(
            task: Task(
                title: "Plan project architecture",
                dueDate: Date(),
                priority: .high,
                subtasks: [
                    Task(title: "Research existing patterns", isCompleted: true),
                    Task(title: "Create data model diagram", isCompleted: true),
                    Task(title: "Write technical spec")
                ]
            ),
            onToggle: {},
            onTap: {}
        )
        .padding(.horizontal)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)

        // Task with all subtasks completed
        ExpandableTaskRowView(
            task: Task(
                title: "Review code changes",
                priority: .medium,
                subtasks: [
                    Task(title: "Check unit tests", isCompleted: true),
                    Task(title: "Review PR comments", isCompleted: true)
                ]
            ),
            onToggle: {},
            onTap: {}
        )
        .padding(.horizontal)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)

        // Task without subtasks
        ExpandableTaskRowView(
            task: Task(title: "Send weekly report", priority: .low),
            onToggle: {},
            onTap: {}
        )
        .padding(.horizontal)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)

        // Completed task
        ExpandableTaskRowView(
            task: Task(title: "Update dependencies", isCompleted: true),
            onToggle: {},
            onTap: {}
        )
        .padding(.horizontal)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }
    .padding()
    .background(Color.adaptiveBackground)
}
