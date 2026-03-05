import SwiftUI
import LazyflowCore
import LazyflowUI

struct BatchRescheduleSheet: View {
    let conflicts: [TaskConflict]
    let onResolveAll: (BatchRescheduleSuggestion) -> Void
    let onDismiss: () -> Void

    @StateObject private var rescheduleService = SmartRescheduleService.shared
    @Environment(\.dismiss) private var dismiss

    private var batchSuggestion: BatchRescheduleSuggestion {
        rescheduleService.suggestBatchReschedule(for: conflicts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Summary header
                    summaryHeader

                    // Auto-resolve option
                    if batchSuggestion.canAutoResolve {
                        autoResolveCard
                    }

                    // Individual conflicts
                    conflictsList
                }
                .padding()
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Schedule Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var summaryHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("\(conflicts.count) Conflicts Found")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(Color.Lazyflow.textPrimary)

            let highCount = conflicts.filter { $0.severity == .high }.count
            if highCount > 0 {
                Text("\(highCount) high severity")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.error)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var autoResolveCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(Color.Lazyflow.accent)
                Text("Smart Reschedule")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
            }

            Text("Automatically reschedule all \(conflicts.count) tasks to their optimal times.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Button {
                onResolveAll(batchSuggestion)
            } label: {
                Text("Resolve All Conflicts")
                    .font(DesignSystem.Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Lazyflow.accent)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .accessibilityIdentifier("ResolveAllConflicts")
        }
        .padding()
        .background(Color.Lazyflow.accent.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private var conflictsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Individual Conflicts")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(Color.Lazyflow.textPrimary)

            ForEach(batchSuggestion.suggestions, id: \.conflict.id) { suggestion in
                conflictRow(suggestion)
            }
        }
    }

    private func conflictRow(_ suggestion: RescheduleSuggestion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.conflict.task.title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
                    .lineLimit(1)

                Text(suggestion.conflict.conflictDescription)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .lineLimit(1)

                if let recommended = suggestion.recommendedOption {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                        Text(recommended.formattedTime)
                            .font(DesignSystem.Typography.caption1)
                    }
                    .foregroundColor(Color.Lazyflow.accent)
                }
            }

            Spacer()

            Image(systemName: suggestion.conflict.severity.systemImage)
                .foregroundColor(severityColor(for: suggestion.conflict.severity))
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func severityColor(for severity: ConflictSeverity) -> Color {
        switch severity {
        case .high: return Color.Lazyflow.error
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}
