import Foundation

/// Domain model for quick capture notes
public struct QuickNote: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public let createdAt: Date
    public var isProcessed: Bool
    public var processedAt: Date?
    public var extractedTaskCount: Int

    public init(
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

    /// Preview text (first line or truncated)
    public var previewText: String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        if firstLine.count > 80 {
            return String(firstLine.prefix(80)) + "..."
        }
        return firstLine
    }

    /// Relative time since creation
    public var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return "Just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
