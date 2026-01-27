import SwiftUI

/// Badge showing subtask progress (e.g., "2/3")
struct SubtaskProgressBadge: View {
    let completedCount: Int
    let totalCount: Int

    /// Initialize from a task with subtasks
    init(task: Task) {
        self.completedCount = task.completedSubtaskCount
        self.totalCount = task.subtasks.count
    }

    /// Initialize with explicit counts
    init(completedCount: Int, totalCount: Int) {
        self.completedCount = completedCount
        self.totalCount = totalCount
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var isComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    var body: some View {
        HStack(spacing: 4) {
            // Progress circle or checkmark
            ZStack {
                Circle()
                    .stroke(Color.Lazyflow.textTertiary.opacity(0.3), lineWidth: 2)
                    .frame(width: 14, height: 14)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isComplete ? Color.Lazyflow.success : Color.Lazyflow.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color.Lazyflow.success)
                }
            }

            // Count text
            Text("\(completedCount)/\(totalCount)")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(
                    isComplete
                        ? Color.Lazyflow.success
                        : Color.Lazyflow.textTertiary
                )
        }
        .accessibilityLabel("\(completedCount) of \(totalCount) subtasks completed")
    }
}

/// Compact version without the progress ring
struct SubtaskCountBadge: View {
    let completedCount: Int
    let totalCount: Int

    init(task: Task) {
        self.completedCount = task.completedSubtaskCount
        self.totalCount = task.subtasks.count
    }

    init(completedCount: Int, totalCount: Int) {
        self.completedCount = completedCount
        self.totalCount = totalCount
    }

    private var isComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "checklist")
                .font(.system(size: 10))
            Text("\(completedCount)/\(totalCount)")
                .font(DesignSystem.Typography.caption2)
        }
        .foregroundColor(
            isComplete
                ? Color.Lazyflow.success
                : Color.Lazyflow.textTertiary
        )
        .accessibilityLabel("\(completedCount) of \(totalCount) subtasks completed")
    }
}

/// Expandable progress badge with chevron for expand/collapse
struct ExpandableSubtaskProgressBadge: View {
    let completedCount: Int
    let totalCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    init(task: Task, isExpanded: Bool, onToggle: @escaping () -> Void) {
        self.completedCount = task.completedSubtaskCount
        self.totalCount = task.subtasks.count
        self.isExpanded = isExpanded
        self.onToggle = onToggle
    }

    init(completedCount: Int, totalCount: Int, isExpanded: Bool, onToggle: @escaping () -> Void) {
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.isExpanded = isExpanded
        self.onToggle = onToggle
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var isComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                // Chevron that rotates
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(DesignSystem.Animation.quick, value: isExpanded)

                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.Lazyflow.textTertiary.opacity(0.3), lineWidth: 2)
                        .frame(width: 14, height: 14)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isComplete ? Color.Lazyflow.success : Color.Lazyflow.accent,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(-90))
                        .animation(DesignSystem.Animation.standard, value: progress)

                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color.Lazyflow.success)
                    }
                }

                // Count text
                Text("\(completedCount)/\(totalCount)")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(
                        isComplete
                            ? Color.Lazyflow.success
                            : Color.Lazyflow.textTertiary
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.Lazyflow.textTertiary.opacity(0.08))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(completedCount) of \(totalCount) subtasks completed. \(isExpanded ? "Collapse" : "Expand") subtasks")
    }
}

/// Peek preview showing next subtask with expand/collapse
struct SubtaskPeekPreview: View {
    let task: Task
    let isExpanded: Bool
    let onToggle: () -> Void

    private var nextSubtask: Task? {
        // Find first incomplete subtask, or first subtask if all complete
        task.subtasks.first { !$0.isCompleted } ?? task.subtasks.first
    }

    private var remainingCount: Int {
        max(0, task.subtasks.count - 1)
    }

    private var completedCount: Int {
        task.completedSubtaskCount
    }

