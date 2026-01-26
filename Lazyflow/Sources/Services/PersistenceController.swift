import CloudKit
import Combine
import CoreData
import Foundation

// MARK: - Sync Status

/// Represents the current state of iCloud sync
enum SyncStatus: Equatable {
    case synced(lastSync: Date)
    case syncing
    case pendingChanges(count: Int)
    case offline
    case disabled
    case error(String)

    var displayText: String {
        switch self {
        case .synced(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .syncing:
            return "Syncing..."
        case .pendingChanges(let count):
            return "\(count) change\(count == 1 ? "" : "s") pending"
        case .offline:
            return "Offline"
        case .disabled:
            return "Disabled"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var icon: String {
        switch self {
        case .synced: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .pendingChanges: return "arrow.clockwise.icloud"
        case .offline: return "icloud.slash"
        case .disabled: return "icloud.slash"
        case .error: return "exclamationmark.icloud"
        }
    }

    var isHealthy: Bool {
        switch self {
        case .synced, .syncing, .pendingChanges: return true
        case .offline, .disabled, .error: return false
        }
    }
}

/// Data counts for storage
struct DataCounts: Equatable {
    let tasks: Int
    let lists: Int

    var isEmpty: Bool { tasks == 0 && lists == 0 }

    var description: String {
        if isEmpty { return "No data" }
        return "\(tasks) task\(tasks == 1 ? "" : "s"), \(lists) list\(lists == 1 ? "" : "s")"
    }
}

// MARK: - Persistence Controller

/// Core Data persistence controller managing the Core Data stack
final class PersistenceController: @unchecked Sendable {
    /// App Group identifier for sharing data with widgets
    private static let appGroupIdentifier = "group.com.lazyflow.shared"

    /// CloudKit container identifier
    private static let cloudKitContainerIdentifier = "iCloud.com.lazyflow.app"

    /// UserDefaults key for iCloud sync preference
    private static let iCloudSyncEnabledKey = "iCloudSyncEnabled"

    /// UserDefaults key for last sync date
    private static let lastSyncDateKey = "lastCloudKitSyncDate"

    // MARK: - iCloud Sync Preference

    /// Check if user has enabled iCloud sync
    /// Defaults to true if iCloud is available and never set
    static var isICloudSyncEnabled: Bool {
        // If preference has been explicitly set, use that value
        if UserDefaults.standard.object(forKey: iCloudSyncEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
        }
        // First launch: enable sync by default if iCloud is available
        let defaultEnabled = isICloudAvailable
        UserDefaults.standard.set(defaultEnabled, forKey: iCloudSyncEnabledKey)
        return defaultEnabled
    }

    /// Check if iCloud is available on this device
    static var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Enable or disable iCloud sync
    /// This now takes effect immediately without requiring a restart
    static func setICloudSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: iCloudSyncEnabledKey)
    }

    /// Reload the persistent store with updated CloudKit settings
    /// Call this after changing iCloud sync preference to apply immediately
    func reloadStoreWithCurrentSyncSettings() {
        guard isLoaded else {
            print("Warning: Store not loaded yet")
            return
        }

        guard let storeDescription = container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            print("Could not find store description")
            return
        }

        let coordinator = container.persistentStoreCoordinator

        // Remove current store
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                print("Failed to remove store: \(error)")
                return
            }
        }

        // Create new store description with updated CloudKit settings
        let newDescription = NSPersistentStoreDescription(url: storeURL)
        newDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        newDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Configure CloudKit based on current preference
        if Self.isICloudSyncEnabled && Self.isICloudAvailable {
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerIdentifier
            )
            newDescription.cloudKitContainerOptions = cloudKitOptions
            print("Reloading store with CloudKit sync ENABLED")
        } else {
            newDescription.cloudKitContainerOptions = nil
            print("Reloading store with CloudKit sync DISABLED")
        }

        // Re-add the store with new settings
        container.persistentStoreDescriptions = [newDescription]

        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?

        coordinator.addPersistentStore(with: newDescription) { _, error in
            loadError = error
            semaphore.signal()
        }

        // Wait for store to load
        _ = semaphore.wait(timeout: .now() + 10)

        if let error = loadError {
            print("Failed to reload store: \(error)")
        } else {
            // Reset and refresh context
            container.viewContext.reset()
            container.viewContext.refreshAllObjects()

            // Post notification for UI to refresh
            NotificationCenter.default.post(name: .cloudKitSyncDidComplete, object: nil)
            print("Store reloaded successfully")
        }
    }

    /// Get last sync date
    static var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date
    }

    /// Set last sync date
    private static func setLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastSyncDateKey)
    }

    /// Check if running in UI test mode
    private static var isUITesting: Bool {
        // Check both arguments and environment for maximum reliability
        ProcessInfo.processInfo.arguments.contains("UI_TESTING") ||
        ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
    }

    /// Shared singleton instance (lazy initialization)
    /// Uses in-memory store for UI tests to ensure test isolation
    private static var _shared: PersistenceController?
    static var shared: PersistenceController {
        if let existing = _shared {
            return existing
        }
        // Use in-memory store and disable CloudKit for UI tests
        // This ensures clean state and prevents background sync from blocking XCUITest
        let controller = PersistenceController(
            inMemory: isUITesting,
            enableCloudKit: !isUITesting
        )
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
        container = NSPersistentCloudKitContainer(name: "Lazyflow")

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

            // Configure CloudKit sync only if enabled and iCloud is available
            // Check both the parameter and user preference
            let shouldEnableCloudKit = enableCloudKit && Self.isICloudSyncEnabled && Self.isICloudAvailable
            if shouldEnableCloudKit {
                let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
                description.cloudKitContainerOptions = cloudKitOptions
                print("CloudKit sync enabled - user preference: enabled, iCloud: available")
            } else {
                print("CloudKit sync disabled - user preference: \(Self.isICloudSyncEnabled), iCloud available: \(Self.isICloudAvailable)")
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

        // Enable UndoManager for undo/redo support
        // This allows Core Data to automatically track all changes (inserts, updates, deletes)
        // and restore them including relationships (e.g., subtasks) when undo is called
        let undoManager = UndoManager()
        // Group undo operations by event (each user action becomes one undo operation)
        undoManager.groupsByEvent = true
        // Set a reasonable undo limit
        undoManager.levelsOfUndo = 10
        container.viewContext.undoManager = undoManager
    }

    // MARK: - Undo Manager

    /// The undo manager for the view context
    var undoManager: UndoManager? {
        container.viewContext.undoManager
    }

    /// Check if there are actions that can be undone
    var canUndo: Bool {
        container.viewContext.undoManager?.canUndo ?? false
    }

    /// Check if there are actions that can be redone
    var canRedo: Bool {
        container.viewContext.undoManager?.canRedo ?? false
    }

    /// Undo the last action
    func undo() {
        // Process any pending changes first to ensure they're registered
        container.viewContext.processPendingChanges()
        container.viewContext.undoManager?.undo()
        // Process changes from undo and save to persist
        container.viewContext.processPendingChanges()
        save()
    }

    /// Redo the last undone action
    func redo() {
        container.viewContext.processPendingChanges()
        container.viewContext.undoManager?.redo()
        container.viewContext.processPendingChanges()
        save()
    }

    /// Begin an undo grouping (for grouping multiple operations as one undo action)
    func beginUndoGrouping(named name: String? = nil) {
        container.viewContext.undoManager?.beginUndoGrouping()
        if let name = name {
            container.viewContext.undoManager?.setActionName(name)
        }
    }

    /// End an undo grouping
    func endUndoGrouping() {
        container.viewContext.undoManager?.endUndoGrouping()
    }

    /// Remove all undo actions (clear the undo stack)
    func removeAllUndoActions() {
        container.viewContext.undoManager?.removeAllActions()
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

            // Update last sync date
            Self.setLastSyncDate(Date())

            // Post notification for services to refresh their data
            NotificationCenter.default.post(name: .cloudKitSyncDidComplete, object: nil)
        }
    }

    // MARK: - Sync Status

    /// Get current sync status
    func getSyncStatus() -> SyncStatus {
        // Check if sync is disabled
        guard Self.isICloudSyncEnabled else {
            return .disabled
        }

        // Check if iCloud is available
        guard Self.isICloudAvailable else {
            return .offline
        }

        // Check for last sync date
        if let lastSync = Self.lastSyncDate {
            return .synced(lastSync: lastSync)
        }

        // If enabled but never synced, show as syncing
        return .syncing
    }

    // MARK: - Data Counts

    /// Get local data counts
    func getLocalDataCounts() -> DataCounts {
        guard isLoaded else { return DataCounts(tasks: 0, lists: 0) }

        let context = viewContext
        var taskCount = 0
        var listCount = 0

        do {
            let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            taskCount = try context.count(for: taskRequest)

            let listRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
            listCount = try context.count(for: listRequest)
        } catch {
            print("Failed to count entities: \(error)")
        }

        return DataCounts(tasks: taskCount, lists: listCount)
    }

    /// Result type for cloud data counts query
    enum CloudCountsResult {
        case success(DataCounts)
        case unavailable
        case error(String)
    }

    /// Get iCloud data counts (async - queries CloudKit directly)
    func getCloudDataCounts() async -> DataCounts? {
        let result = await getCloudDataCountsWithError()
        switch result {
        case .success(let counts): return counts
        case .unavailable, .error: return nil
        }
    }

    /// Get iCloud data counts with detailed error handling
    /// Uses the Core Data CloudKit zone to fetch records
    func getCloudDataCountsWithError() async -> CloudCountsResult {
        guard Self.isICloudAvailable else {
            return .unavailable
        }

        let cloudContainer = CKContainer(identifier: Self.cloudKitContainerIdentifier)
        let privateDatabase = cloudContainer.privateCloudDatabase

        // Core Data CloudKit uses this specific zone
        let coreDataZoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        do {
            // First verify the zone exists
            let zone = try await privateDatabase.recordZone(for: coreDataZoneID)
            print("Found Core Data CloudKit zone: \(zone.zoneID.zoneName)")

            // Fetch all records from the zone to count them
            // Using recordZoneChanges to get all records without needing queryable fields
            var taskCount = 0
            var listCount = 0

            // Create a fetch configuration for the zone
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil // Fetch all records

            // Use continuation to handle the callback-based API
            let counts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(tasks: Int, lists: Int), Error>) in
                var tasks = 0
                var lists = 0
                var operationError: Error?

                let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [coreDataZoneID], configurationsByRecordZoneID: [coreDataZoneID: config])

                operation.recordWasChangedBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        if record.recordType == "CD_TaskEntity" {
                            tasks += 1
                        } else if record.recordType == "CD_TaskListEntity" {
                            lists += 1
                        }
                    case .failure:
                        break
                    }
                }

                operation.recordZoneFetchResultBlock = { zoneID, result in
                    if case .failure(let error) = result {
                        operationError = error
                    }
                }

                operation.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: (tasks: tasks, lists: lists))
                    case .failure(let error):
                        continuation.resume(throwing: operationError ?? error)
                    }
                }

                privateDatabase.add(operation)
            }

            taskCount = counts.tasks
            listCount = counts.lists

            // Update last sync date on successful cloud query
            Self.setLastSyncDate(Date())

            return .success(DataCounts(tasks: taskCount, lists: listCount))
        } catch let ckError as CKError {
            let errorMessage: String
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                errorMessage = "No network connection"
            case .notAuthenticated:
                errorMessage = "Sign in to iCloud"
            case .quotaExceeded:
                errorMessage = "iCloud storage full"
            case .serverResponseLost:
                errorMessage = "Connection lost"
            case .zoneNotFound:
                // Zone doesn't exist yet - no data synced
                return .success(DataCounts(tasks: 0, lists: 0))
            default:
                errorMessage = "CloudKit error: \(ckError.localizedDescription)"
            }
            print("CloudKit error fetching counts: \(ckError)")
            return .error(errorMessage)
        } catch {
            print("Failed to fetch CloudKit counts: \(error)")
            return .error("Unable to check iCloud")
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

    // MARK: - Data Deletion

    /// Delete local data only (keeps iCloud data intact)
    /// Use when: User wants to clear local cache and re-sync from cloud
    /// Note: This removes the local SQLite store and lets CloudKit re-download data
    func deleteLocalDataOnly() {
        guard isLoaded else {
            print("Warning: Attempted to delete before store was loaded")
            return
        }

        guard let storeDescription = container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            print("Could not find store URL")
            return
        }

        // Get the persistent store coordinator
        let coordinator = container.persistentStoreCoordinator

        // Remove all persistent stores
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                print("Failed to remove store: \(error)")
            }
        }

        // Delete the SQLite files
        let sqliteFiles = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal"),
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"),
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        ]

        for fileURL in sqliteFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Also delete the ckAssets folder if it exists (CloudKit cached assets)
        let ckAssetsURL = storeURL.deletingLastPathComponent().appendingPathComponent("ckAssets")
        try? FileManager.default.removeItem(at: ckAssetsURL)

        // Re-add the store with the same description (preserves CloudKit options)
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?

        coordinator.addPersistentStore(with: storeDescription) { _, error in
            loadError = error
            semaphore.signal()
        }

        // Wait for store to load
        let result = semaphore.wait(timeout: .now() + 10)
        if result == .timedOut {
            print("Store reload timed out")
        } else if let error = loadError {
            print("Failed to re-add store: \(error)")
        } else {
            print("Local cache cleared - CloudKit will re-sync data")
        }

        // Reset and refresh view context
        container.viewContext.reset()
        container.viewContext.refreshAllObjects()
    }

    /// Delete all data everywhere (local + iCloud)
    /// Use when: User wants a complete fresh start
    /// Note: Only works properly when iCloud sync is enabled
    func deleteAllDataEverywhere() {
        guard isLoaded else {
            print("Warning: Attempted to delete before store was loaded")
            return
        }

        // If sync is enabled, deletions will propagate to CloudKit automatically
        let entities = container.managedObjectModel.entities

        for entity in entities {
            guard let entityName = entity.name else { continue }

            // Fetch and delete each object individually so CloudKit sync picks up deletions
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let objects = try container.viewContext.fetch(fetchRequest)
                for object in objects {
                    container.viewContext.delete(object)
                }
            } catch {
                print("Failed to fetch \(entityName) for deletion: \(error)")
            }
        }

        save()
        print("All data deleted (will sync to iCloud if enabled)")
    }

    /// Delete CloudKit data directly using CloudKit API
    /// Use when: Sync is disabled but user wants to clear iCloud data
    func deleteCloudKitData() async throws {
        let cloudContainer = CKContainer(identifier: Self.cloudKitContainerIdentifier)
        let privateDatabase = cloudContainer.privateCloudDatabase

        // Core Data CloudKit uses this specific zone
        let coreDataZoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        // First, fetch all record IDs from the zone
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = nil

        let recordIDs: [CKRecord.ID] = try await withCheckedThrowingContinuation { continuation in
            var ids: [CKRecord.ID] = []
            var operationError: Error?

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [coreDataZoneID],
                configurationsByRecordZoneID: [coreDataZoneID: config]
            )

            operation.recordWasChangedBlock = { recordID, result in
                if case .success = result {
                    ids.append(recordID)
                }
            }

            operation.recordZoneFetchResultBlock = { _, result in
                if case .failure(let error) = result {
                    operationError = error
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ids)
                case .failure(let error):
                    continuation.resume(throwing: operationError ?? error)
                }
            }

            privateDatabase.add(operation)
        }

        if recordIDs.isEmpty {
            print("No CloudKit records to delete")
            return
        }

        // Delete records in batches of 400 (CloudKit limit)
        let batchSize = 400
        for startIndex in stride(from: 0, to: recordIDs.count, by: batchSize) {
            let endIndex = min(startIndex + batchSize, recordIDs.count)
            let batch = Array(recordIDs[startIndex..<endIndex])

            let (_, deleteResults) = try await privateDatabase.modifyRecords(
                saving: [],
                deleting: batch
            )

            let failures = deleteResults.filter { _, result in
                if case .failure = result { return true }
                return false
            }

            if !failures.isEmpty {
                print("Some CloudKit records failed to delete: \(failures.count) failures")
            } else {
                print("Deleted \(batch.count) records from CloudKit")
            }
        }

        // Clear last sync date since we've wiped CloudKit
        UserDefaults.standard.removeObject(forKey: Self.lastSyncDateKey)
        print("CloudKit data deleted - total \(recordIDs.count) records")
    }

    /// Re-sync from iCloud (clear local, pull fresh from cloud)
    /// Use when: Local data is corrupted or out of sync
    func resyncFromCloud() {
        guard isLoaded else {
            print("Warning: Attempted to resync before store was loaded")
            return
        }

        // Delete local data without propagating to CloudKit
        deleteLocalDataOnly()

        // Trigger a fresh sync from CloudKit
        container.viewContext.refreshAllObjects()

        // Clear and reload will happen automatically via CloudKit sync
        print("Local data cleared, waiting for CloudKit resync...")
    }

    /// Legacy method - now calls deleteAllDataEverywhere for backwards compatibility
    @available(*, deprecated, renamed: "deleteAllDataEverywhere")
    func deleteAllData() {
        deleteAllDataEverywhere()
    }

    /// Create default lists if they don't exist
    func createDefaultListsIfNeeded() {
        guard isLoaded else {
            print("Warning: Attempted to create default lists before store was loaded")
            return
        }

        let context = viewContext
        let inboxID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        // Check for Inbox by its specific UUID to prevent race condition duplicates
        let request: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", inboxID as CVarArg)

        do {
            let existingInbox = try context.fetch(request)
            if existingInbox.isEmpty {
                // Create Inbox
                let inbox = TaskListEntity(context: context)
                inbox.id = inboxID
                inbox.name = "Inbox"
                inbox.colorHex = "#5A6C71"
                inbox.iconName = "tray"
                inbox.order = 0
                inbox.isDefault = true
                inbox.createdAt = Date()

                save()
            }

            // Clean up any duplicate Inbox lists (from previous race conditions)
            removeDuplicateInboxLists()
        } catch {
            print("Failed to check for default lists: \(error)")
        }
    }

    /// Remove duplicate Inbox lists, keeping only the one with the canonical UUID
    func removeDuplicateInboxLists() {
        let context = viewContext
        let inboxID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        // First, let's see all lists for debugging
        let allListsRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
        do {
            let allLists = try context.fetch(allListsRequest)
            print("[InboxCleanup] Total lists in database: \(allLists.count)")

            // Log first 20 lists to understand what they are
            for (index, list) in allLists.prefix(20).enumerated() {
                print("[InboxCleanup] List \(index): name='\(list.name ?? "nil")' isDefault=\(list.isDefault) id=\(list.id?.uuidString.prefix(8) ?? "nil")")
            }

            // Find all Inbox-like lists (by name or isDefault flag)
            let inboxLists = allLists.filter { entity in
                let name = entity.name?.lowercased() ?? ""
                return name.contains("inbox") || entity.isDefault
            }

            print("[InboxCleanup] Found \(inboxLists.count) Inbox-like lists")

            // Keep only the FIRST one, delete all others
            let duplicates = Array(inboxLists.dropFirst())

            print("[InboxCleanup] Found \(duplicates.count) duplicate Inbox list(s) to remove")

            if !duplicates.isEmpty {
                // Keep the first inbox as the canonical one
                let canonicalInbox = inboxLists.first!

                // Ensure it has the correct canonical ID
                if canonicalInbox.id != inboxID {
                    print("[InboxCleanup] Updating canonical Inbox ID from \(canonicalInbox.id?.uuidString ?? "nil") to \(inboxID)")
                    canonicalInbox.id = inboxID
                }

                for duplicate in duplicates {
                    print("[InboxCleanup] Removing duplicate: \(duplicate.name ?? "nil") (id: \(duplicate.id?.uuidString ?? "nil"))")
                    // Move tasks from duplicate to canonical inbox
                    if let tasks = duplicate.tasks as? Set<TaskEntity> {
                        print("[InboxCleanup]   Moving \(tasks.count) tasks to canonical Inbox")
                        for task in tasks {
                            task.list = canonicalInbox
                        }
                    }
                    context.delete(duplicate)
                }
                save()
                print("[InboxCleanup] Cleanup complete")
            }
        } catch {
            print("[InboxCleanup] Failed: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when CloudKit sync completes with remote changes
    static let cloudKitSyncDidComplete = Notification.Name("cloudKitSyncDidComplete")
}
