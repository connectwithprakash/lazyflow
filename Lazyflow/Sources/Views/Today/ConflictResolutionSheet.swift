import SwiftUI
import LazyflowCore
import LazyflowUI

struct ConflictResolutionSheet: View {
    let conflict: TaskConflict
    let onReschedule: (RescheduleOption) -> Void
    let onPushToTomorrow: () -> Void
    let onDismiss: () -> Void

    @StateObject private var rescheduleService = SmartRescheduleService.shared
    @Environment(\.dismiss) private var dismiss

    private var suggestion: RescheduleSuggestion {
        rescheduleService.suggestReschedule(for: conflict)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Conflict summary
                    conflictSummaryCard

                    // Recommended action
                    if let recommended = suggestion.recommendedOption {
                        recommendedActionCard(recommended)
                    }

                    // Other options
                    if suggestion.options.count > 1 {
                        otherOptionsSection
                    }

                    // Quick actions
                    quickActionsSection

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var conflictSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Severity indicator
            HStack {
                Image(systemName: conflict.severity.systemImage)
                    .foregroundColor(severityColor)
                Text("\(conflict.severity.displayName) Severity")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(severityColor)
                Spacer()
            }

            Divider()

            // Task info
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(Color.Lazyflow.accent)
                VStack(alignment: .leading) {
                    Text("Task")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textTertiary)
                    Text(conflict.task.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                }
                Spacer()
            }

            // Conflicting event info
            if let event = conflict.conflictingEvent {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Conflicts with")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        Text(event.title)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                        Text(event.formattedTimeRange)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                    Spacer()
                }
            }

            // Conflicting task info (for task-to-task conflicts)
            if let conflictingTask = conflict.conflictingTask {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Conflicts with task")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textTertiary)
                        Text(conflictingTask.title)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                        if let dueTime = conflictingTask.dueTime {
                            Text(dueTime.formatted(date: .omitted, time: .shortened))
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                    Spacer()
                }
            }

            // Overlap info
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(Color.Lazyflow.error)
                Text(conflict.formattedOverlap)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func recommendedActionCard(_ option: RescheduleOption) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("Recommended")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.accent)
            }

            Button {
                onReschedule(option)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.formattedTime)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(Color.Lazyflow.textPrimary)
                        Text(option.reason)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.Lazyflow.accent)
                }
                .padding()
                .background(Color.Lazyflow.accent.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .buttonStyle(.plain)
        }
    }

    private var otherOptionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Other Options")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            ForEach(suggestion.options.dropFirst().prefix(3)) { option in
                Button {
                    onReschedule(option)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.formattedTime)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                            Text(option.reason)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                    .padding()
                    .background(Color.adaptiveSurface)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Quick Actions")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Button {
                onPushToTomorrow()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.to.line")
                        .foregroundColor(Color.Lazyflow.accent)
                    Text("Push to Tomorrow")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                    Spacer()
                }
                .padding()
                .background(Color.adaptiveSurface)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("PushToTomorrow")
        }
    }

    private var severityColor: Color {
        switch conflict.severity {
        case .high: return Color.Lazyflow.error
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}
