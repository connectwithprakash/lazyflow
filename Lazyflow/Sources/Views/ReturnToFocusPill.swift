import SwiftUI

/// Floating pill shown when Focus Mode is dismissed but task is still in progress.
/// Tap "Resume" to reopen the full-screen focus view.
struct ReturnToFocusPill: View {
    @EnvironmentObject private var coordinator: FocusSessionCoordinator

    private var tintColor: Color {
        coordinator.isOnBreak ? .orange : Color.Lazyflow.accent
    }

    var body: some View {
        if let task = coordinator.focusedTask {
            Button {
                coordinator.reopenFocus()
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: coordinator.isOnBreak ? "moon.fill" : "timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(tintColor)

                    Text(task.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text("Resume")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(tintColor)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge)
                        .fill(Color.adaptiveSurface)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge)
                        .stroke(
                            coordinator.isOnBreak
                                ? .orange.opacity(0.3)
                                : Color.Lazyflow.textTertiary.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Resume focusing on \(task.title)")
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
