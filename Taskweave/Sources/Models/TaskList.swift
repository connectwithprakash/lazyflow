import Foundation
import SwiftUI

/// Domain model representing a task list/project
struct TaskList: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var iconName: String?
    var order: Int32
    var isDefault: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#218A8D",
        iconName: String? = nil,
        order: Int32 = 0,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.order = order
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    /// SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex) ?? .teal
    }

    /// System icon or default
    var icon: String {
        iconName ?? "list.bullet"
    }
}

// MARK: - Default Lists
extension TaskList {
    static let inbox = TaskList(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Inbox",
        colorHex: "#5A6C71",
        iconName: "tray",
        order: 0,
        isDefault: true
    )

    static let defaultLists: [TaskList] = [
        inbox
    ]

    static let sampleLists: [TaskList] = [
        inbox,
        TaskList(name: "Work", colorHex: "#218A8D", iconName: "briefcase", order: 1),
        TaskList(name: "Personal", colorHex: "#22C876", iconName: "person", order: 2),
        TaskList(name: "Shopping", colorHex: "#E68157", iconName: "cart", order: 3)
    ]
}

// MARK: - Predefined Colors
extension TaskList {
    static let availableColors: [String] = [
        "#218A8D", // Teal (Primary)
        "#5A6C71", // Gray
        "#22C876", // Green
        "#FF5459", // Red
        "#E68157", // Orange
        "#FFB800", // Yellow
        "#007AFF", // Blue
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5856D6", // Indigo
        "#00C7BE", // Cyan
        "#FF9500"  // Orange (Apple)
    ]

    static let availableIcons: [String] = [
        "list.bullet",
        "tray",
        "briefcase",
        "person",
        "cart",
        "house",
        "heart",
        "star",
        "flag",
        "bookmark",
        "folder",
        "doc",
        "calendar",
        "clock",
        "bell",
        "gear"
    ]
}
