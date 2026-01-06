import SwiftUI

/// App design constants
enum WidgetDesign {
    static let accentColor = Color(red: 0.129, green: 0.541, blue: 0.553) // Teal #218A8D
    static let urgentColor = Color(red: 0.898, green: 0.224, blue: 0.208) // Red
    static let highColor = Color(red: 0.961, green: 0.518, blue: 0.141)   // Orange
    static let mediumColor = Color(red: 0.965, green: 0.753, blue: 0.196) // Yellow
    static let lowColor = Color(red: 0.255, green: 0.478, blue: 0.871)    // Blue
}

/// Lightweight task model for widget display
struct WidgetTask: Identifiable {
    let id: UUID
    let title: String
    let priority: Int16
    let isCompleted: Bool
    let dueDate: Date?

    var priorityColor: Color {
        switch priority {
        case 4: return WidgetDesign.urgentColor
        case 3: return WidgetDesign.highColor
        case 2: return WidgetDesign.mediumColor
        case 1: return WidgetDesign.lowColor
        default: return .gray.opacity(0.4)
        }
    }

    var priorityName: String {
        switch priority {
        case 4: return "Urgent"
        case 3: return "High"
        case 2: return "Medium"
        case 1: return "Low"
        default: return ""
        }
    }
}
