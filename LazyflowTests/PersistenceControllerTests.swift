import CoreData
import XCTest

@testable import Lazyflow

final class PersistenceControllerTests: XCTestCase {

    var sut: PersistenceController!

    override func setUp() {
        super.setUp()
        sut = PersistenceController(inMemory: true, enableCloudKit: false)
    }

    override func tearDown() {
        sut.deleteAllDataEverywhere()
        sut = nil
        super.tearDown()
    }

    // MARK: - Stack Initialization

    func testInMemoryStore_Loads() {
        XCTAssertTrue(sut.isLoaded, "In-memory store should load successfully")
        XCTAssertNil(sut.initializationError, "No error expected for in-memory store")
    }

    func testInMemoryStore_ViewContextAvailable() {
        let context = sut.viewContext
        XCTAssertNotNil(context, "viewContext should be available after store loads")
    }

    func testInMemoryStore_MergePolicy() {
        let context = sut.viewContext
        XCTAssertTrue(
            (context.mergePolicy as AnyObject) === NSMergeByPropertyObjectTrumpMergePolicy,
            "viewContext should use NSMergeByPropertyObjectTrumpMergePolicy"
        )
    }

    func testInMemoryStore_AutoMergesChanges() {
        XCTAssertTrue(sut.viewContext.automaticallyMergesChangesFromParent)
    }

    // MARK: - Save and Fetch

    func testSave_PersistsTaskEntity() {
        let context = sut.viewContext

        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Test Task"
        task.createdAt = Date()
        task.updatedAt = Date()

        sut.save()

        // Verify it persists
        let fetchRequest = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        let results = try? context.fetch(fetchRequest)
        XCTAssertEqual(results?.count, 1)
        XCTAssertEqual(results?.first?.title, "Test Task")
    }

    func testSave_NoChanges_DoesNotError() {
        // save() with no changes should be a no-op
        sut.save()
        XCTAssertNil(sut.lastSaveError)
    }

    func testSave_ClearsSaveErrorOnSuccess() {
        let context = sut.viewContext

        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Valid Task"
        task.createdAt = Date()
        task.updatedAt = Date()

        sut.save()
        XCTAssertNil(sut.lastSaveError, "lastSaveError should be nil after successful save")
    }

    // MARK: - Entity Default Values (CloudKit Compliance)

    func testTaskEntity_DefaultValues() {
        let context = sut.viewContext
        let task = TaskEntity(context: context)

        // Non-optional attributes should have defaults
        XCTAssertFalse(task.isCompleted)
        XCTAssertFalse(task.isArchived)
        XCTAssertFalse(task.isSoftDeleted)
        XCTAssertEqual(task.priorityRaw, 1) // default priority
        XCTAssertEqual(task.categoryRaw, 0)
        XCTAssertEqual(task.statusRaw, 0)
        XCTAssertEqual(task.accumulatedDuration, 0)
    }

    func testTaskListEntity_DefaultValues() {
        let context = sut.viewContext
        let list = TaskListEntity(context: context)

        XCTAssertFalse(list.isDefault)
        XCTAssertEqual(list.colorHex, "#218A8D")
        XCTAssertEqual(list.order, 0)
    }

    func testCustomCategoryEntity_DefaultValues() {
        let context = sut.viewContext
        let category = CustomCategoryEntity(context: context)

        XCTAssertEqual(category.colorHex, "#808080")
        XCTAssertEqual(category.iconName, "tag.fill")
        XCTAssertEqual(category.order, 0)
    }

    func testQuickNoteEntity_DefaultValues() {
        let context = sut.viewContext
        let note = QuickNoteEntity(context: context)

        XCTAssertFalse(note.isProcessed)
        XCTAssertEqual(note.extractedTaskCount, 0)
    }

    func testRecurringRuleEntity_DefaultValues() {
        let context = sut.viewContext
        let rule = RecurringRuleEntity(context: context)

        XCTAssertEqual(rule.frequencyRaw, 0)
        XCTAssertEqual(rule.interval, 1)
    }

