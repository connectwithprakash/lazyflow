import Foundation
import SwiftUI

/// A user-created custom category for tasks
struct CustomCategory: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var order: Int32
    let createdAt: Date

    // MARK: - Computed Properties

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    var displayName: String {
        name
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#808080",
        iconName: String = "tag.fill",
        order: Int32 = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.order = order
        self.createdAt = createdAt
    }

    // MARK: - Update Methods

    func updated(
        name: String? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        order: Int32? = nil
    ) -> CustomCategory {
        CustomCategory(
            id: self.id,
            name: name ?? self.name,
            colorHex: colorHex ?? self.colorHex,
            iconName: iconName ?? self.iconName,
            order: order ?? self.order,
            createdAt: self.createdAt
        )
    }
}

// MARK: - CustomCategoryEntity to Domain Model

extension CustomCategoryEntity {
    func toDomainModel() -> CustomCategory {
        CustomCategory(
            id: id ?? UUID(),
            name: name ?? "",
            colorHex: colorHex ?? "#808080",
            iconName: iconName ?? "tag.fill",
            order: order,
            createdAt: createdAt ?? Date()
        )
    }
}

// MARK: - Category Selection Type

/// Represents either a system category or a custom category
enum CategorySelection: Equatable, Hashable {
    case system(TaskCategory)
    case custom(UUID)

    var isUncategorized: Bool {
        if case .system(let category) = self {
            return category == .uncategorized
        }
        return false
    }

    var systemCategory: TaskCategory? {
        if case .system(let category) = self {
            return category
        }
        return nil
    }

    var customCategoryID: UUID? {
        if case .custom(let id) = self {
            return id
        }
        return nil
    }
}

// MARK: - Available Category Icons

extension CustomCategory {
    /// Icons available for custom categories
    static let availableIcons: [String] = [
        "tag.fill",
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "flame.fill",
        "leaf.fill",
        "drop.fill",
        "snowflake",
        "sun.max.fill",
        "moon.fill",
        "cloud.fill",
        "umbrella.fill",
        "paintbrush.fill",
        "hammer.fill",
        "wrench.fill",
        "gearshape.fill",
        "lightbulb.fill",
        "bell.fill",
        "flag.fill",
        "bookmark.fill",
        "folder.fill",
        "tray.fill",
        "archivebox.fill",
        "doc.fill",
        "paperclip",
        "link",
        "pin.fill",
        "mappin",
        "gift.fill",
        "bag.fill",
        "creditcard.fill",
        "banknote.fill",
        "chart.bar.fill",
        "trophy.fill",
        "medal.fill",
        "graduationcap.fill",
        "music.note",
        "film.fill",
        "gamecontroller.fill",
        "sportscourt.fill",
        "dumbbell.fill",
        "figure.run",
        "bicycle",
        "car.fill",
        "airplane",
        "bus.fill",
        "tram.fill",
        "ferry.fill"
    ]

    /// Colors available for custom categories
    static let availableColors: [String] = [
        "#808080", // Gray
        "#FF6B6B", // Red
        "#FF8E72", // Coral
        "#FFA94D", // Orange
        "#FFD43B", // Yellow
        "#A9E34B", // Lime
        "#69DB7C", // Green
        "#38D9A9", // Teal
        "#3BC9DB", // Cyan
        "#4DABF7", // Blue
        "#748FFC", // Indigo
        "#9775FA", // Purple
        "#DA77F2", // Magenta
        "#F783AC", // Pink
        "#A68A64", // Brown
        "#495057"  // Dark Gray
    ]
}
