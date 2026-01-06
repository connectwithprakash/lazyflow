import SwiftUI

/// Compact task row for Watch display
struct WatchTaskRowView: View {
    let task: WatchTask
    let onComplete: () -> Void

    private let accentColor = Color(red: 33/255, green: 138/255, blue: 141/255)

    var body: some View {
        Button(action: onComplete) {
            HStack(spacing: 10) {
                // Checkbox
                checkboxView

                // Task content
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)

                    // Due time if available
                    if let dueTime = task.dueTime {
                        Text(dueTime, style: .time)
                            .font(.system(size: 11))
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }

                Spacer()

                // Priority indicator
                if task.priority > 1 {
                    priorityIndicator
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to mark as \(task.isCompleted ? "incomplete" : "complete")")
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
        if task.priority > 1 {
            components.append("\(priorityName) priority")
        }

        // Due time
        if task.isOverdue {
            components.append("Overdue")
        } else if task.dueTime != nil {
            components.append("Due today")
        }

        return components.joined(separator: ", ")
    }

    private var priorityName: String {
        switch task.priority {
        case 4: return "Urgent"
        case 3: return "High"
        case 2: return "Medium"
        case 1: return "Low"
        default: return ""
        }
    }

    private var checkboxView: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    task.isCompleted ? accentColor : priorityColor.opacity(0.6),
                    lineWidth: 2
                )
                .frame(width: 22, height: 22)

            if task.isCompleted {
                Circle()
                    .fill(accentColor)
                    .frame(width: 18, height: 18)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
    }

    private var priorityColor: Color {
        switch task.priority {
        case 4: return .red        // Urgent
        case 3: return .orange     // High
        case 2: return .yellow     // Medium
        case 1: return .blue       // Low
        default: return .gray      // None
        }
    }
}

#Preview {
    VStack {
        WatchTaskRowView(
            task: WatchTask(
                id: UUID(),
                title: "Review pull request",
                isCompleted: false,
                priority: 3,
                isOverdue: false,
                dueTime: Date()
            )
        ) {}

        WatchTaskRowView(
            task: WatchTask(
                id: UUID(),
                title: "Call dentist",
                isCompleted: true,
                priority: 2,
                isOverdue: false,
                dueTime: nil
            )
        ) {}

        WatchTaskRowView(
            task: WatchTask(
                id: UUID(),
                title: "Overdue task example",
                isCompleted: false,
                priority: 4,
                isOverdue: true,
                dueTime: Date().addingTimeInterval(-3600)
            )
        ) {}
    }
}
