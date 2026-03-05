import SwiftUI
import LazyflowCore
import LazyflowUI

/// Floating action button for quick capture — 56pt accent circle with pencil icon
struct QuickCaptureFAB: View {
    let action: () -> Void

    @State private var isAppearing = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil.line")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: DesignSystem.TouchTarget.large, height: DesignSystem.TouchTarget.large)
                .background(Color.Lazyflow.accent)
                .clipShape(Circle())
                .shadow(color: Color.Lazyflow.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isAppearing ? 1.0 : 0.5)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAppearing = true
            }
        }
        .accessibilityLabel("Quick Capture")
        .accessibilityHint("Opens a quick note for capturing thoughts")
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        Color.adaptiveBackground
            .ignoresSafeArea()

        QuickCaptureFAB { }
            .padding()
    }
}
