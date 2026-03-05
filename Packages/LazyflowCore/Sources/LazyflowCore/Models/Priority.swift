import Foundation
import SwiftUI

/// Task priority levels with associated visual properties
public enum Priority: Int16, CaseIterable, Codable, Identifiable, Sendable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4

    public var id: Int16 { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    public var color: Color {
        switch self {
        case .none: return .secondary
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }

    public var iconName: String {
        switch self {
        case .none: return "minus"
        case .low: return "flag"
        case .medium: return "flag.fill"
        case .high: return "exclamationmark.triangle"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .none: return 4
        }
    }
}
