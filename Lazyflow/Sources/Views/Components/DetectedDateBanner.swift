import SwiftUI

struct DetectedDateBanner: View {
    let date: Date
    let time: Date?
    let matchedText: String
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16))
                .foregroundColor(Color.Lazyflow.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Date detected: \"\(matchedText)\"")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                HStack(spacing: 4) {
                    Text(date.relativeFormatted)
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)

                    if let time = time {
                        Text("at \(time.timeFormatted)")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            }

            Spacer()

            Button(action: onApply) {
                Text("Apply")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(Color.Lazyflow.accent)
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
            .accessibilityLabel("Dismiss date suggestion")
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.Lazyflow.accent.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}
