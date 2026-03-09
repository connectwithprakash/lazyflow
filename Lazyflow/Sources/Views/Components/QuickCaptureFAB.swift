import SwiftUI
import LazyflowCore
import LazyflowUI

/// Floating action button for quick capture — 56pt accent circle with pencil icon.
/// Freely draggable along the right edge; position persists across launches.
struct QuickCaptureFAB: View {
    let action: () -> Void
    let containerHeight: CGFloat
    let containerWidth: CGFloat
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat
    let isFocusPillVisible: Bool

    private let fabSize: CGFloat = DesignSystem.TouchTarget.large
    private let trailingMargin: CGFloat = DesignSystem.Spacing.lg

    @AppStorage(AppConstants.StorageKey.fabVerticalPosition) private var savedYPosition: Double = -1
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isAppearing = false

    /// Top of the allowed vertical range (below nav bar / + button area)
    private var minY: CGFloat {
        safeAreaTop + 60
    }

    /// Bottom of the allowed vertical range (above tab bar, accounting for focus pill)
    private var maxY: CGFloat {
        containerHeight - safeAreaBottom - (isFocusPillVisible ? 120 : 60) - fabSize
    }

    /// The base Y position before any active drag offset
    private var currentY: CGFloat {
        if savedYPosition < 0 {
            return maxY
        }
        return clamp(CGFloat(savedYPosition))
    }

    /// Final Y accounting for active drag gesture
    private var effectiveY: CGFloat {
        clamp(currentY + dragOffset)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, minY), maxY)
    }

    var body: some View {
        Image(systemName: "pencil.line")
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: fabSize, height: fabSize)
            .background(Color.Lazyflow.accent)
            .clipShape(Circle())
            .shadow(color: Color.Lazyflow.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            .contentShape(Circle())
            .scaleEffect(isAppearing ? 1.0 : 0.5)
            .opacity(isAppearing ? 1.0 : 0.0)
            .position(
                x: containerWidth - trailingMargin - fabSize / 2,
                y: effectiveY + fabSize / 2
            )
            .gesture(
                DragGesture(minimumDistance: 10)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onChanged { _ in
                        isDragging = true
                    }
                    .onEnded { value in
                        let finalY = clamp(currentY + value.translation.height)
                        savedYPosition = Double(finalY)
                        // Delay resetting isDragging so the tap doesn't fire
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isDragging = false
                        }
                    }
            )
            .onTapGesture {
                if !isDragging {
                    action()
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isAppearing = true
                }
            }
            .onChange(of: isFocusPillVisible) {
                // Push FAB up if it would overlap the focus pill
                if savedYPosition >= 0 {
                    let clamped = clamp(CGFloat(savedYPosition))
                    if clamped != CGFloat(savedYPosition) {
                        savedYPosition = Double(clamped)
                    }
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Quick Capture")
            .accessibilityHint("Opens a quick note for capturing thoughts. Drag to reposition.")
    }
}

#Preview {
    GeometryReader { geometry in
        QuickCaptureFAB(
            action: { },
            containerHeight: geometry.size.height,
            containerWidth: geometry.size.width,
            safeAreaTop: geometry.safeAreaInsets.top,
            safeAreaBottom: geometry.safeAreaInsets.bottom,
            isFocusPillVisible: false
        )
    }
    .background(Color.adaptiveBackground)
}
