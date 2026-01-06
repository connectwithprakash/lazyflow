import Foundation

/// Lightweight task model for Watch communication
struct WatchTask: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Int16
    let isOverdue: Bool
    let dueTime: Date?

    /// Priority color name for SwiftUI
    var priorityColorName: String {
        switch priority {
        case 4: return "urgent"    // Red
        case 3: return "high"      // Orange
        case 2: return "medium"    // Yellow
        case 1: return "low"       // Blue
        default: return "none"     // Gray
        }
    }
}

// MARK: - Sync Message Types

enum WatchMessageType: String, Codable {
    case requestSync = "requestSync"
    case tasksUpdate = "tasksUpdate"
    case toggleCompletion = "toggleCompletion"
    case syncComplete = "syncComplete"
}

struct WatchMessage: Codable {
    let type: WatchMessageType
    let tasks: [WatchTask]?
    let taskID: UUID?
    let timestamp: Date

    init(type: WatchMessageType, tasks: [WatchTask]? = nil, taskID: UUID? = nil) {
        self.type = type
        self.tasks = tasks
        self.taskID = taskID
        self.timestamp = Date()
    }

    /// Convert to dictionary for WatchConnectivity
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        if let tasks = tasks, let data = try? JSONEncoder().encode(tasks) {
            dict["tasks"] = data
        }
        if let taskID = taskID {
            dict["taskID"] = taskID.uuidString
        }
        return dict
    }

    /// Create from dictionary received via WatchConnectivity
    static func from(dictionary: [String: Any]) -> WatchMessage? {
        guard let typeString = dictionary["type"] as? String,
              let type = WatchMessageType(rawValue: typeString),
              let _ = dictionary["timestamp"] as? TimeInterval else {
            return nil
        }

        var tasks: [WatchTask]?
        if let tasksData = dictionary["tasks"] as? Data {
            tasks = try? JSONDecoder().decode([WatchTask].self, from: tasksData)
        }

        var taskID: UUID?
        if let taskIDString = dictionary["taskID"] as? String {
            taskID = UUID(uuidString: taskIDString)
        }

        let message = WatchMessage(type: type, tasks: tasks, taskID: taskID)
        return message
    }
}
