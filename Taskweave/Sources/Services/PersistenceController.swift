import CoreData
import Foundation

/// Core Data persistence controller managing the Core Data stack
final class PersistenceController: @unchecked Sendable {
    /// App Group identifier for sharing data with widgets
    private static let appGroupIdentifier = "group.com.taskweave.shared"

    /// Shared singleton instance
    static let shared = PersistenceController()

    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Create sample data for previews
        let inbox = TaskListEntity(context: context)
        inbox.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        inbox.name = "Inbox"
        inbox.colorHex = "#5A6C71"
        inbox.iconName = "tray"
        inbox.order = 0
        inbox.isDefault = true
        inbox.createdAt = Date()

        let workList = TaskListEntity(context: context)
        workList.id = UUID()
        workList.name = "Work"
        workList.colorHex = "#218A8D"
        workList.iconName = "briefcase"
        workList.order = 1
        workList.isDefault = false
        workList.createdAt = Date()

        // Create sample tasks
        let task1 = TaskEntity(context: context)
        task1.id = UUID()
        task1.title = "Review pull request"
        task1.notes = "Check the new authentication module"
        task1.dueDate = Date()
        task1.priorityRaw = Priority.high.rawValue
        task1.isCompleted = false
        task1.isArchived = false
        task1.createdAt = Date()
        task1.updatedAt = Date()
        task1.list = inbox

        let task2 = TaskEntity(context: context)
        task2.id = UUID()
        task2.title = "Update documentation"
        task2.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        task2.priorityRaw = Priority.medium.rawValue
        task2.isCompleted = false
        task2.isArchived = false
        task2.createdAt = Date()
        task2.updatedAt = Date()
        task2.list = workList

        let task3 = TaskEntity(context: context)
        task3.id = UUID()
        task3.title = "Fix login bug"
        task3.dueDate = Date()
        task3.priorityRaw = Priority.urgent.rawValue
        task3.isCompleted = true
        task3.isArchived = false
        task3.createdAt = Date()
        task3.updatedAt = Date()
        task3.list = workList

        do {
            try context.save()
        } catch {
            fatalError("Failed to save preview context: \(error)")
        }

        return controller
    }()

    /// The persistent container
    let container: NSPersistentContainer

    /// The main view context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Initialize the persistence controller
    /// - Parameter inMemory: If true, uses in-memory store (for testing/previews)
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Taskweave")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use shared App Groups container for widget access
            if let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
                .appendingPathComponent("Taskweave.sqlite") {
                let description = NSPersistentStoreDescription(url: storeURL)
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                container.persistentStoreDescriptions = [description]
            }
        }

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Failed to load Core Data store: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Enable CloudKit sync
        if !inMemory {
            setupCloudKitSync()
        }
    }

    /// Configure CloudKit synchronization
    private func setupCloudKitSync() {
        guard let description = container.persistentStoreDescriptions.first else { return }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }

    /// Save the view context if there are changes
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }

    /// Perform a background context operation
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    /// Create a new background context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Delete all data (for testing or reset)
    func deleteAllData() {
        let entities = container.managedObjectModel.entities

        for entity in entities {
            guard let entityName = entity.name else { continue }
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try container.viewContext.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }

        save()
    }

    /// Create default lists if they don't exist
    func createDefaultListsIfNeeded() {
        let context = viewContext
        let request: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")

        do {
            let defaultLists = try context.fetch(request)
            if defaultLists.isEmpty {
                // Create Inbox
                let inbox = TaskListEntity(context: context)
                inbox.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                inbox.name = "Inbox"
                inbox.colorHex = "#5A6C71"
                inbox.iconName = "tray"
                inbox.order = 0
                inbox.isDefault = true
                inbox.createdAt = Date()

                save()
            }
        } catch {
            print("Failed to check for default lists: \(error)")
        }
    }
}