    // MARK: - Relationships

    func testTaskEntity_ListRelationship() {
        let context = sut.viewContext

        let list = TaskListEntity(context: context)
        list.id = UUID()
        list.name = "Test List"

        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Task in List"
        task.list = list

        sut.save()

        XCTAssertEqual(task.list, list)
        XCTAssertTrue(list.tasks?.contains(task) == true)
    }

    func testTaskEntity_SubtaskRelationship() {
        let context = sut.viewContext

        let parent = TaskEntity(context: context)
        parent.id = UUID()
        parent.title = "Parent Task"
        parent.createdAt = Date()
        parent.updatedAt = Date()

        let subtask = TaskEntity(context: context)
        subtask.id = UUID()
        subtask.title = "Subtask"
        subtask.parentTask = parent
        subtask.createdAt = Date()
        subtask.updatedAt = Date()

        sut.save()

        XCTAssertEqual(subtask.parentTask, parent)
        XCTAssertTrue(parent.subtasks?.contains(subtask) == true)
    }

    func testTaskEntity_CascadeDeleteSubtasks() {
        let context = sut.viewContext

        let parent = TaskEntity(context: context)
        parent.id = UUID()
        parent.title = "Parent"
        parent.createdAt = Date()
        parent.updatedAt = Date()

        let subtask = TaskEntity(context: context)
        subtask.id = UUID()
        subtask.title = "Subtask"
        subtask.parentTask = parent
        subtask.createdAt = Date()
        subtask.updatedAt = Date()

        sut.save()

        // Delete parent — subtask should be cascade deleted
        context.delete(parent)
        sut.save()

        let fetchRequest = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        let remaining = try? context.fetch(fetchRequest)
        XCTAssertEqual(remaining?.count, 0, "Subtask should be cascade deleted with parent")
    }

    // MARK: - Delete All Data

    func testDeleteAllDataEverywhere_ClearsAllEntities() {
        let context = sut.viewContext

        // Insert data across multiple entities
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "To Delete"
        task.createdAt = Date()
        task.updatedAt = Date()

        let list = TaskListEntity(context: context)
        list.id = UUID()
        list.name = "To Delete"

        let note = QuickNoteEntity(context: context)
        note.id = UUID()
        note.text = "To Delete"

        sut.save()

        // Delete all
        sut.deleteAllDataEverywhere()

        // Verify empty
        let taskFetch = NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
        let listFetch = NSFetchRequest<TaskListEntity>(entityName: "TaskListEntity")
        let noteFetch = NSFetchRequest<QuickNoteEntity>(entityName: "QuickNoteEntity")

        XCTAssertEqual(try? context.fetch(taskFetch).count, 0)
        XCTAssertEqual(try? context.fetch(listFetch).count, 0)
        XCTAssertEqual(try? context.fetch(noteFetch).count, 0)
    }

    // MARK: - Background Context

    func testNewBackgroundContext_HasMergePolicy() {
        let bgContext = sut.newBackgroundContext()
        XCTAssertTrue((bgContext.mergePolicy as AnyObject) === NSMergeByPropertyObjectTrumpMergePolicy)
    }

    // MARK: - Migration Options

    func testMigrationOptions_AreSet() {
        // Use inMemory:false so the init actually sets migration options on the description
        let controller = PersistenceController(inMemory: false, enableCloudKit: false)
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }

        XCTAssertEqual(
            description.options[NSMigratePersistentStoresAutomaticallyOption] as? NSNumber,
            true as NSNumber,
            "Auto migration should be enabled"
        )
        XCTAssertEqual(
            description.options[NSInferMappingModelAutomaticallyOption] as? NSNumber,
            true as NSNumber,
            "Infer mapping should be enabled"
        )
        controller.deleteAllDataEverywhere()
    }
}
