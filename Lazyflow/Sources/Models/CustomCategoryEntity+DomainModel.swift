import Foundation
import LazyflowCore

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
