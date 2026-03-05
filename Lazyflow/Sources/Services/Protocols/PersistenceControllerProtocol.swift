import CoreData
import Foundation
import LazyflowCore

/// Protocol defining the public API surface of PersistenceController consumed by services.
protocol PersistenceControllerProtocol: AnyObject {
    var viewContext: NSManagedObjectContext { get }
    var isLoaded: Bool { get }
    var canUndo: Bool { get }
    var canRedo: Bool { get }

    func save()
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void)
    func newBackgroundContext() -> NSManagedObjectContext

    func undo()
    func redo()
    func beginUndoGrouping(named name: String?)
    func endUndoGrouping()
    func removeAllUndoActions()

    func deleteAllDataEverywhere()
    func deleteLocalDataOnly()
    func createDefaultListsIfNeeded()
    func removeDuplicateInboxLists()
}
