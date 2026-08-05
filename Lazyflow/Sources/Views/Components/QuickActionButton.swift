import SwiftUI
import LazyflowCore
import LazyflowUI

struct QuickActionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color
    /// Stable identifier for UI tests (labels alone can collide, e.g. the
    /// "Today" chip vs the "Today" tab bar item)
    var accessibilityID: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionButtonContent(icon: icon, title: title, isSelected: isSelected, color: color)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityID ?? "")
    }
}

struct QuickActionButtonContent: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(isSelected ? color : Color.Lazyflow.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            isSelected
                ? color.opacity(0.15)
                : Color.secondary.opacity(0.1)
        )
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}
