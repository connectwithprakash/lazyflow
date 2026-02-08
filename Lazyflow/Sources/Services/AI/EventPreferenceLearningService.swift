import Foundation

/// Service for learning user preferences about which calendar events to convert to tasks.
/// Tracks selection patterns in Plan Your Day and uses them to improve defaults over time.
@MainActor
final class EventPreferenceLearningService: ObservableObject {
    static let shared = EventPreferenceLearningService()

    // MARK: - Constants

    private let recordsKey = "eventSelectionRecords"
    private let preferencesKey = "eventTitlePreferences"
    private let maxRecords = 500
    private let expiryDays = 180

    // MARK: - Published State

    @Published private(set) var records: [EventSelectionRecord] = []
    @Published private(set) var preferences: [String: EventTitlePreference] = [:]

    // MARK: - Init

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadData()
        cleanupOldData()
    }

    // MARK: - Title Normalization

    /// Normalize an event title for consistent matching
    nonisolated static func normalizeTitle(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Recording

    /// Record the final selection state of all events when user confirms "Start My Day".
    /// Only call this on confirmation, not on dismiss/skip (to avoid ambiguous signals).
    func recordSelections(_ events: [PlanEventItem]) {
        for event in events {
            let normalized = Self.normalizeTitle(event.title)
            guard !normalized.isEmpty else { continue }

            let record = EventSelectionRecord(
                normalizedTitle: normalized,
                wasSelected: event.isSelected,
                isAllDay: event.isAllDay
            )
            records.append(record)

            // Update aggregated preference
            var pref = preferences[normalized] ?? EventTitlePreference(
                normalizedTitle: normalized,
                selectedCount: 0,
                skippedCount: 0,
                lastInteraction: Date()
            )

            if event.isSelected {
                pref.selectedCount += 1
            } else {
                pref.skippedCount += 1
            }
            pref.lastInteraction = Date()
            preferences[normalized] = pref
        }

        trimRecords()
        saveData()
    }

    // MARK: - Preference Lookups

    /// Get the learned preference for a given event title
    func preference(for title: String) -> EventTitlePreference? {
        let normalized = Self.normalizeTitle(title)
        return preferences[normalized]
    }

    /// Whether this event title is frequently skipped
    func isFrequentlySkipped(_ title: String) -> Bool {
        preference(for: title)?.isFrequentlySkipped ?? false
    }

    /// Whether this event title is frequently selected
    func isFrequentlySelected(_ title: String) -> Bool {
        preference(for: title)?.isFrequentlySelected ?? false
    }

    // MARK: - Data Management

    /// Clear all learning data
    func clearAllLearningData() {
        records = []
        preferences = [:]
        defaults.removeObject(forKey: recordsKey)
        defaults.removeObject(forKey: preferencesKey)
    }

    // MARK: - Persistence

    private func loadData() {
        if let data = defaults.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([EventSelectionRecord].self, from: data) {
            records = decoded
        }

        if let data = defaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode([String: EventTitlePreference].self, from: data) {
            preferences = decoded
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: recordsKey)
        }
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: preferencesKey)
        }
    }

    private func trimRecords() {
        if records.count > maxRecords {
            records = Array(records.suffix(maxRecords))
        }
    }

    private func cleanupOldData() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -expiryDays, to: Date()) else { return }

        let countBefore = records.count
        records = records.filter { $0.timestamp > cutoff }

        // Remove preferences that haven't been interacted with recently
        let staleKeys = preferences.filter { $0.value.lastInteraction <= cutoff }.map(\.key)
        for key in staleKeys {
            preferences.removeValue(forKey: key)
        }

        if records.count != countBefore || !staleKeys.isEmpty {
            saveData()
        }
    }
}
