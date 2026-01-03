import SwiftUI

/// Toast message types for undo actions
enum UndoAction: Equatable {
    case completed(Task)
    case deleted(Task)
    case movedToToday(Task)
    case pushedToTomorrow(Task)

    var message: String {
        switch self {
        case .completed(let task):
            return "'\(task.title)' completed"
        case .deleted(let task):
            return "'\(task.title)' deleted"
        case .movedToToday(let task):
            return "'\(task.title)' moved to today"
        case .pushedToTomorrow(let task):
            return "'\(task.title)' moved to tomorrow"
        }
    }

    var icon: String {
        switch self {
        case .completed:
            return "checkmark.circle.fill"
        case .deleted:
            return "trash.fill"
        case .movedToToday:
            return "star.fill"
        case .pushedToTomorrow:
            return "arrow.right.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .completed:
            return Color.Taskweave.success
        case .deleted:
            return Color.Taskweave.error
        case .movedToToday:
            return .blue
        case .pushedToTomorrow:
            return .orange
        }
    }

    var task: Task {
        switch self {
        case .completed(let task), .deleted(let task),
             .movedToToday(let task), .pushedToTomorrow(let task):
            return task
        }
    }
}

/// Undo toast view shown at the bottom of the screen
struct UndoToastView: View {
    let action: UndoAction
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: action.icon)
                .foregroundColor(action.iconColor)
                .font(.system(size: 18, weight: .semibold))

            Text(action.message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Taskweave.textPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                onUndo()
            } label: {
                Text("Undo")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Taskweave.accent)
            }
            .accessibilityIdentifier("UndoButton")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color.adaptiveSurface)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(Color.Taskweave.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xl)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            isVisible = true
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                dismiss()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 20 {
                        dismiss()
                    }
                }
        )
    }

    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

/// View modifier to add undo toast capability to any view
struct UndoToastModifier: ViewModifier {
    @Binding var undoAction: UndoAction?
    let onUndo: (UndoAction) -> Void

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if let action = undoAction {
                UndoToastView(
                    action: action,
                    onUndo: {
                        onUndo(action)
                        undoAction = nil
                    },
                    onDismiss: {
                        undoAction = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

extension View {
    /// Adds an undo toast overlay to the view
    func undoToast(action: Binding<UndoAction?>, onUndo: @escaping (UndoAction) -> Void) -> some View {
        modifier(UndoToastModifier(undoAction: action, onUndo: onUndo))
    }
}

// MARK: - Error Toast

/// Simple error toast for displaying failures
struct ErrorToastView: View {
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.Taskweave.error)
                .font(.system(size: 18, weight: .semibold))

            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Taskweave.textPrimary)
                .lineLimit(2)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.Taskweave.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color.adaptiveSurface)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(Color.Taskweave.error.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xl)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            isVisible = true
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismiss()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 20 {
                        dismiss()
                    }
                }
        )
    }

    private func dismiss() {
        guard isVisible else { return }
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

/// View modifier to add error toast capability to any view
struct ErrorToastModifier: ViewModifier {
    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if let message = errorMessage {
                ErrorToastView(
                    message: message,
                    onDismiss: {
                        errorMessage = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

extension View {
    /// Adds an error toast overlay to the view
    func errorToast(message: Binding<String?>) -> some View {
        modifier(ErrorToastModifier(errorMessage: message))
    }
}

// MARK: - Preview

#Preview("Undo Toast") {
    ZStack {
        Color.adaptiveBackground
            .ignoresSafeArea()

        VStack {
            Text("Main Content")
            Spacer()
        }

        VStack {
            Spacer()
            UndoToastView(
                action: .completed(Task(title: "Buy groceries")),
                onUndo: { print("Undo tapped") },
                onDismiss: { print("Dismissed") }
            )
        }
    }
}

#Preview("Error Toast") {
    ZStack {
        Color.adaptiveBackground
            .ignoresSafeArea()

        VStack {
            Text("Main Content")
            Spacer()
        }

        VStack {
            Spacer()
            ErrorToastView(
                message: "Failed to sync task to calendar",
                onDismiss: { print("Dismissed") }
            )
        }
    }
}
