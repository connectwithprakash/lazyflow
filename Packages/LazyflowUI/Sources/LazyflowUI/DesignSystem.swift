import SwiftUI
import LazyflowCore

/// Lazyflow Design System
/// Based on PRD specifications: Teal accent, SF Pro typography, WCAG AAA accessibility
public enum DesignSystem {
    // MARK: - Spacing

    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    public enum CornerRadius {
        public static let small: CGFloat = 4
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let extraLarge: CGFloat = 16
        public static let full: CGFloat = 9999
    }

    // MARK: - Typography

    public enum Typography {
        public static let largeTitle = Font.system(size: 34, weight: .bold)
        public static let title1 = Font.system(size: 28, weight: .bold)
        public static let title2 = Font.system(size: 22, weight: .bold)
        public static let title3 = Font.system(size: 20, weight: .semibold)
        public static let headline = Font.system(size: 17, weight: .semibold)
        public static let body = Font.system(size: 17, weight: .regular)
        public static let callout = Font.system(size: 16, weight: .regular)
        public static let subheadline = Font.system(size: 15, weight: .regular)
        public static let footnote = Font.system(size: 13, weight: .regular)
        public static let caption1 = Font.system(size: 12, weight: .regular)
        public static let caption2 = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Touch Targets

    public enum TouchTarget {
        /// Minimum touch target size (44pt per Apple HIG)
        public static let minimum: CGFloat = 44
        public static let comfortable: CGFloat = 48
        public static let large: CGFloat = 56
    }

    // MARK: - Animation

    public enum Animation {
        public static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        public static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Shadow

    public enum Shadow {
        public static let small = (color: Color.black.opacity(0.08), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        public static let medium = (color: Color.black.opacity(0.12), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        public static let large = (color: Color.black.opacity(0.16), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply card styling
    public func cardStyle() -> some View {
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
    public func accessibleTouchTarget() -> some View {
        self.frame(minWidth: DesignSystem.TouchTarget.minimum, minHeight: DesignSystem.TouchTarget.minimum)
    }
}

// MARK: - Button Styles

public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.TouchTarget.comfortable)
            .background(
                isEnabled
                    ? Color.Lazyflow.accent
                    : Color.Lazyflow.accent.opacity(0.5)
            )
            .cornerRadius(DesignSystem.CornerRadius.large)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(Color.Lazyflow.accent)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.TouchTarget.comfortable)
            .background(Color.Lazyflow.accent.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.large)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

public struct IconButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.Lazyflow.accent)
            .frame(width: DesignSystem.TouchTarget.minimum, height: DesignSystem.TouchTarget.minimum)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.Lazyflow.accent.opacity(0.2) : Color.clear)
            )
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Custom Components

public struct TaskCheckbox: View {
    public let isCompleted: Bool
    public let priority: Priority
    public let action: () -> Void

    public init(isCompleted: Bool, priority: Priority, action: @escaping () -> Void) {
        self.isCompleted = isCompleted
        self.priority = priority
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? Color.Lazyflow.success : priority.color,
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)

                if isCompleted {
                    Circle()
                        .fill(Color.Lazyflow.success)
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

public struct PriorityBadge: View {
    public let priority: Priority

    public init(priority: Priority) {
        self.priority = priority
    }

    public var body: some View {
        if priority != .none {
            HStack(spacing: 4) {
                Image(systemName: priority.iconName)
                    .font(.caption2)
                Text(priority.displayName)
                    .font(DesignSystem.Typography.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(priority.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
            .fixedSize()
            .accessibilityHidden(true) // Info conveyed via parent row label
        }
    }
}

public struct DueDateBadge: View {
    public let date: Date
    public let isOverdue: Bool
    public var isDueToday: Bool = false

    public init(date: Date, isOverdue: Bool, isDueToday: Bool = false) {
        self.date = date
        self.isOverdue = isOverdue
        self.isDueToday = isDueToday
    }

    private var foregroundColor: Color {
        if isOverdue { return Color.Lazyflow.error }
        if isDueToday { return Color.Lazyflow.accent }
        return Color.Lazyflow.textTertiary
    }

    private var backgroundColor: Color {
        if isOverdue { return Color.Lazyflow.error.opacity(0.15) }
        if isDueToday { return Color.Lazyflow.accent.opacity(0.12) }
        return Color.secondary.opacity(0.1)
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(date.relativeFormatted)
                .font(DesignSystem.Typography.caption2)
                .lineLimit(1)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .fixedSize()
        .accessibilityHidden(true) // Info conveyed via parent row label
    }
}

public struct ScheduledTimeBadge: View {
    public let task: Task

    public init(task: Task) {
        self.task = task
    }

    private var isPast: Bool {
        guard let start = task.scheduledStartTime else { return false }
        let referenceDate = task.scheduledEndTime ?? start
        return referenceDate < Date()
    }

    private var foregroundColor: Color {
        isPast ? Color.Lazyflow.textTertiary : Color.Lazyflow.accent
    }

    private var backgroundColor: Color {
        isPast ? Color.secondary.opacity(0.1) : Color.Lazyflow.accent.opacity(0.12)
    }

    public var body: some View {
        if let timeText = task.formattedScheduledTime {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption2)
                Text(timeText)
                    .font(DesignSystem.Typography.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.small)
            .fixedSize()
            .accessibilityHidden(true)
        }
    }
}

public struct CategoryBadge: View {
    public let category: TaskCategory

    public init(category: TaskCategory) {
        self.category = category
    }

    public var body: some View {
        if category != .uncategorized {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption2)
                Text(category.displayName)
                    .font(DesignSystem.Typography.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(category.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.15))
            .cornerRadius(DesignSystem.CornerRadius.small)
            .fixedSize()
            .accessibilityHidden(true) // Info conveyed via parent row label
        }
    }
}

public struct ListColorDot: View {
    public let colorHex: String

    public init(colorHex: String) {
        self.colorHex = colorHex
    }

    public var body: some View {
        Circle()
            .fill(Color(hex: colorHex) ?? .gray)
            .frame(width: 12, height: 12)
            .accessibilityHidden(true) // Decorative element
    }
}

// MARK: - Empty State

public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let message: String
    public var actionTitle: String? = nil
    public var action: (() -> Void)? = nil

    public init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.Lazyflow.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}
