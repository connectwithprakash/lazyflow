import CoreData
import XCTest
@testable import Lazyflow

final class CloudKitSyncTests: XCTestCase {

    var sut: PersistenceController!

    override func setUp() {
        super.setUp()
        sut = PersistenceController(inMemory: true, enableCloudKit: false)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Merge Policy

    func testViewContext_UsesMergeByPropertyObjectTrump() {
        let policy = sut.container.viewContext.mergePolicy as AnyObject
        XCTAssertTrue(
            policy === NSMergeByPropertyObjectTrumpMergePolicy,
            "View context should use object-trump merge policy for CloudKit conflict resolution"
        )
    }

    func testBackgroundContext_UsesMergeByPropertyObjectTrump() {
        let bgContext = sut.newBackgroundContext()
        let policy = bgContext.mergePolicy as AnyObject
        XCTAssertTrue(
            policy === NSMergeByPropertyObjectTrumpMergePolicy,
            "Background context should use object-trump merge policy"
        )
    }

    // MARK: - Automatic Merge

    func testViewContext_AutomaticallyMergesChanges() {
        XCTAssertTrue(
            sut.container.viewContext.automaticallyMergesChangesFromParent,
            "View context should automatically merge changes from parent"
        )
    }

    // MARK: - Persistent History Tracking

    func testPersistentStoreDescription_HasHistoryTracking() {
        // In-memory stores won't have this, but non-in-memory stores should
        let controller = PersistenceController(inMemory: false, enableCloudKit: false)
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }

        let historyTracking = description.options[NSPersistentHistoryTrackingKey] as? NSNumber
        XCTAssertEqual(historyTracking, true, "Persistent history tracking should be enabled")
    }

    func testPersistentStoreDescription_HasRemoteChangeNotification() {
        let controller = PersistenceController(inMemory: false, enableCloudKit: false)
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }

        let remoteChange = description.options[NSPersistentStoreRemoteChangeNotificationPostOptionKey] as? NSNumber
        XCTAssertEqual(remoteChange, true, "Remote change notification should be enabled")
    }

    // MARK: - Sync Status

    func testSyncStatus_DisabledWhenPreferenceOff() {
        // Save current state
        let originalValue = UserDefaults.standard.object(forKey: "iCloudSyncEnabled")

        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
        let status = sut.getSyncStatus()
        XCTAssertEqual(status, .disabled)

        // Restore
        if let original = originalValue {
            UserDefaults.standard.set(original, forKey: "iCloudSyncEnabled")
        } else {
            UserDefaults.standard.removeObject(forKey: "iCloudSyncEnabled")
        }
    }

    func testSyncStatus_DisplayText() {
        XCTAssertEqual(SyncStatus.disabled.displayText, "Disabled")
        XCTAssertEqual(SyncStatus.syncing.displayText, "Syncing...")
        XCTAssertEqual(SyncStatus.offline.displayText, "Offline")
        XCTAssertEqual(SyncStatus.error("Network error").displayText, "Error: Network error")
    }

    func testSyncStatus_Icon() {
        XCTAssertEqual(SyncStatus.disabled.icon, "icloud.slash")
        XCTAssertEqual(SyncStatus.syncing.icon, "arrow.triangle.2.circlepath.icloud")
        XCTAssertEqual(SyncStatus.offline.icon, "icloud.slash")
        XCTAssertEqual(SyncStatus.error("fail").icon, "exclamationmark.icloud")
    }

    func testSyncStatus_IsHealthy() {
        XCTAssertTrue(SyncStatus.syncing.isHealthy)
        XCTAssertTrue(SyncStatus.synced(lastSync: Date()).isHealthy)
        XCTAssertTrue(SyncStatus.pendingChanges(count: 3).isHealthy)
        XCTAssertFalse(SyncStatus.offline.isHealthy)
        XCTAssertFalse(SyncStatus.disabled.isHealthy)
        XCTAssertFalse(SyncStatus.error("fail").isHealthy)
    }

    // MARK: - Sync Error

    func testLastSyncError_InitiallyNil() {
        XCTAssertNil(sut.lastSyncError)
    }

    // MARK: - Concurrent Write Conflict Resolution

    func testConcurrentWrites_MergedByObjectTrumpPolicy() throws {
        let context1 = sut.container.viewContext
        let context2 = sut.newBackgroundContext()

        // Create a task in context1
        let task = TaskEntity(context: context1)
        task.id = UUID()
        task.title = "Original"
        task.isCompleted = false
        task.isArchived = false
        task.createdAt = Date()
        task.updatedAt = Date()
        try context1.save()

        let taskID = task.objectID

        // Simulate concurrent writes: context2 modifies, context1 modifies
        let expectation = XCTestExpectation(description: "Background save")

        context2.perform {
            let bgTask = context2.object(with: taskID) as! TaskEntity
            bgTask.title = "Background update"
            bgTask.updatedAt = Date()
            try? context2.save()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)

        // Modify in context1 (object-trump: this should win)
        task.title = "Main context update"
        task.updatedAt = Date()
        try context1.save()

        // Refresh to pick up merge
        context1.refreshAllObjects()
        let finalTask = context1.object(with: taskID) as! TaskEntity
        XCTAssertEqual(finalTask.title, "Main context update", "Object-trump merge should keep main context changes")
    }

    // MARK: - Data Counts

    func testDataCounts_EmptyStore() {
        let counts = sut.getLocalDataCounts()
        XCTAssertTrue(counts.isEmpty)
        XCTAssertEqual(counts.description, "No data")
    }

    func testDataCounts_WithData() throws {
        let context = sut.container.viewContext
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Test"
        task.isCompleted = false
        task.isArchived = false
        task.createdAt = Date()
        task.updatedAt = Date()
        try context.save()

        let counts = sut.getLocalDataCounts()
        XCTAssertEqual(counts.tasks, 1)
        XCTAssertFalse(counts.isEmpty)
    }
}
