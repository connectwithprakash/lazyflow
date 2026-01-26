import CoreData
import Foundation
import Combine
import SwiftUI

/// Service responsible for all CustomCategory-related CRUD operations
final class CategoryService: ObservableObject {
    static let shared = CategoryService()

    private let persistenceController: PersistenceController

    @Published private(set) var categories: [CustomCategory] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private var cancellables = Set<AnyCancellable>()

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        setupObservers()
        fetchAllCategories()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Listen for local Core Data saves
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllCategories()
            }
            .store(in: &cancellables)

        // Listen for CloudKit sync completion (remote changes)
        NotificationCenter.default.publisher(for: .cloudKitSyncDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllCategories()
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Operations

    /// Fetch all custom categories sorted by order
    func fetchAllCategories() {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CustomCategoryEntity> = CustomCategoryEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CustomCategoryEntity.order, ascending: true),
            NSSortDescriptor(keyPath: \CustomCategoryEntity.createdAt, ascending: true)
        ]

        do {
            let entities = try context.fetch(request)
            categories = entities.map { $0.toDomainModel() }
        } catch {
            self.error = error
            print("Failed to fetch custom categories: \(error)")
        }
    }

    /// Get a specific category by ID
    func getCategory(byID id: UUID) -> CustomCategory? {
        return categories.first { $0.id == id }
    }

    /// Get category by name (case-insensitive)
    func getCategory(byName name: String) -> CustomCategory? {
        return categories.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Create Operations

    /// Create a new custom category
    @discardableResult
    func createCategory(
        name: String,
        colorHex: String = "#808080",
        iconName: String = "tag.fill"
    ) -> CustomCategory {
        let context = persistenceController.viewContext

        // Get the next order value
        let maxOrder = categories.map { $0.order }.max() ?? 0

        let entity = CustomCategoryEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.colorHex = colorHex
        entity.iconName = iconName
        entity.order = maxOrder + 1
        entity.createdAt = Date()

        persistenceController.save()

        let category = entity.toDomainModel()
        fetchAllCategories()
        return category
    }

    // MARK: - Update Operations

    /// Update an existing category
    func updateCategory(_ category: CustomCategory) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CustomCategoryEntity> = CustomCategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }

            entity.name = category.name
            entity.colorHex = category.colorHex
            entity.iconName = category.iconName
            entity.order = category.order

            persistenceController.save()
            fetchAllCategories()
        } catch {
            self.error = error
            print("Failed to update category: \(error)")
        }
    }

    /// Reorder categories
    func reorderCategories(_ categories: [CustomCategory]) {
        let context = persistenceController.viewContext

        for (index, category) in categories.enumerated() {
            let request: NSFetchRequest<CustomCategoryEntity> = CustomCategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)

            do {
                guard let entity = try context.fetch(request).first else { continue }
                entity.order = Int32(index)
            } catch {
                print("Failed to reorder category: \(error)")
            }
        }

        persistenceController.save()
        fetchAllCategories()
    }

    // MARK: - Delete Operations

    /// Delete a category
    func deleteCategory(_ category: CustomCategory) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CustomCategoryEntity> = CustomCategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                // Before deleting, clear customCategoryID from all tasks using this category
                clearCategoryFromTasks(categoryID: category.id)

                context.delete(entity)
                persistenceController.save()
                fetchAllCategories()
            }
        } catch {
            self.error = error
            print("Failed to delete category: \(error)")
        }
    }

    /// Clear custom category reference from all tasks using this category
    private func clearCategoryFromTasks(categoryID: UUID) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "customCategoryID == %@", categoryID as CVarArg)

        do {
            let tasks = try context.fetch(request)
            for task in tasks {
                task.customCategoryID = nil
            }
        } catch {
            print("Failed to clear category from tasks: \(error)")
        }
    }

    // MARK: - Validation

    /// Check if a category name already exists
    func categoryNameExists(_ name: String, excludingID: UUID? = nil) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return categories.contains { category in
            if let excludingID = excludingID, category.id == excludingID {
                return false
            }
            return category.name.lowercased() == normalizedName
        }
    }

    /// Check if a name conflicts with system category names
    func conflictsWithSystemCategory(_ name: String) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return TaskCategory.allCases.contains { $0.displayName.lowercased() == normalizedName }
    }
}

// MARK: - Category Helper Methods

extension CategoryService {
    /// Get display info for a task's category (either system or custom)
    func getCategoryDisplay(systemCategory: TaskCategory, customCategoryID: UUID?) -> (name: String, color: Color, iconName: String) {
        // Custom category takes precedence
        if let customID = customCategoryID,
           let custom = getCategory(byID: customID) {
            return (custom.displayName, custom.color, custom.iconName)
        }

        // Fall back to system category
        return (systemCategory.displayName, systemCategory.color, systemCategory.iconName)
    }

    /// Get all available categories (system + custom) for picker
    func getAllCategoriesForPicker() -> [(id: String, name: String, color: Color, iconName: String, isCustom: Bool)] {
        var result: [(id: String, name: String, color: Color, iconName: String, isCustom: Bool)] = []

        // Add system categories
        for category in TaskCategory.allCases {
            result.append((
                id: "system-\(category.rawValue)",
                name: category.displayName,
                color: category.color,
                iconName: category.iconName,
                isCustom: false
            ))
        }

        // Add custom categories
        for category in categories {
            result.append((
                id: "custom-\(category.id.uuidString)",
                name: category.displayName,
                color: category.color,
                iconName: category.iconName,
                isCustom: true
            ))
        }

        return result
    }
}
