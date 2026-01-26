import XCTest
import CoreData
@testable import Lazyflow

@MainActor
final class CategoryServiceTests: XCTestCase {
    var persistenceController: PersistenceController!
    var categoryService: CategoryService!
    var taskService: TaskService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        categoryService = CategoryService(persistenceController: persistenceController)
        taskService = TaskService(persistenceController: persistenceController)
    }

    override func tearDownWithError() throws {
        persistenceController.deleteAllDataEverywhere()
        persistenceController = nil
        categoryService = nil
        taskService = nil
    }

    // MARK: - Create Tests

    func testCreateCategory() throws {
        let category = categoryService.createCategory(name: "Work Projects")

        XCTAssertEqual(category.name, "Work Projects")
        XCTAssertEqual(category.colorHex, "#808080")
        XCTAssertEqual(category.iconName, "tag.fill")
        XCTAssertEqual(categoryService.categories.count, 1)
    }

    func testCreateCategoryWithCustomization() throws {
        let category = categoryService.createCategory(
            name: "Urgent",
            colorHex: "#FF6B6B",
            iconName: "flame.fill"
        )

        XCTAssertEqual(category.name, "Urgent")
        XCTAssertEqual(category.colorHex, "#FF6B6B")
        XCTAssertEqual(category.iconName, "flame.fill")
    }

    func testCreateMultipleCategories_OrderIncrementsAutomatically() throws {
        let category1 = categoryService.createCategory(name: "Category 1")
        let category2 = categoryService.createCategory(name: "Category 2")
        let category3 = categoryService.createCategory(name: "Category 3")

        XCTAssertLessThan(category1.order, category2.order)
        XCTAssertLessThan(category2.order, category3.order)
    }

    // MARK: - Read Tests

    func testFetchAllCategories() throws {
        categoryService.createCategory(name: "Category 1")
        categoryService.createCategory(name: "Category 2")
        categoryService.createCategory(name: "Category 3")

        categoryService.fetchAllCategories()

        XCTAssertEqual(categoryService.categories.count, 3)
    }

    func testFetchAllCategories_SortedByOrder() throws {
        let cat1 = categoryService.createCategory(name: "First")
        let cat2 = categoryService.createCategory(name: "Second")
        let cat3 = categoryService.createCategory(name: "Third")

        // Reorder to: Third, First, Second
        categoryService.reorderCategories([cat3, cat1, cat2])
        categoryService.fetchAllCategories()

        XCTAssertEqual(categoryService.categories[0].name, "Third")
        XCTAssertEqual(categoryService.categories[1].name, "First")
        XCTAssertEqual(categoryService.categories[2].name, "Second")
    }

    func testGetCategoryByID() throws {
        let createdCategory = categoryService.createCategory(name: "Test Category")

        let fetchedCategory = categoryService.getCategory(byID: createdCategory.id)

        XCTAssertNotNil(fetchedCategory)
        XCTAssertEqual(fetchedCategory?.name, "Test Category")
    }

    func testGetCategoryByID_NotFound() throws {
        let nonExistentID = UUID()

        let fetchedCategory = categoryService.getCategory(byID: nonExistentID)

        XCTAssertNil(fetchedCategory)
    }

    func testGetCategoryByName() throws {
        categoryService.createCategory(name: "Shopping List")

        let fetchedCategory = categoryService.getCategory(byName: "Shopping List")

        XCTAssertNotNil(fetchedCategory)
        XCTAssertEqual(fetchedCategory?.name, "Shopping List")
    }

    func testGetCategoryByName_CaseInsensitive() throws {
        categoryService.createCategory(name: "Work Projects")

        let fetchedLower = categoryService.getCategory(byName: "work projects")
        let fetchedUpper = categoryService.getCategory(byName: "WORK PROJECTS")
        let fetchedMixed = categoryService.getCategory(byName: "Work PROJECTS")

        XCTAssertNotNil(fetchedLower)
        XCTAssertNotNil(fetchedUpper)
        XCTAssertNotNil(fetchedMixed)
    }

    func testGetCategoryByName_NotFound() throws {
        categoryService.createCategory(name: "Existing Category")

        let fetchedCategory = categoryService.getCategory(byName: "Non-Existent")

        XCTAssertNil(fetchedCategory)
    }

    // MARK: - Update Tests

    func testUpdateCategory() throws {
        let category = categoryService.createCategory(name: "Original Name")

        let updatedCategory = category.updated(
            name: "Updated Name",
            colorHex: "#FF5459",
            iconName: "star.fill"
        )
        categoryService.updateCategory(updatedCategory)

        let fetchedCategory = categoryService.getCategory(byID: category.id)
        XCTAssertEqual(fetchedCategory?.name, "Updated Name")
        XCTAssertEqual(fetchedCategory?.colorHex, "#FF5459")
        XCTAssertEqual(fetchedCategory?.iconName, "star.fill")
    }

    func testUpdateCategory_PartialUpdate() throws {
        let category = categoryService.createCategory(
            name: "Original",
            colorHex: "#FF6B6B",
            iconName: "heart.fill"
        )

        // Only update name
        let updatedCategory = category.updated(name: "New Name")
        categoryService.updateCategory(updatedCategory)

        let fetchedCategory = categoryService.getCategory(byID: category.id)
        XCTAssertEqual(fetchedCategory?.name, "New Name")
        XCTAssertEqual(fetchedCategory?.colorHex, "#FF6B6B") // Unchanged
        XCTAssertEqual(fetchedCategory?.iconName, "heart.fill") // Unchanged
    }

    func testReorderCategories() throws {
        let cat1 = categoryService.createCategory(name: "First")
        let cat2 = categoryService.createCategory(name: "Second")
        let cat3 = categoryService.createCategory(name: "Third")

        // Initial order: First, Second, Third
        XCTAssertEqual(categoryService.categories[0].name, "First")
        XCTAssertEqual(categoryService.categories[1].name, "Second")
        XCTAssertEqual(categoryService.categories[2].name, "Third")

        // Reorder to: Third, First, Second
        categoryService.reorderCategories([cat3, cat1, cat2])

        XCTAssertEqual(categoryService.categories[0].name, "Third")
        XCTAssertEqual(categoryService.categories[1].name, "First")
        XCTAssertEqual(categoryService.categories[2].name, "Second")
    }

    // MARK: - Delete Tests

    func testDeleteCategory() throws {
        let category = categoryService.createCategory(name: "Category to Delete")
        XCTAssertEqual(categoryService.categories.count, 1)

        categoryService.deleteCategory(category)

        XCTAssertEqual(categoryService.categories.count, 0)
    }

    func testDeleteCategory_ClearsFromTasks() throws {
        let category = categoryService.createCategory(name: "Work")

        // Create tasks with this custom category
        let task1 = taskService.createTask(
            title: "Task 1",
            customCategoryID: category.id
        )
        let task2 = taskService.createTask(
            title: "Task 2",
            customCategoryID: category.id
        )

        // Verify tasks have the custom category
        taskService.fetchAllTasks()
        XCTAssertEqual(taskService.tasks.first { $0.id == task1.id }?.customCategoryID, category.id)
        XCTAssertEqual(taskService.tasks.first { $0.id == task2.id }?.customCategoryID, category.id)

        // Delete the category
        categoryService.deleteCategory(category)

        // Tasks should now have nil customCategoryID
        taskService.fetchAllTasks()
        XCTAssertNil(taskService.tasks.first { $0.id == task1.id }?.customCategoryID)
        XCTAssertNil(taskService.tasks.first { $0.id == task2.id }?.customCategoryID)
    }

    func testDeleteCategory_DoesNotAffectOtherCategoryTasks() throws {
        let category1 = categoryService.createCategory(name: "Category 1")
        let category2 = categoryService.createCategory(name: "Category 2")

        let task1 = taskService.createTask(title: "Task 1", customCategoryID: category1.id)
        let task2 = taskService.createTask(title: "Task 2", customCategoryID: category2.id)

        // Delete only category1
        categoryService.deleteCategory(category1)

        taskService.fetchAllTasks()
        XCTAssertNil(taskService.tasks.first { $0.id == task1.id }?.customCategoryID)
        XCTAssertEqual(taskService.tasks.first { $0.id == task2.id }?.customCategoryID, category2.id)
    }

    // MARK: - Validation Tests

    func testCategoryNameExists() throws {
        categoryService.createCategory(name: "Existing Category")

        XCTAssertTrue(categoryService.categoryNameExists("Existing Category"))
        XCTAssertFalse(categoryService.categoryNameExists("Non-Existent"))
    }

    func testCategoryNameExists_CaseInsensitive() throws {
        categoryService.createCategory(name: "Work Projects")

        XCTAssertTrue(categoryService.categoryNameExists("work projects"))
        XCTAssertTrue(categoryService.categoryNameExists("WORK PROJECTS"))
        XCTAssertTrue(categoryService.categoryNameExists("Work PROJECTS"))
    }

    func testCategoryNameExists_TrimsWhitespace() throws {
        categoryService.createCategory(name: "Work")

        XCTAssertTrue(categoryService.categoryNameExists("  Work  "))
        XCTAssertTrue(categoryService.categoryNameExists("\tWork\n"))
    }

    func testCategoryNameExists_ExcludingID() throws {
        let category = categoryService.createCategory(name: "Original Name")

        // Should return false when excluding the same category's ID (for edit validation)
        XCTAssertFalse(categoryService.categoryNameExists("Original Name", excludingID: category.id))

        // Should return true when checking without exclusion
        XCTAssertTrue(categoryService.categoryNameExists("Original Name"))
    }

    func testConflictsWithSystemCategory() throws {
        // Test all system category names
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Work"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Personal"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Health"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Finance"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Shopping"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Errands"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Learning"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Home"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Uncategorized"))
    }

    func testConflictsWithSystemCategory_CaseInsensitive() throws {
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("work"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("WORK"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("Work"))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("wOrK"))
    }

    func testConflictsWithSystemCategory_TrimsWhitespace() throws {
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("  Work  "))
        XCTAssertTrue(categoryService.conflictsWithSystemCategory("\tPersonal\n"))
    }

    func testConflictsWithSystemCategory_FalseForCustomNames() throws {
        XCTAssertFalse(categoryService.conflictsWithSystemCategory("My Custom Category"))
        XCTAssertFalse(categoryService.conflictsWithSystemCategory("Side Projects"))
        XCTAssertFalse(categoryService.conflictsWithSystemCategory("Hobbies"))
    }

    // MARK: - Helper Method Tests

    func testGetCategoryDisplay_CustomCategory() throws {
        let customCategory = categoryService.createCategory(
            name: "My Projects",
            colorHex: "#4DABF7",
            iconName: "folder.fill"
        )

        let display = categoryService.getCategoryDisplay(
            systemCategory: .uncategorized,
            customCategoryID: customCategory.id
        )

        XCTAssertEqual(display.name, "My Projects")
        XCTAssertEqual(display.iconName, "folder.fill")
    }

    func testGetCategoryDisplay_SystemCategory() throws {
        let display = categoryService.getCategoryDisplay(
            systemCategory: .work,
            customCategoryID: nil
        )

        XCTAssertEqual(display.name, "Work")
        XCTAssertEqual(display.iconName, TaskCategory.work.iconName)
    }

    func testGetCategoryDisplay_CustomTakesPrecedence() throws {
        let customCategory = categoryService.createCategory(
            name: "Custom Work",
            colorHex: "#FF6B6B",
            iconName: "star.fill"
        )

        // Even when system category is set, custom should take precedence
        let display = categoryService.getCategoryDisplay(
            systemCategory: .work,
            customCategoryID: customCategory.id
        )

        XCTAssertEqual(display.name, "Custom Work")
        XCTAssertEqual(display.iconName, "star.fill")
    }

    func testGetAllCategoriesForPicker() throws {
        categoryService.createCategory(name: "Custom 1")
        categoryService.createCategory(name: "Custom 2")

        let allCategories = categoryService.getAllCategoriesForPicker()

        // Should include all system categories plus custom ones
        let systemCount = TaskCategory.allCases.count
        XCTAssertEqual(allCategories.count, systemCount + 2)

        // Verify system categories come first
        let systemCategories = allCategories.filter { !$0.isCustom }
        XCTAssertEqual(systemCategories.count, systemCount)

        // Verify custom categories are included
        let customCategories = allCategories.filter { $0.isCustom }
        XCTAssertEqual(customCategories.count, 2)
        XCTAssertTrue(customCategories.contains { $0.name == "Custom 1" })
        XCTAssertTrue(customCategories.contains { $0.name == "Custom 2" })
    }

    // MARK: - Domain Model Tests

    func testCustomCategoryUpdated() throws {
        let original = CustomCategory(
            name: "Original",
            colorHex: "#808080",
            iconName: "tag.fill",
            order: 0
        )

        let updated = original.updated(
            name: "Updated",
            colorHex: "#FF6B6B",
            iconName: "star.fill"
        )

        // Original should be unchanged
        XCTAssertEqual(original.name, "Original")
        XCTAssertEqual(original.colorHex, "#808080")

        // Updated should have new values
        XCTAssertEqual(updated.name, "Updated")
        XCTAssertEqual(updated.colorHex, "#FF6B6B")
        XCTAssertEqual(updated.iconName, "star.fill")

        // ID and createdAt should be preserved
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.createdAt, original.createdAt)
    }

    func testCategorySelectionEnum() throws {
        let systemSelection = CategorySelection.system(.work)
        let customSelection = CategorySelection.custom(UUID())

        XCTAssertFalse(systemSelection.isUncategorized)
        XCTAssertFalse(customSelection.isUncategorized)

        let uncategorizedSelection = CategorySelection.system(.uncategorized)
        XCTAssertTrue(uncategorizedSelection.isUncategorized)

        XCTAssertEqual(systemSelection.systemCategory, .work)
        XCTAssertNil(customSelection.systemCategory)

        XCTAssertNotNil(customSelection.customCategoryID)
        XCTAssertNil(systemSelection.customCategoryID)
    }

    // MARK: - Performance Tests

    func testFetchPerformance() throws {
        // Create 50 categories
        for i in 0..<50 {
            categoryService.createCategory(name: "Category \(i)")
        }

        measure {
            categoryService.fetchAllCategories()
        }
    }

    func testGetByNamePerformance() throws {
        // Create 50 categories
        for i in 0..<50 {
            categoryService.createCategory(name: "Category \(i)")
        }

        measure {
            _ = categoryService.getCategory(byName: "Category 49")
        }
    }
}
