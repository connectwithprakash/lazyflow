import CoreData
import Foundation
import LazyflowCore
@testable import Lazyflow

/// Mock PersistenceController wrapping an in-memory Core Data stack for testing.
final class MockPersistenceController: PersistenceControllerProtocol {
    private let controller: PersistenceController

    var viewContext: NSManagedObjectContext { controller.viewContext }
    var isLoaded: Bool { controller.isLoaded }
    var canUndo: Bool { controller.canUndo }
    var canRedo: Bool { controller.canRedo }

    init() {
        controller = PersistenceController(inMemory: true)
    }

    func save() { controller.save() }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        controller.performBackgroundTask(block)
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        controller.newBackgroundContext()
    }

    func undo() { controller.undo() }
    func redo() { controller.redo() }
    func beginUndoGrouping(named name: String?) { controller.beginUndoGrouping(named: name) }
    func endUndoGrouping() { controller.endUndoGrouping() }
    func removeAllUndoActions() { controller.removeAllUndoActions() }

    func deleteAllDataEverywhere() { controller.deleteAllDataEverywhere() }
    func deleteLocalDataOnly() { controller.deleteLocalDataOnly() }
    func createDefaultListsIfNeeded() { controller.createDefaultListsIfNeeded() }
    func removeDuplicateInboxLists() { controller.removeDuplicateInboxLists() }
}
