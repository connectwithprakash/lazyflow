import SwiftUI

/// Celebration toast shown when all subtasks are completed and parent is auto-completed
struct AutoCompleteCelebrationView: View {
    let parentTitle: String
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var sparklePhase = 0.0

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Sparkle icon
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: isVisible)

            // Message
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("All subtasks complete!")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text("\"\(parentTitle)\" has been marked complete.")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Dismiss button
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDismiss()
                }
            } label: {
                Text("Great!")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.white)
                    .frame(minWidth: 120)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .background(Color.Lazyflow.success)
                    .cornerRadius(DesignSystem.CornerRadius.full)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.extraLarge)
        .shadow(
            color: DesignSystem.Shadow.large.color,
            radius: DesignSystem.Shadow.large.radius,
            x: DesignSystem.Shadow.large.x,
            y: DesignSystem.Shadow.large.y
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
}

/// View modifier to show auto-complete celebration
struct AutoCompleteCelebrationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let parentTitle: String

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }

                // Celebration card
                AutoCompleteCelebrationView(
                    parentTitle: parentTitle,
                    onDismiss: {
                        isPresented = false
                    }
                )
                .padding()
            }
        }
        .animation(DesignSystem.Animation.standard, value: isPresented)
    }
}

extension View {
    func autoCompleteCelebration(isPresented: Binding<Bool>, parentTitle: String) -> some View {
        self.modifier(AutoCompleteCelebrationModifier(isPresented: isPresented, parentTitle: parentTitle))
    }
}

// MARK: - Preview

#Preview("Celebration Toast") {
    ZStack {
        Color.adaptiveBackground
            .ignoresSafeArea()

        AutoCompleteCelebrationView(
            parentTitle: "Plan project architecture",
            onDismiss: {}
        )
    }
}
