import Foundation

// MARK: - Event Selection Record

/// Records a single selection/skip interaction for a calendar event during Plan Your Day
public struct EventSelectionRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let normalizedTitle: String
    public let wasSelected: Bool
    public let isAllDay: Bool
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        normalizedTitle: String,
        wasSelected: Bool,
        isAllDay: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.normalizedTitle = normalizedTitle
        self.wasSelected = wasSelected
        self.isAllDay = isAllDay
        self.timestamp = timestamp
    }
}

// MARK: - Event Title Preference

/// Aggregated preference learned from multiple selection records for a specific event title
public struct EventTitlePreference: Codable, Sendable {
    public let normalizedTitle: String
    public var selectedCount: Int
    public var skippedCount: Int
    public var lastInteraction: Date

    public init(normalizedTitle: String, selectedCount: Int, skippedCount: Int, lastInteraction: Date) {
        self.normalizedTitle = normalizedTitle
        self.selectedCount = selectedCount
        self.skippedCount = skippedCount
        self.lastInteraction = lastInteraction
    }

    public var totalCount: Int {
        selectedCount + skippedCount
    }

    public var skipRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(skippedCount) / Double(totalCount)
    }

    public var selectionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(selectedCount) / Double(totalCount)
    }

    /// Requires at least 3 interactions to make a judgment
    public var hasEnoughData: Bool {
        totalCount >= 3
    }

    /// Title is frequently skipped (>=80% skip rate with enough data)
    public var isFrequentlySkipped: Bool {
        hasEnoughData && skipRate >= 0.8
    }

    /// Title is frequently selected (>=80% selection rate with enough data)
    public var isFrequentlySelected: Bool {
        hasEnoughData && selectionRate >= 0.8
    }
}
