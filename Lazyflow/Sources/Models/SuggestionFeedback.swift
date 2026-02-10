import Foundation

// MARK: - Feedback Action

enum FeedbackAction: String, Codable {
    case startedImmediately
    case viewedDetails
    case snoozed1Hour
    case snoozedEvening
    case snoozedTomorrow
    case skippedNotRelevant
    case skippedWrongTime
    case skippedNeedsFocus

    /// Score adjustment delta for this action
    var adjustmentDelta: Double {
        switch self {
        case .startedImmediately: return 5
        case .viewedDetails: return 1
        case .snoozed1Hour: return -2
        case .snoozedEvening, .snoozedTomorrow: return -3
        case .skippedNotRelevant, .skippedWrongTime, .skippedNeedsFocus: return -5
        }
    }

    /// Whether this action triggers a snooze suppression
    var isSnooze: Bool {
        switch self {
        case .snoozed1Hour, .snoozedEvening, .snoozedTomorrow: return true
        default: return false
        }
    }

    /// Snooze duration for snooze actions
    func snoozeUntilDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .snoozed1Hour:
            return now.addingTimeInterval(3600)
        case .snoozedEvening:
            // 6 PM today, or tomorrow if already past 6 PM
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 18
            components.minute = 0
            if let evening = calendar.date(from: components), evening > now {
                return evening
            }
            // Already past 6 PM — snooze to tomorrow 6 PM
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                tomorrowComponents.hour = 18
                tomorrowComponents.minute = 0
                return calendar.date(from: tomorrowComponents)
            }
            return now.addingTimeInterval(3600)
        case .snoozedTomorrow:
            // 9 AM tomorrow
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = 9
                components.minute = 0
                return calendar.date(from: components)
            }
            return now.addingTimeInterval(3600 * 12)
        default:
            return nil
        }
    }
}

// MARK: - Feedback Event

struct FeedbackEvent: Codable {
    let taskID: UUID
    let action: FeedbackAction
    let timestamp: Date
    let originalScore: Double
    let taskCategory: TaskCategory
    let hourOfDay: Int
}

// MARK: - Suggestion Feedback (Persistence)

struct SuggestionFeedback: Codable {
    var events: [FeedbackEvent] = []
    var adjustments: [UUID: Double] = [:]
    var snoozedUntil: [UUID: Date] = [:]
    var lastDecayDate: Date = Date()

    private static let key = "suggestion_feedback"
    private static let maxEvents = 200

    // MARK: - Persistence

    static func load() -> SuggestionFeedback {
        guard let data = UserDefaults.standard.data(forKey: key),
              let feedback = try? JSONDecoder().decode(SuggestionFeedback.self, from: data) else {
            return SuggestionFeedback()
        }
        return feedback
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    // MARK: - Score Adjustments

    func getAdjustment(for taskID: UUID) -> Double {
        adjustments[taskID] ?? 0
    }

    mutating func recordFeedback(taskID: UUID, action: FeedbackAction, originalScore: Double, taskCategory: TaskCategory) {
        let hour = Calendar.current.component(.hour, from: Date())

        let event = FeedbackEvent(
            taskID: taskID,
            action: action,
            timestamp: Date(),
            originalScore: originalScore,
            taskCategory: taskCategory,
            hourOfDay: hour
        )
        events.append(event)

        // Trim oldest events if over cap
        if events.count > Self.maxEvents {
            events = Array(events.suffix(Self.maxEvents))
        }

        // Update adjustment, clamped to ±15
        let current = adjustments[taskID] ?? 0
        let newValue = current + action.adjustmentDelta
        adjustments[taskID] = max(-15, min(15, newValue))

        // Set snooze suppression if applicable
        if let snoozeDate = action.snoozeUntilDate() {
            snoozedUntil[taskID] = snoozeDate
        }

        save()
    }

    // MARK: - Snooze Check

    func isSnoozed(_ taskID: UUID) -> Bool {
        guard let until = snoozedUntil[taskID] else { return false }
        return until > Date()
    }

    mutating func cleanExpiredSnoozes() {
        let countBefore = snoozedUntil.count
        let now = Date()
        snoozedUntil = snoozedUntil.filter { $0.value > now }
        if snoozedUntil.count < countBefore {
            save()
        }
    }

    // MARK: - Decay

    /// Apply 5% weekly decay if >=7 days since last decay.
    /// Prune adjustments < 0.5 magnitude after decay.
    mutating func applyDecayIfNeeded() {
        let calendar = Calendar.current
        guard let daysSinceLastDecay = calendar.dateComponents([.day], from: lastDecayDate, to: Date()).day,
              daysSinceLastDecay >= 7 else { return }

        let weeks = daysSinceLastDecay / 7
        let decayFactor = pow(0.95, Double(weeks))

        for (taskID, adjustment) in adjustments {
            let decayed = adjustment * decayFactor
            if abs(decayed) < 0.5 {
                adjustments.removeValue(forKey: taskID)
            } else {
                adjustments[taskID] = decayed
            }
        }

        lastDecayDate = Date()
        save()
    }
}
