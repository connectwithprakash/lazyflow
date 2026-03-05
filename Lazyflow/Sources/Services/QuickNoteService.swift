import CoreData
import Foundation
import Combine
import Observation
import os
import LazyflowCore

/// Service responsible for Quick Note CRUD operations
@MainActor
@Observable
final class QuickNoteService {
    static let shared = QuickNoteService()

    private let persistenceController: PersistenceController

    private(set) var notes: [QuickNote] = []

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        setupObservers()
        fetchAllNotes()
    }

    // MARK: - Setup

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllNotes()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitSyncDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllNotes()
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch

    func fetchAllNotes() {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<QuickNoteEntity> = QuickNoteEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \QuickNoteEntity.createdAt, ascending: false)]

        do {
            let entities = try context.fetch(request)
            notes = entities.map { QuickNote(entity: $0) }
        } catch {
            Logger.notes.error("Failed to fetch quick notes: \(error)")
        }
    }

    /// Unprocessed notes sorted by newest first
    var unprocessedNotes: [QuickNote] {
        notes.filter { !$0.isProcessed }
    }

    /// Processed notes sorted by newest first
    var processedNotes: [QuickNote] {
        notes.filter { $0.isProcessed }
    }

    // MARK: - Create

    @discardableResult
    func createNote(text: String) -> QuickNote {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return QuickNote(text: "")
        }

        let context = persistenceController.viewContext
        let entity = QuickNoteEntity(context: context)
        entity.id = UUID()
        entity.text = trimmed
        entity.createdAt = Date()
        entity.isProcessed = false
        entity.extractedTaskCount = 0

        do {
            try context.save()
        } catch {
            Logger.notes.error("Failed to save quick note: \(error)")
        }

        let note = QuickNote(entity: entity)
        fetchAllNotes()
        return note
    }

    // MARK: - Update

    func updateNoteText(_ note: QuickNote, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let context = persistenceController.viewContext
        let request: NSFetchRequest<QuickNoteEntity> = QuickNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)

        guard let entity = try? context.fetch(request).first else { return }

        entity.text = trimmed

        do {
            try context.save()
        } catch {
            Logger.notes.error("Failed to update quick note: \(error)")
        }

        fetchAllNotes()
    }

    func markProcessed(_ note: QuickNote, taskCount: Int) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<QuickNoteEntity> = QuickNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)

        guard let entity = try? context.fetch(request).first else { return }

        entity.isProcessed = true
        entity.processedAt = Date()
        entity.extractedTaskCount = Int16(taskCount)

        do {
            try context.save()
        } catch {
            Logger.notes.error("Failed to mark note as processed: \(error)")
        }

        fetchAllNotes()
    }

    /// Unmark a processed note so it can be re-extracted
    func unmarkProcessed(_ note: QuickNote) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<QuickNoteEntity> = QuickNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)

        guard let entity = try? context.fetch(request).first else { return }

        entity.isProcessed = false
        entity.processedAt = nil
        entity.extractedTaskCount = 0

        do {
            try context.save()
        } catch {
            Logger.notes.error("Failed to unmark note: \(error)")
        }

        fetchAllNotes()
    }

    // MARK: - Delete

    func deleteNote(_ note: QuickNote) {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<QuickNoteEntity> = QuickNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)

        guard let entity = try? context.fetch(request).first else { return }

        context.delete(entity)

        do {
            try context.save()
        } catch {
            Logger.notes.error("Failed to delete quick note: \(error)")
        }

        fetchAllNotes()
    }
}
