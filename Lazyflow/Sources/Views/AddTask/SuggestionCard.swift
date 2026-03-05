import SwiftUI
import LazyflowCore
import LazyflowUI

struct SuggestionCard<Action: View>: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)

                    Text(value)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                }
            }

            Spacer()

            action()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal)
    }
}

// MARK: - Apply Button

struct ApplyButton: View {
    let isApplied: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isApplied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(isApplied ? "Applied" : "Apply")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isApplied ? .white : color)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isApplied ? color : color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .disabled(isApplied)
        .animation(.easeInOut(duration: 0.2), value: isApplied)
        .accessibilityIdentifier(isApplied ? "Applied" : "Apply")
    }
}

// MARK: - Toggle Apply Button (can un-apply)

struct ToggleApplyButton: View {
    @Binding var isApplied: Bool
    let color: Color
    let onApply: () -> Void
    let onUnapply: () -> Void

    var body: some View {
        Button {
            if isApplied {
                onUnapply()
                isApplied = false
            } else {
                onApply()
                isApplied = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isApplied ? "checkmark" : "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(isApplied ? "Applied" : "Apply")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isApplied ? .white : color)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isApplied ? color : color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .animation(.easeInOut(duration: 0.2), value: isApplied)
        .accessibilityLabel(isApplied ? "Un-apply suggestion" : "Apply suggestion")
    }
}
