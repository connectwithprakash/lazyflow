import CloudKit
import Combine
import CoreData
import Foundation

/// Core Data persistence controller managing the Core Data stack
final class PersistenceController: @unchecked Sendable {
    /// App Group identifier for sharing data with widgets
    private static let appGroupIdentifier = "group.com.taskweave.shared"

    /// CloudKit container identifier
    private static let cloudKitContainerIdentifier = "iCloud.com.taskweave.app"

    /// Shared singleton instance (lazy initialization)
    private static var _shared: PersistenceController?
    static var shared: PersistenceController {
        if let existing = _shared {
            return existing
        }
        let controller = PersistenceController()
        _shared = controller
        return controller
    }

    /// Whether Core Data has finished loading
    private(set) var isLoaded = false

    /// Set the shared instance (used for async initialization)
    static func setShared(_ controller: PersistenceController) {
        _shared = controller
    }

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

    /// The persistent container with CloudKit sync support
    let container: NSPersistentCloudKitContainer

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Error that occurred during Core Data initialization
    private(set) var initializationError: Error?

    /// The main view context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Initialize the persistence controller (synchronous)
    /// Used by widgets, intents, and direct `.shared` access
    /// - Parameters:
    ///   - inMemory: If true, uses in-memory store (for testing/previews)
    ///   - configureViewContext: If true, configures viewContext immediately (requires main thread)
    ///   - enableCloudKit: If true, enables CloudKit sync (default true, can disable for testing)
    init(inMemory: Bool = false, configureViewContext: Bool = true, enableCloudKit: Bool = true) {
        container = NSPersistentCloudKitContainer(name: "Taskweave")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use shared App Groups container for widget access
            // Fall back to default location if App Groups not available
            let storeURL: URL
            if let appGroupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
                .appendingPathComponent("Taskweave.sqlite") {
                storeURL = appGroupURL
                print("Using App Groups container: \(appGroupURL.path)")
            } else {
                // Fallback to default Core Data location
                let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Taskweave.sqlite")
                storeURL = defaultURL
                print("App Groups not available, using default location: \(defaultURL.path)")
            }

            let description = NSPersistentStoreDescription(url: storeURL)

            // Enable persistent history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            // Configure CloudKit sync only if enabled and iCloud is available
            if enableCloudKit && FileManager.default.ubiquityIdentityToken != nil {
                let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
                description.cloudKitContainerOptions = cloudKitOptions
                print("CloudKit sync enabled")
            } else {
                print("CloudKit sync disabled - iCloud not available or disabled")
            }

            container.persistentStoreDescriptions = [description]
        }

        // Use semaphore to wait for store to load (sync initialization)
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?

        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                self?.initializationError = error
                loadError = error
                print("Critical: Failed to load Core Data store: \(error), \(error.userInfo)")
            } else {
                print("Successfully loaded persistent store: \(storeDescription.url?.path ?? "unknown")")
            }
            semaphore.signal()
        }

        // Wait for store to load (with timeout)
        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("Warning: Persistent store loading timed out")
        }

        // Configure viewContext only if requested (must be on main thread) and no error
        if configureViewContext && loadError == nil {
            self.configureViewContext()
        }

        if !inMemory && loadError == nil {
            setupCloudKitSync()
        }

        isLoaded = loadError == nil
    }

    /// Configure the viewContext settings (must be called on main thread)
    func configureViewContext() {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Create and initialize persistence controller asynchronously
    /// Used by main app to show loading UI while Core Data initializes
    static func createAsync() async -> PersistenceController {
        // Create container on background thread
        let controller = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let controller = PersistenceController(configureViewContext: false)
                continuation.resume(returning: controller)
            }
        }

        // Configure viewContext on main thread (required by Core Data)
        await MainActor.run {
            controller.configureViewContext()
            setShared(controller)
        }

        return controller
    }

    /// Configure CloudKit synchronization and observers
    private func setupCloudKitSync() {
        // Listen for remote change notifications from CloudKit
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRemoteStoreChange()
            }
            .store(in: &cancellables)
    }

    /// Handle remote changes from CloudKit sync
    private func handleRemoteStoreChange() {
        // Refresh the view context to pick up remote changes
        container.viewContext.perform { [weak self] in
            guard let self = self else { return }

            // Force refresh all objects to pick up remote changes
            self.container.viewContext.refreshAllObjects()

            // Post notification for services to refresh their data
            NotificationCenter.default.post(name: .cloudKitSyncDidComplete, object: nil)
        }
    }

    /// Save the view context if there are changes
    func save() {
        guard isLoaded else {
            print("Warning: Attempted to save before store was loaded")
            return
        }

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
        guard isLoaded else {
            print("Warning: Attempted to create default lists before store was loaded")
            return
        }

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

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when CloudKit sync completes with remote changes
    static let cloudKitSyncDidComplete = Notification.Name("cloudKitSyncDidComplete")
}
