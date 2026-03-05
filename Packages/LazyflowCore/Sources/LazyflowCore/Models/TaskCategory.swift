import Foundation
import SwiftUI

/// Task categories with associated visual properties for automatic categorization
public enum TaskCategory: Int16, CaseIterable, Codable, Identifiable, Sendable {
    case uncategorized = 0
    case work = 1
    case personal = 2
    case health = 3
    case finance = 4
    case shopping = 5
    case errands = 6
    case learning = 7
    case home = 8

    public var id: Int16 { rawValue }

    public var displayName: String {
        switch self {
        case .uncategorized: return "Uncategorized"
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .finance: return "Finance"
        case .shopping: return "Shopping"
        case .errands: return "Errands"
        case .learning: return "Learning"
        case .home: return "Home"
        }
    }

    public var color: Color {
        switch self {
        case .uncategorized: return .secondary
        case .work: return .blue
        case .personal: return .purple
        case .health: return .green
        case .finance: return .mint
        case .shopping: return .orange
        case .errands: return .yellow
        case .learning: return .cyan
        case .home: return .brown
        }
    }

    public var iconName: String {
        switch self {
        case .uncategorized: return "questionmark.circle"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .finance: return "dollarsign.circle.fill"
        case .shopping: return "cart.fill"
        case .errands: return "figure.walk"
        case .learning: return "book.fill"
        case .home: return "house.fill"
        }
    }

}
