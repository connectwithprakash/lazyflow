import Foundation
import SwiftUI

/// Protocol defining the public API surface of CategoryService consumed by ViewModels.
protocol CategoryServiceProtocol: AnyObject {
    var categories: [CustomCategory] { get }
    var isLoading: Bool { get }
    var error: Error? { get }

    func fetchAllCategories()
    func getCategory(byID id: UUID) -> CustomCategory?
    func getCategory(byName name: String) -> CustomCategory?

    @discardableResult
    func createCategory(name: String, colorHex: String, iconName: String) -> CustomCategory

    func updateCategory(_ category: CustomCategory)
    func reorderCategories(_ categories: [CustomCategory])
    func deleteCategory(_ category: CustomCategory)

    func categoryNameExists(_ name: String, excludingID: UUID?) -> Bool
    func conflictsWithSystemCategory(_ name: String) -> Bool

    func getCategoryDisplay(
        systemCategory: TaskCategory,
        customCategoryID: UUID?
    ) -> (name: String, color: Color, iconName: String)

    func getAllCategoriesForPicker() -> [(id: String, name: String, color: Color, iconName: String, isCustom: Bool)]
}

// MARK: - Default Parameter Values

extension CategoryServiceProtocol {
    @discardableResult
    func createCategory(
        name: String,
        colorHex: String = "#808080",
        iconName: String = "tag.fill"
    ) -> CustomCategory {
        createCategory(name: name, colorHex: colorHex, iconName: iconName)
    }

    func categoryNameExists(_ name: String, excludingID: UUID? = nil) -> Bool {
        categoryNameExists(name, excludingID: excludingID)
    }
}
