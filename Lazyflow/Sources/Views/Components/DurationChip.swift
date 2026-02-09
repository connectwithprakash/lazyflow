import SwiftUI

struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(isSelected ? .white : Color.Lazyflow.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    isSelected
                        ? Color.Lazyflow.accent
                        : Color.secondary.opacity(0.1)
                )
                .cornerRadius(DesignSystem.CornerRadius.full)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
