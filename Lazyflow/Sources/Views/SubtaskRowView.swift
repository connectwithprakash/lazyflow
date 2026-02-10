import SwiftUI
import UIKit

/// Compact row view for displaying subtasks with indentation and thread connection
struct SubtaskRowView: View {
    let subtask: Task
    let onToggle: () -> Void
    let onTap: () -> Void
    var onDelete: ((Task) -> Void)?
    var onPromote: ((Task) -> Void)?
    var index: Int = 0
    var isLast: Bool = false

    @State private var isPressed = false

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private var threadColor: Color {
        subtask.isCompleted ? Color.Lazyflow.success.opacity(0.5) : Color.Lazyflow.textTertiary.opacity(0.4)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Left spacing for thread connector (connector is added as overlay below)
            Spacer()
                .frame(width: 16 + DesignSystem.Spacing.sm)

            // Checkbox
            Button {
                notificationFeedback.notificationOccurred(.success)
                onToggle()
            } label: {
                subtaskCheckbox
            }
            .buttonStyle(.plain)

            // Content - tappable area for editing
            Button {
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    // Title
                    Text(subtask.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(
                            subtask.isCompleted
                                ? Color.Lazyflow.textTertiary
                                : Color.Lazyflow.textPrimary
                        )
                        .strikethrough(subtask.isCompleted, color: Color.Lazyflow.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Metadata row (if any metadata exists)
                    if hasMetadata {
                        subtaskMetadataRow
                    }
                }
                .frame(maxWidth: .infinity, minHeight: DesignSystem.TouchTarget.minimum - 8, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.trailing, DesignSystem.Spacing.md)
        .background(Color.adaptiveSurface.opacity(0.5))
        .overlay(alignment: .leading) {
            SubtaskThreadConnector(
                isLast: isLast,
                isCompleted: subtask.isCompleted
            )
            .frame(width: 16)
            .padding(.leading, DesignSystem.Spacing.sm)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.quick, value: isPressed)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to edit subtask")
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .contextMenu {
            contextMenuContent
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                notificationFeedback.notificationOccurred(.warning)
                onDelete?(subtask)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                impactLight.impactOccurred()
                onPromote?(subtask)
            } label: {
                Label("Promote", systemImage: "arrow.up.right")
            }
            .tint(.purple)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                notificationFeedback.notificationOccurred(.success)
                onToggle()
            } label: {
                Label(subtask.isCompleted ? "Undo" : "Done", systemImage: subtask.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(Color.Lazyflow.success)
        }
    }

    // MARK: - Metadata

    private var hasMetadata: Bool {
        subtask.dueDate != nil || subtask.priority != .none || subtask.notes != nil || subtask.estimatedDuration != nil
    }

    private var subtaskMetadataRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Priority indicator (small dot)
            if subtask.priority != .none && !subtask.isCompleted {
                Circle()
                    .fill(subtask.priority.color)
                    .frame(width: 6, height: 6)
            }

            // Due date
            if let dueDate = subtask.dueDate {
                HStack(spacing: 2) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                    Text(dueDate.shortFormatted)
                        .font(DesignSystem.Typography.caption2)
                }
                .foregroundColor(dueDateColor(dueDate))
            }

            // Notes indicator
            if subtask.notes != nil && !(subtask.notes?.isEmpty ?? true) {
                Image(systemName: "note.text")
                    .font(.system(size: 9))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }

            // Duration
            if let duration = subtask.estimatedDuration, duration > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(formatDuration(duration))
                        .font(DesignSystem.Typography.caption2)
                }
                .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        if subtask.isCompleted {
            return Color.Lazyflow.textTertiary
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return Color.Lazyflow.accent
        } else if date < Date() {
            return Color.Lazyflow.error
        }
        return Color.Lazyflow.textTertiary
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainingMinutes)m"
    }

    // MARK: - Checkbox

    private var subtaskCheckbox: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    subtask.isCompleted ? Color.Lazyflow.success : Color.Lazyflow.textTertiary,
                    lineWidth: 1.5
                )
                .frame(width: 20, height: 20)

            if subtask.isCompleted {
                Circle()
                    .fill(Color.Lazyflow.success)
                    .frame(width: 20, height: 20)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(minWidth: DesignSystem.TouchTarget.minimum, minHeight: DesignSystem.TouchTarget.minimum)
        .contentShape(Rectangle())
        .accessibilityLabel(subtask.isCompleted ? "Mark subtask incomplete" : "Mark subtask complete")
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var components: [String] = ["Subtask"]

        if subtask.isCompleted {
            components.append("Completed")
        }

        components.append(subtask.title)

        return components.joined(separator: ", ")
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onToggle()
        } label: {
            Label(
                subtask.isCompleted ? "Mark Incomplete" : "Mark Complete",
                systemImage: subtask.isCompleted ? "circle" : "checkmark.circle"
            )
        }

        Divider()

        Button {
            onPromote?(subtask)
        } label: {
            Label("Promote to Task", systemImage: "arrow.up.right")
        }

        Divider()

        Button(role: .destructive) {
            onDelete?(subtask)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Thread Connector

/// Visual thread connector showing hierarchy between subtasks
struct SubtaskThreadConnector: View {
    let isLast: Bool
    let isCompleted: Bool

    private var lineColor: Color {
        isCompleted ? Color.Lazyflow.success.opacity(0.6) : Color.Lazyflow.textTertiary.opacity(0.5)
    }

    var body: some View {
        // Use Canvas for precise drawing
        Canvas { context, size in
            let midY = size.height / 2
            let lineWidth: CGFloat = 1.5
            let xPos: CGFloat = 2  // Offset from left edge
            let nodeRadius: CGFloat = 2.5  // Junction node size

            // Vertical line from top to middle (or full height if not last)
            let verticalEnd = isLast ? midY : size.height
            var verticalPath = Path()
            verticalPath.move(to: CGPoint(x: xPos, y: 0))
            verticalPath.addLine(to: CGPoint(x: xPos, y: verticalEnd))
            context.stroke(verticalPath, with: .color(lineColor), lineWidth: lineWidth)

            // Horizontal line - shorter, just to the node
            let horizontalEnd = size.width - 2
            var horizontalPath = Path()
            horizontalPath.move(to: CGPoint(x: xPos, y: midY))
            horizontalPath.addLine(to: CGPoint(x: horizontalEnd, y: midY))
            context.stroke(horizontalPath, with: .color(lineColor), lineWidth: lineWidth)

            // Junction node at the end of horizontal line
            let nodeCenter = CGPoint(x: horizontalEnd, y: midY)
            let nodeRect = CGRect(
                x: nodeCenter.x - nodeRadius,
                y: nodeCenter.y - nodeRadius,
                width: nodeRadius * 2,
                height: nodeRadius * 2
            )
            context.fill(Path(ellipseIn: nodeRect), with: .color(lineColor))
        }
    }
}

// MARK: - Preview

#Preview("Subtask Row") {
    VStack(spacing: 0) {
        SubtaskRowView(
            subtask: Task(title: "Research existing patterns"),
            onToggle: {},
            onTap: {},
            index: 0,
            isLast: false
        )

        SubtaskRowView(
            subtask: Task(title: "Create data model diagram", isCompleted: true),
            onToggle: {},
            onTap: {},
            index: 1,
            isLast: false
        )

        SubtaskRowView(
            subtask: Task(
                title: "Write technical specification document",
                notes: "Include API design",
                dueDate: Date(),
                priority: .high,
                estimatedDuration: 3600
            ),
            onToggle: {},
            onTap: {},
            index: 2,
            isLast: false
        )

        SubtaskRowView(
            subtask: Task(
                title: "Review with team",
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                priority: .medium
            ),
            onToggle: {},
            onTap: {},
            index: 3,
            isLast: true
        )
    }
    .padding()
    .background(Color.adaptiveBackground)
}
