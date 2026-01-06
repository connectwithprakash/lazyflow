import Foundation
import Combine

/// Service for managing protected time rules (lunch, family time, focus time, etc.)
final class TimeProtectionService: ObservableObject {
    static let shared = TimeProtectionService()

    // MARK: - Storage Keys

    private let rulesKey = "TimeProtectionRules"
    private let defaults = UserDefaults.standard

    // MARK: - Published Properties

    @Published private(set) var rules: [TimeProtectionRule] = []

    private init() {
        loadRules()
    }

    // MARK: - Rule Management

    /// Add a new time protection rule
    func addRule(_ rule: TimeProtectionRule) {
        rules.append(rule)
        saveRules()
    }

    /// Update an existing rule
    func updateRule(_ rule: TimeProtectionRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        saveRules()
    }

    /// Delete a rule
    func deleteRule(_ rule: TimeProtectionRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    /// Toggle rule active status
    func toggleRule(_ rule: TimeProtectionRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index].isActive.toggle()
        saveRules()
    }

    // MARK: - Time Checking

    /// Check if a given time falls within protected time
    func isTimeProtected(_ date: Date) -> (isProtected: Bool, rule: TimeProtectionRule?) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday, 7 = Saturday
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = timeComponents.hour, let minute = timeComponents.minute else {
            return (false, nil)
        }

        let timeInMinutes = hour * 60 + minute

        for rule in rules where rule.isActive {
            // Check if this day of week is included
            guard rule.daysOfWeek.contains(weekday) else { continue }

            let ruleStart = rule.startHour * 60 + rule.startMinute
            let ruleEnd = rule.endHour * 60 + rule.endMinute

            // Handle overnight rules (e.g., 22:00 - 06:00)
            if ruleStart > ruleEnd {
                if timeInMinutes >= ruleStart || timeInMinutes < ruleEnd {
                    return (true, rule)
                }
            } else {
                if timeInMinutes >= ruleStart && timeInMinutes < ruleEnd {
                    return (true, rule)
                }
            }
        }

        return (false, nil)
    }

    /// Check if a time range overlaps with protected time
    func isRangeProtected(start: Date, end: Date) -> (isProtected: Bool, rule: TimeProtectionRule?) {
        // Check start time
        let startCheck = isTimeProtected(start)
        if startCheck.isProtected {
            return startCheck
        }

        // Check end time
        let endCheck = isTimeProtected(end)
        if endCheck.isProtected {
            return endCheck
        }

        // Check midpoint for longer durations
        let midpoint = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
        return isTimeProtected(midpoint)
    }

    /// Find the next available time after protected period ends
    func findNextUnprotectedTime(after date: Date) -> Date {
        let calendar = Calendar.current
        var checkDate = date

        // Check up to 24 hours ahead
        for _ in 0..<(24 * 4) { // Check every 15 minutes
            let (isProtected, _) = isTimeProtected(checkDate)
            if !isProtected {
                return checkDate
            }
            checkDate = calendar.date(byAdding: .minute, value: 15, to: checkDate) ?? checkDate
        }

        // Fallback: next day at 9 AM
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextDay) ?? nextDay
    }

    /// Get all active rules that apply to a specific date
    func getActiveRules(for date: Date) -> [TimeProtectionRule] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        return rules.filter { rule in
            rule.isActive && rule.daysOfWeek.contains(weekday)
        }
    }

    // MARK: - Preset Rules

    /// Create common preset rules
    static func createPresetRules() -> [TimeProtectionRule] {
        return [
            TimeProtectionRule(
                name: "Lunch Break",
                type: .lunch,
                startHour: 12,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                daysOfWeek: [2, 3, 4, 5, 6], // Monday-Friday
                isActive: true
            ),
            TimeProtectionRule(
                name: "Evening Family Time",
                type: .family,
                startHour: 18,
                startMinute: 0,
                endHour: 20,
                endMinute: 0,
                daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // Every day
                isActive: false
            ),
            TimeProtectionRule(
                name: "Morning Focus",
                type: .focus,
                startHour: 9,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                daysOfWeek: [2, 3, 4, 5, 6], // Monday-Friday
                isActive: false
            ),
            TimeProtectionRule(
                name: "Sleep Time",
                type: .sleep,
                startHour: 22,
                startMinute: 0,
                endHour: 7,
                endMinute: 0,
                daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // Every day
                isActive: true
            ),
            TimeProtectionRule(
                name: "Weekend",
                type: .personal,
                startHour: 0,
                startMinute: 0,
                endHour: 23,
                endMinute: 59,
                daysOfWeek: [1, 7], // Sunday, Saturday
                isActive: false,
                allowedCategories: [.personal, .health, .errands]
            )
        ]
    }

    /// Initialize with preset rules (first time setup)
    func initializeWithPresets() {
        guard rules.isEmpty else { return }
        rules = Self.createPresetRules()
        saveRules()
    }

    // MARK: - Persistence

    private func loadRules() {
        guard let data = defaults.data(forKey: rulesKey),
              let decoded = try? JSONDecoder().decode([TimeProtectionRule].self, from: data) else {
            return
        }
        rules = decoded
    }

    private func saveRules() {
        guard let encoded = try? JSONEncoder().encode(rules) else { return }
        defaults.set(encoded, forKey: rulesKey)
    }
}

// MARK: - Time Protection Rule Model

struct TimeProtectionRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: TimeProtectionType
    var startHour: Int      // 0-23
    var startMinute: Int    // 0-59
    var endHour: Int        // 0-23
    var endMinute: Int      // 0-59
    var daysOfWeek: Set<Int> // 1 = Sunday, 7 = Saturday
    var isActive: Bool
    var allowedCategories: Set<TaskCategory>? // If set, only these categories can be scheduled

    init(
        id: UUID = UUID(),
        name: String,
        type: TimeProtectionType,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        daysOfWeek: Set<Int>,
        isActive: Bool = true,
        allowedCategories: Set<TaskCategory>? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.daysOfWeek = daysOfWeek
        self.isActive = isActive
        self.allowedCategories = allowedCategories
    }

    var formattedTimeRange: String {
        let startString = String(format: "%02d:%02d", startHour, startMinute)
        let endString = String(format: "%02d:%02d", endHour, endMinute)
        return "\(startString) - \(endString)"
    }

    var formattedDays: String {
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = daysOfWeek.sorted()

        if sortedDays == [2, 3, 4, 5, 6] {
            return "Weekdays"
        } else if sortedDays == [1, 7] {
            return "Weekends"
        } else if sortedDays == [1, 2, 3, 4, 5, 6, 7] {
            return "Every day"
        } else {
            return sortedDays.map { dayNames[$0] }.joined(separator: ", ")
        }
    }
}

enum TimeProtectionType: String, Codable, CaseIterable {
    case lunch = "Lunch"
    case family = "Family"
    case focus = "Focus"
    case sleep = "Sleep"
    case exercise = "Exercise"
    case personal = "Personal"
    case custom = "Custom"

    var systemImage: String {
        switch self {
        case .lunch: return "fork.knife"
        case .family: return "figure.2.and.child.holdinghands"
        case .focus: return "brain.head.profile"
        case .sleep: return "moon.zzz"
        case .exercise: return "figure.run"
        case .personal: return "person"
        case .custom: return "clock"
        }
    }

    var defaultColor: String {
        switch self {
        case .lunch: return "orange"
        case .family: return "pink"
        case .focus: return "purple"
        case .sleep: return "indigo"
        case .exercise: return "green"
        case .personal: return "blue"
        case .custom: return "gray"
        }
    }
}
