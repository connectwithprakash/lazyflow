import Foundation
import LazyflowCore

// MARK: - QuickNoteEntity to Domain Model

extension QuickNote {
    /// Map from Core Data entity
    init(entity: QuickNoteEntity) {
        self.init(
            id: entity.id ?? UUID(),
            text: entity.text ?? "",
            createdAt: entity.createdAt ?? Date(),
            isProcessed: entity.isProcessed,
            processedAt: entity.processedAt,
            extractedTaskCount: Int(entity.extractedTaskCount)
        )
    }
}
