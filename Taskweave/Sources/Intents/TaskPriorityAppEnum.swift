import AppIntents

/// App Intents compatible priority enum for Siri Shortcuts
enum TaskPriorityAppEnum: String, AppEnum {
    case none
    case low
    case medium
    case high
    case urgent

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Priority")

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .none: "None",
        .low: "Low",
        .medium: "Medium",
        .high: "High",
        .urgent: "Urgent"
    ]

    /// Convert to domain Priority enum
    func toDomain() -> Priority {
        switch self {
        case .none: return .none
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .urgent
        }
    }
}
