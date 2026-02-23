import Foundation

/// Domain model for quick capture notes
struct QuickNote: Identifiable, Equatable {
    let id: UUID
    var text: String
    let createdAt: Date
    var isProcessed: Bool
    var processedAt: Date?
    var extractedTaskCount: Int

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        isProcessed: Bool = false,
        processedAt: Date? = nil,
        extractedTaskCount: Int = 0
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isProcessed = isProcessed
        self.processedAt = processedAt
        self.extractedTaskCount = extractedTaskCount
    }

    /// Map from Core Data entity
    init(entity: QuickNoteEntity) {
        self.id = entity.id ?? UUID()
        self.text = entity.text ?? ""
        self.createdAt = entity.createdAt ?? Date()
        self.isProcessed = entity.isProcessed
        self.processedAt = entity.processedAt
        self.extractedTaskCount = Int(entity.extractedTaskCount)
    }

    /// Preview text (first line or truncated)
    var previewText: String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        if firstLine.count > 80 {
            return String(firstLine.prefix(80)) + "..."
        }
        return firstLine
    }

    /// Relative time since creation
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
