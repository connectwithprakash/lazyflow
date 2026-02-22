import SwiftUI

/// Lazyflow Design System
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
                    ? Color.Lazyflow.accent
                    : Color.Lazyflow.accent.opacity(0.5)
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
            .foregroundColor(Color.Lazyflow.accent)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.TouchTarget.comfortable)
            .background(Color.Lazyflow.accent.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.large)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
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

struct TaskCheckbox: View {
    let isCompleted: Bool
    let priority: Priority
    let action: () -> Void

    var body: some View {
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

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
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

struct DueDateBadge: View {
    let date: Date
    let isOverdue: Bool
    var isDueToday: Bool = false

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

    var body: some View {
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

struct ScheduledTimeBadge: View {
    let task: Task

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

    var body: some View {
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

struct CategoryBadge: View {
    let category: TaskCategory

    var body: some View {
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

struct TaskCategoryBadge: View {
    let systemCategory: TaskCategory
    var customCategoryID: UUID?
    var isCompleted: Bool = false

    private var display: (name: String, color: Color, iconName: String) {
        CategoryService.shared.getCategoryDisplay(systemCategory: systemCategory, customCategoryID: customCategoryID)
    }

    /// True when a real category exists (handles stale customCategoryID gracefully)
    private var hasCategory: Bool {
        let info = display
        // If customCategoryID is dangling (deleted), getCategoryDisplay falls back to system.
        // Only show badge when there's a meaningful category.
        if let _ = customCategoryID {
            return info.name != TaskCategory.uncategorized.displayName
        }
        return systemCategory != .uncategorized
    }

    var body: some View {
        if hasCategory {
            Image(systemName: display.iconName)
                .font(.caption2)
                .foregroundColor(display.color)
                .opacity(isCompleted ? 0.5 : 1.0)
                .accessibilityHidden(true)
        }
    }
}

struct ListColorDot: View {
    let colorHex: String

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex) ?? .gray)
            .frame(width: 12, height: 12)
            .accessibilityHidden(true) // Decorative element
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
