import SwiftUI

/// Bottom sheet showing up to 2 alternative suggestions for switching focus.
struct SwitchFocusTaskSheet: View {
    @EnvironmentObject private var coordinator: FocusSessionCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.alternatives.isEmpty {
                    emptyState
                } else {
                    alternativesList
                }
            }
            .navigationTitle("Switch Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var alternativesList: some View {
        List {
            ForEach(coordinator.alternatives) { suggestion in
                Button {
                    coordinator.switchTask(to: suggestion.task)
                    dismiss()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Circle()
                            .fill(suggestion.task.priority.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: suggestion.task.priority.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(suggestion.task.priority.color)
                            )

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text(suggestion.task.title)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.Lazyflow.textPrimary)
                                .lineLimit(2)

                            if let topReason = suggestion.reasons.first {
                                Text(topReason)
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textTertiary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text("No alternative suggestions right now")
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
