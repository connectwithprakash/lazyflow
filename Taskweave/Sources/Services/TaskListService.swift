import CoreData
import Foundation
import Combine

/// Service responsible for all TaskList-related CRUD operations
final class TaskListService: ObservableObject {
    private let persistenceController: PersistenceController

    @Published private(set) var lists: [TaskList] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private var cancellables = Set<AnyCancellable>()

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        setupObservers()
        createDefaultListsIfNeeded()
        fetchAllLists()
    }

    // MARK: - Setup

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllLists()
            }
            .store(in: &cancellables)
    }

    private func createDefaultListsIfNeeded() {
        persistenceController.createDefaultListsIfNeeded()
    }

    // MARK: - Fetch Operations

    /// Fetch all lists sorted by order
    func fetchAllLists() {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskListEntity.order, ascending: true),
            NSSortDescriptor(keyPath: \TaskListEntity.createdAt, ascending: true)
        ]

        do {
            let entities = try context.fetch(request)
            lists = entities.map { $0.toDomainModel() }
        } catch {
            self.error = error
            print("Failed to fetch lists: \(error)")
        }
    }

    /// Get a specific list by ID
    func getList(byID id: UUID) -> TaskList? {
        return lists.first { $0.id == id }
    }

    /// Get the default inbox list
    func getInboxList() -> TaskList? {
        return lists.first { $0.isDefault }
    }

    /// Get task count for a specific list
    func getTaskCount(forListID listID: UUID) -> Int {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@ AND isArchived == NO AND isCompleted == NO", listID as CVarArg)

        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count tasks: \(error)")
            return 0
        }
    }

    // MARK: - Create Operations

    /// Create a new list
    @discardableResult
    func createList(
        name: String,
        colorHex: String = "#218A8D",
        iconName: String? = nil
    ) -> TaskList {
        let context = persistenceController.viewContext

        // Get the next order value
        let maxOrder = lists.map { $0.order }.max() ?? 0

        let entity = TaskListEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.colorHex = colorHex
        entity.iconName = iconName
        entity.order = maxOrder + 1
        entity.isDefault = false
        entity.createdAt = Date()

        persistenceController.save()

        let list = entity.toDomainModel()
        fetchAllLists()
        return list
    }

    // MARK: - Update Operations

    /// Update an existing list
    func updateList(_ list: TaskList) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }

            entity.name = list.name
            entity.colorHex = list.colorHex
            entity.iconName = list.iconName
            entity.order = list.order

            persistenceController.save()
            fetchAllLists()
        } catch {
            self.error = error
            print("Failed to update list: \(error)")
        }
    }

    /// Reorder lists
    func reorderLists(_ lists: [TaskList]) {
        let context = persistenceController.viewContext

        for (index, list) in lists.enumerated() {
            let request: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

            do {
                guard let entity = try context.fetch(request).first else { continue }
                entity.order = Int32(index)
            } catch {
                print("Failed to reorder list: \(error)")
            }
        }

        persistenceController.save()
        fetchAllLists()
    }

    // MARK: - Delete Operations

    /// Delete a list (moves tasks to inbox)
    func deleteList(_ list: TaskList) {
        // Can't delete default list
        guard !list.isDefault else { return }

        let context = persistenceController.viewContext

        // First, move all tasks to inbox
        let inboxID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "list.id == %@", list.id as CVarArg)

        let inboxRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
        inboxRequest.predicate = NSPredicate(format: "id == %@", inboxID as CVarArg)

        do {
            let tasks = try context.fetch(taskRequest)
            let inbox = try context.fetch(inboxRequest).first

            for task in tasks {
                task.list = inbox
            }

            // Now delete the list
            let listRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
            listRequest.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

            if let entity = try context.fetch(listRequest).first {
                context.delete(entity)
            }

            persistenceController.save()
            fetchAllLists()
        } catch {
            self.error = error
            print("Failed to delete list: \(error)")
        }
    }
}

// MARK: - TaskListEntity to Domain Model

extension TaskListEntity {
    func toDomainModel() -> TaskList {
        TaskList(
            id: id ?? UUID(),
            name: name ?? "",
            colorHex: colorHex ?? "#218A8D",
            iconName: iconName,
            order: order,
            isDefault: isDefault,
            createdAt: createdAt ?? Date()
        )
    }
}
