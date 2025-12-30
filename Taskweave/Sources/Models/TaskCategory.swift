import Foundation
import SwiftUI

/// Task categories with associated visual properties for automatic categorization
enum TaskCategory: Int16, CaseIterable, Codable, Identifiable {
    case uncategorized = 0
    case work = 1
    case personal = 2
    case health = 3
    case finance = 4
    case shopping = 5
    case errands = 6
    case learning = 7
    case home = 8

    var id: Int16 { rawValue }

    var displayName: String {
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

    var color: Color {
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

    var iconName: String {
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

    /// Keywords associated with each category for AI detection
    var keywords: [String] {
        switch self {
        case .uncategorized:
            return []
        case .work:
            return [
                "meeting", "project", "deadline", "report", "client", "presentation",
                "email", "call", "review", "code", "deploy", "sprint", "standup",
                "sync", "proposal", "contract", "invoice", "milestone", "release",
                "PR", "pull request", "merge", "ticket", "jira", "slack", "team",
                "manager", "colleague", "office", "work", "job", "career"
            ]
        case .personal:
            return [
                "birthday", "anniversary", "gift", "party", "friend", "family",
                "date", "appointment", "reservation", "visit", "vacation", "trip",
                "travel", "passport", "license", "registration", "renew", "plan"
            ]
        case .health:
            return [
                "gym", "workout", "exercise", "run", "yoga", "meditation",
                "doctor", "dentist", "appointment", "medication", "medicine",
                "prescription", "vitamins", "sleep", "diet", "nutrition",
                "therapy", "mental", "checkup", "hospital", "clinic", "health"
            ]
        case .finance:
            return [
                "pay", "bill", "invoice", "budget", "tax", "taxes", "bank",
                "transfer", "deposit", "withdraw", "investment", "stock",
                "crypto", "401k", "retirement", "insurance", "rent", "mortgage",
                "loan", "credit", "debt", "save", "savings", "expense"
            ]
        case .shopping:
            return [
                "buy", "purchase", "order", "amazon", "groceries", "grocery",
                "store", "shop", "mall", "market", "supermarket", "online",
                "deliver", "delivery", "pickup", "cart", "list", "item"
            ]
        case .errands:
            return [
                "pickup", "drop off", "return", "exchange", "mail", "post",
                "package", "dry clean", "laundry", "car wash", "gas", "fuel",
                "DMV", "pharmacy", "haircut", "barber", "appointment"
            ]
        case .learning:
            return [
                "read", "study", "course", "class", "learn", "tutorial",
                "book", "article", "research", "practice", "certificate",
                "exam", "test", "quiz", "homework", "assignment", "lecture",
                "webinar", "workshop", "conference", "skill", "training"
            ]
        case .home:
            return [
                "clean", "cleaning", "vacuum", "mop", "dishes", "laundry",
                "fix", "repair", "maintenance", "plumber", "electrician",
                "paint", "organize", "declutter", "furniture", "garden",
                "lawn", "yard", "trash", "recycle", "cook", "meal prep"
            ]
        }
    }

    /// Detect category from task title and notes using ML model with keyword fallback
    /// - Parameters:
    ///   - title: The task title
    ///   - notes: Optional task notes/description
    ///   - minimumConfidence: Minimum ML confidence threshold (default 0.3)
    /// - Returns: Detected category
    static func detect(from title: String, notes: String? = nil, minimumConfidence: Double = 0.3) -> TaskCategory {
        // Try ML-based classification first
        if let mlResult = TaskClassifier.shared.classifyWithConfidence(title: title, notes: notes),
           mlResult.confidence >= minimumConfidence {
            return mlResult.category
        }

        // Fallback to keyword matching
        return detectWithKeywords(from: title, notes: notes)
    }

    /// Detect category using keyword matching (fallback method)
    private static func detectWithKeywords(from title: String, notes: String?) -> TaskCategory {
        let text = "\(title) \(notes ?? "")".lowercased()

        var bestMatch: TaskCategory = .uncategorized
        var highestScore = 0

        for category in TaskCategory.allCases where category != .uncategorized {
            let score = category.keywords.reduce(0) { count, keyword in
                count + (text.contains(keyword.lowercased()) ? 1 : 0)
            }

            if score > highestScore {
                highestScore = score
                bestMatch = category
            }
        }

        return bestMatch
    }
}