    private var totalCount: Int {
        task.subtasks.count
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Thread line hint
                Rectangle()
                    .fill(Color.Lazyflow.textTertiary.opacity(0.3))
                    .frame(width: 1, height: 16)
                    .padding(.leading, 2)

                // Next subtask preview
                if let subtask = nextSubtask {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        // Mini checkbox indicator
                        Circle()
                            .strokeBorder(
                                subtask.isCompleted ? Color.Lazyflow.success : Color.Lazyflow.textTertiary,
                                lineWidth: 1.5
                            )
                            .frame(width: 12, height: 12)
                            .overlay(
                                subtask.isCompleted ?
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(Color.Lazyflow.success)
                                : nil
                            )

                        // Subtask title (truncated)
                        Text(subtask.title)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(
                                subtask.isCompleted
                                    ? Color.Lazyflow.textTertiary
                                    : Color.Lazyflow.textSecondary
                            )
                            .strikethrough(subtask.isCompleted, color: Color.Lazyflow.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Remaining count + chevron
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if remainingCount > 0 {
                        Text("+\(remainingCount) more")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    } else {
                        Text("\(completedCount)/\(totalCount)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(
                                task.allSubtasksCompleted
                                    ? Color.Lazyflow.success
                                    : Color.Lazyflow.textTertiary
                            )
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.Lazyflow.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(DesignSystem.Animation.quick, value: isExpanded)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(Color.Lazyflow.textTertiary.opacity(0.06))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(completedCount) of \(totalCount) subtasks. \(isExpanded ? "Collapse" : "Expand") to \(isExpanded ? "hide" : "show") subtasks")
    }
}

// MARK: - Intraday Progress Badge

/// Badge showing intraday completion progress (e.g., "2/3" for "Take medication 3x daily")
struct IntradayProgressBadge: View {
    let completedCount: Int
    let targetCount: Int

    /// Initialize from a task with intraday recurring rule
    init(task: Task) {
        self.completedCount = task.currentIntradayCompletions
        self.targetCount = task.intradayTargetToday
    }

    /// Initialize with explicit counts
    init(completedCount: Int, targetCount: Int) {
        self.completedCount = completedCount
        self.targetCount = targetCount
    }

    private var progress: Double {
        guard targetCount > 0 else { return 0 }
        return Double(completedCount) / Double(targetCount)
    }

    private var isComplete: Bool {
        targetCount > 0 && completedCount >= targetCount
    }

    var body: some View {
        HStack(spacing: 4) {
            // Repeat icon to indicate this is an intraday recurring task
            Image(systemName: "repeat")
                .font(.system(size: 10))

            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.Lazyflow.textTertiary.opacity(0.3), lineWidth: 2)
                    .frame(width: 14, height: 14)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isComplete ? Color.Lazyflow.success : Color.Lazyflow.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color.Lazyflow.success)
                }
            }

            // Count text
            Text("\(completedCount)/\(targetCount)")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(
                    isComplete
                        ? Color.Lazyflow.success
                        : Color.Lazyflow.textTertiary
                )
        }
        .accessibilityLabel("\(completedCount) of \(targetCount) completed today")
    }
}

// MARK: - Preview

#Preview("Progress Badge") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            SubtaskProgressBadge(completedCount: 0, totalCount: 3)
            SubtaskProgressBadge(completedCount: 1, totalCount: 3)
            SubtaskProgressBadge(completedCount: 2, totalCount: 3)
            SubtaskProgressBadge(completedCount: 3, totalCount: 3)
        }

        Divider()

        HStack(spacing: 20) {
            SubtaskCountBadge(completedCount: 0, totalCount: 5)
            SubtaskCountBadge(completedCount: 2, totalCount: 5)
            SubtaskCountBadge(completedCount: 5, totalCount: 5)
        }

        Divider()

        Text("Expandable Badges")
            .font(.headline)

        HStack(spacing: 20) {
            ExpandableSubtaskProgressBadge(
                completedCount: 2,
                totalCount: 3,
                isExpanded: false,
                onToggle: {}
            )
            ExpandableSubtaskProgressBadge(
                completedCount: 2,
                totalCount: 3,
                isExpanded: true,
                onToggle: {}
            )
            ExpandableSubtaskProgressBadge(
                completedCount: 3,
                totalCount: 3,
                isExpanded: true,
                onToggle: {}
            )
        }

        Divider()

        Text("Intraday Progress Badges")
            .font(.headline)

        HStack(spacing: 20) {
            IntradayProgressBadge(completedCount: 0, targetCount: 3)
            IntradayProgressBadge(completedCount: 1, targetCount: 3)
            IntradayProgressBadge(completedCount: 2, targetCount: 3)
            IntradayProgressBadge(completedCount: 3, targetCount: 3)
        }
    }
    .padding()
}
