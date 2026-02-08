import Foundation

// MARK: - Event Selection Record

/// Records a single selection/skip interaction for a calendar event during Plan Your Day
struct EventSelectionRecord: Codable, Identifiable {
    let id: UUID
    let normalizedTitle: String
    let wasSelected: Bool
    let isAllDay: Bool
    let timestamp: Date

    init(
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
struct EventTitlePreference: Codable {
    let normalizedTitle: String
    var selectedCount: Int
    var skippedCount: Int
    var lastInteraction: Date

    var totalCount: Int {
        selectedCount + skippedCount
    }

    var skipRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(skippedCount) / Double(totalCount)
    }

    var selectionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(selectedCount) / Double(totalCount)
    }

    /// Requires at least 3 interactions to make a judgment
    var hasEnoughData: Bool {
        totalCount >= 3
    }

    /// Title is frequently skipped (>=80% skip rate with enough data)
    var isFrequentlySkipped: Bool {
        hasEnoughData && skipRate >= 0.8
    }

    /// Title is frequently selected (>=80% selection rate with enough data)
    var isFrequentlySelected: Bool {
        hasEnoughData && selectionRate >= 0.8
    }
}
