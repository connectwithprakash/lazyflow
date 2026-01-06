import CloudKit
import Combine
import CoreData
import Foundation

/// Core Data persistence controller managing the Core Data stack
final class PersistenceController: @unchecked Sendable {
    /// App Group identifier for sharing data with widgets
    private static let appGroupIdentifier = "group.com.lazyflow.shared"

    /// CloudKit container identifier
    private static let cloudKitContainerIdentifier = "iCloud.com.lazyflow.app"

    /// UserDefaults key for iCloud sync preference
    private static let iCloudSyncEnabledKey = "iCloudSyncEnabled"

    /// App launch time for timing measurements
    private static let appLaunchTime = CFAbsoluteTimeGetCurrent()

    /// Log with timestamp since app launch
    static func log(_ message: String) {
        let elapsed = CFAbsoluteTimeGetCurrent() - appLaunchTime
        print("[\(String(format: "%6.3f", elapsed))s] \(message)")
    }

    /// Check if user has enabled iCloud sync
    static var isICloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
    }

    /// Enable or disable iCloud sync (requires app restart to take effect)
    static func setICloudSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: iCloudSyncEnabledKey)
    }

    /// Shared singleton instance (lazy initialization with fast local-first loading)
    private static var _shared: PersistenceController?
    static var shared: PersistenceController {
        if let existing = _shared {
            return existing
        }
        // Use fast initialization: local-only unless user enabled iCloud, non-blocking
        let controller = PersistenceController(enableCloudKit: isICloudSyncEnabled, blocking: false)
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

    /// The persistent container (uses CloudKit container only when iCloud sync is enabled for faster startup)
    let container: NSPersistentContainer

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Whether this controller is using CloudKit sync
    private(set) var isCloudKitEnabled: Bool = false

    /// Error that occurred during Core Data initialization
    private(set) var initializationError: Error?

    /// The main view context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Initialize the persistence controller
    /// Used by widgets, intents, and direct `.shared` access
    /// - Parameters:
    ///   - inMemory: If true, uses in-memory store (for testing/previews)
    ///   - configureViewContext: If true, configures viewContext immediately (requires main thread)
    ///   - enableCloudKit: If true, enables CloudKit sync (default true, can disable for testing)
    ///   - blocking: If true, waits for store to load (default true for sync access, false for async)
    init(inMemory: Bool = false, configureViewContext: Bool = true, enableCloudKit: Bool = true, blocking: Bool = true) {
        let startTime = CFAbsoluteTimeGetCurrent()
        Self.log("⏱️ PersistenceController.init started")

        // Use CloudKit container only when iCloud sync is enabled - NSPersistentContainer is much faster
        let useCloudKit = enableCloudKit && FileManager.default.ubiquityIdentityToken != nil
        self.isCloudKitEnabled = useCloudKit

        if useCloudKit {
            container = NSPersistentCloudKitContainer(name: "Lazyflow")
            Self.log("📦 Using NSPersistentCloudKitContainer (iCloud enabled)")
        } else {
            container = NSPersistentContainer(name: "Lazyflow")
            Self.log("📦 Using NSPersistentContainer (fast local-only)")
        }

        Self.log("⏱️ Container created in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime))s")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use shared App Groups container for widget access
            // Fall back to default location if App Groups not available
            let storeURL: URL
            if let appGroupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
                .appendingPathComponent("Lazyflow.sqlite") {
                storeURL = appGroupURL
                print("Using App Groups container: \(appGroupURL.path)")
            } else {
                // Fallback to default Core Data location
                let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Lazyflow.sqlite")
                storeURL = defaultURL
                print("App Groups not available, using default location: \(defaultURL.path)")
            }

            let description = NSPersistentStoreDescription(url: storeURL)

            // Enable persistent history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            // Configure CloudKit sync only if using CloudKit container
            if useCloudKit {
                let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
                description.cloudKitContainerOptions = cloudKitOptions
            }

            container.persistentStoreDescriptions = [description]
        }

        // Load persistent stores
        let semaphore = blocking ? DispatchSemaphore(value: 0) : nil
        var loadError: Error?
        let storeLoadStartTime = CFAbsoluteTimeGetCurrent()

        container.loadPersistentStores { [weak self] storeDescription, error in
            let loadTime = CFAbsoluteTimeGetCurrent() - storeLoadStartTime
            if let error = error as NSError? {
                self?.initializationError = error
                loadError = error
                Self.log("❌ Failed to load store in \(String(format: "%.3f", loadTime))s: \(error.localizedDescription)")
            } else {
                Self.log("✅ Store loaded in \(String(format: "%.3f", loadTime))s")
                self?.isLoaded = true

                // For non-blocking init, set up CloudKit sync when store is ready
                if !blocking && !inMemory && (self?.isCloudKitEnabled ?? false) {
                    DispatchQueue.main.async {
                        self?.setupCloudKitSync()
                    }
                }
            }
            semaphore?.signal()
        }

        // Only block if requested (widgets/intents need sync access)
        if let semaphore = semaphore {
            let timeout = DispatchTime.now() + .seconds(5)
            if semaphore.wait(timeout: timeout) == .timedOut {
                print("Warning: Persistent store loading timed out after 5s")
            }
        }

        // Configure viewContext only if requested (must be on main thread) and no error
        if configureViewContext && loadError == nil {
            self.configureViewContext()
        }

        // For blocking init, set up CloudKit sync immediately
        if blocking && !inMemory && loadError == nil && isCloudKitEnabled {
            setupCloudKitSync()
        }

        if blocking {
            isLoaded = loadError == nil
        }
    }

    /// Configure the viewContext settings (must be called on main thread)
    func configureViewContext() {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Create persistence controller with fast local-first loading
    /// iCloud sync only enabled if user has opted in
    static func createAsync() async -> PersistenceController {
        let overallStart = CFAbsoluteTimeGetCurrent()
        let iCloudEnabled = isICloudSyncEnabled && FileManager.default.ubiquityIdentityToken != nil

        print("Starting Core Data initialization (iCloud: \(iCloudEnabled ? "enabled" : "disabled"))")

        let controller = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Only enable CloudKit if user has opted in
                let controller = PersistenceController(
                    configureViewContext: false,
                    enableCloudKit: iCloudEnabled,
                    blocking: false
                )
                continuation.resume(returning: controller)
            }
        }

        let initTime = CFAbsoluteTimeGetCurrent() - overallStart
        print("Container created in \(String(format: "%.2f", initTime))s")

        // Configure viewContext on main thread
        await MainActor.run {
            controller.configureViewContext()
            setShared(controller)
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - overallStart
        print("UI ready in \(String(format: "%.2f", totalTime))s (iCloud: \(iCloudEnabled ? "syncing" : "off"))")

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
