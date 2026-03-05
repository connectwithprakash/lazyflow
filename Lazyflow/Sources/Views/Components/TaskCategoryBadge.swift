import SwiftUI
import LazyflowCore
import LazyflowUI

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
