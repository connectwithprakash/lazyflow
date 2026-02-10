import SwiftUI

struct ReminderQuickOption: View {
    let title: String
    let time: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.medium)
                Text(time)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
