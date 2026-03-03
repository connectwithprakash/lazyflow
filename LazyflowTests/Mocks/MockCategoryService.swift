import Foundation
import SwiftUI
@testable import Lazyflow

/// In-memory mock of CategoryServiceProtocol for testing.
final class MockCategoryService: CategoryServiceProtocol {
    private(set) var categories: [CustomCategory] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    private(set) var calls: [String] = []

    func fetchAllCategories() {
        calls.append("fetchAllCategories")
    }

    func getCategory(byID id: UUID) -> CustomCategory? {
        calls.append("getCategory(byID:)")
        return categories.first { $0.id == id }
    }

    func getCategory(byName name: String) -> CustomCategory? {
        calls.append("getCategory(byName:)")
        return categories.first { $0.name == name }
    }

    @discardableResult
    func createCategory(name: String, colorHex: String, iconName: String) -> CustomCategory {
        calls.append("createCategory")
        let category = CustomCategory(
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            order: Int32(categories.count)
        )
        categories.append(category)
        return category
    }

    func updateCategory(_ category: CustomCategory) {
        calls.append("updateCategory")
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        }
    }

    func reorderCategories(_ categories: [CustomCategory]) {
        calls.append("reorderCategories")
        self.categories = categories
    }

    func deleteCategory(_ category: CustomCategory) {
        calls.append("deleteCategory")
        categories.removeAll { $0.id == category.id }
    }

    func categoryNameExists(_ name: String, excludingID: UUID?) -> Bool {
        calls.append("categoryNameExists")
        return categories.contains { $0.name == name && $0.id != excludingID }
    }

    func conflictsWithSystemCategory(_ name: String) -> Bool {
        calls.append("conflictsWithSystemCategory")
        return false
    }

    func getCategoryDisplay(
        systemCategory: TaskCategory,
        customCategoryID: UUID?
    ) -> (name: String, color: Color, iconName: String) {
        calls.append("getCategoryDisplay")
        if let customID = customCategoryID, let custom = getCategory(byID: customID) {
            return (custom.name, custom.color, custom.iconName)
        }
        return (systemCategory.displayName, .gray, "tag.fill")
    }

    func getAllCategoriesForPicker() -> [(id: String, name: String, color: Color, iconName: String, isCustom: Bool)] {
        calls.append("getAllCategoriesForPicker")
        return categories.map { ($0.id.uuidString, $0.name, $0.color, $0.iconName, true) }
    }
}
