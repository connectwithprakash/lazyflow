import SwiftUI

/// Taskweave Design System
/// Based on PRD specifications: Teal accent, SF Pro typography, WCAG AAA accessibility
enum DesignSystem {
    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
        static let full: CGFloat = 9999
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .bold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption1 = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Touch Targets

    enum TouchTarget {
        /// Minimum touch target size (44pt per Apple HIG)
        static let minimum: CGFloat = 44
        static let comfortable: CGFloat = 48
        static let large: CGFloat = 56
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Shadow

    enum Shadow {
        static let small = (color: Color.black.opacity(0.08), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.12), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.16), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply card styling
    func cardStyle() -> some View {
        self
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .shadow(
                color: DesignSystem.Shadow.small.color,
                radius: DesignSystem.Shadow.small.radius,
                x: DesignSystem.Shadow.small.x,
                y: DesignSystem.Shadow.small.y
            )
    }

    /// Ensure minimum touch target size
    func accessibleTouchTarget() -> some View {
        self.frame(minWidth: DesignSystem.TouchTarget.minimum, minHeight: DesignSystem.TouchTarget.minimum)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.TouchTarget.comfortable)
            .background(
                isEnabled
                    ? Color.Taskweave.accent
                    : Color.Taskweave.accent.opacity(0.5)
            )
            .cornerRadius(DesignSystem.CornerRadius.large)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(Color.Taskweave.accent)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.TouchTarget.comfortable)
            .background(Color.Taskweave.accent.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.large)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.Taskweave.accent)
            .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.Taskweave.accent.opacity(0.2) : Color.clear)
            )
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Custom Components

struct TaskCheckbox: View {
    let isCompleted: Bool
    let priority: Priority
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? Color.Taskweave.success : priority.color,
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)

                if isCompleted {
                    Circle()
                        .fill(Color.Taskweave.success)
                        .frame(width: 24, height: 24)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .accessibleTouchTarget()
        .accessibilityLabel(isCompleted ? "Mark incomplete" : "Mark complete")
    }
}

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        if priority != .none {
            HStack(spacing: 4) {
                Image(systemName: priority.iconName)
                    .font(.caption2)
                Text(priority.displayName)
                    .font(DesignSystem.Typography.caption2)
            }
            .foregroundColor(priority.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
    }
}

struct DueDateBadge: View {
    let date: Date
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(date.relativeFormatted)
                .font(DesignSystem.Typography.caption2)
        }
        .foregroundColor(isOverdue ? Color.Taskweave.error : Color.Taskweave.textTertiary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isOverdue
                ? Color.Taskweave.error.opacity(0.15)
                : Color.secondary.opacity(0.1)
        )
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
}

struct CategoryBadge: View {
    let category: TaskCategory

    var body: some View {
        if category != .uncategorized {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption2)
                Text(category.displayName)
                    .font(DesignSystem.Typography.caption2)
            }
            .foregroundColor(category.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
    }
}

struct ListColorDot: View {
    let colorHex: String

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex) ?? .gray)
            .frame(width: 12, height: 12)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.Taskweave.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(Color.Taskweave.textPrimary)

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Taskweave.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 200)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
    }
}
