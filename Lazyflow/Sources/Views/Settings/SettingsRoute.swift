import SwiftUI
import LazyflowCore
import LazyflowUI

// MARK: - Settings Route

/// Navigation model for settings groups (Issue #285)
/// Each case represents a settings card on the Me tab that opens a dedicated page.
enum SettingsRoute: String, CaseIterable, Identifiable {
    case general
    case notifications
    case productivity
    case ai
    case dataAbout
    #if DEBUG
    case developer
    #endif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .notifications: return "Notifications"
        case .productivity: return "Productivity"
        case .ai: return "AI"
        case .dataAbout: return "Data & About"
        #if DEBUG
        case .developer: return "Developer"
        #endif
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Appearance, tasks & accessibility"
        case .notifications: return "Briefings, reminders & alerts"
        case .productivity: return "Calendar, focus & live activity"
        case .ai: return "Configure AI provider & features"
        case .dataAbout: return "Data management, about & legal"
        #if DEBUG
        case .developer: return "Feature flags & debug tools"
        #endif
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .notifications: return "bell.badge"
        case .productivity: return "timer"
        case .ai: return "brain"
        case .dataAbout: return "externaldrive"
        #if DEBUG
        case .developer: return "flag.fill"
        #endif
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .notifications: return .orange
        case .productivity: return Color.Lazyflow.accent
        case .ai: return .purple
        case .dataAbout: return .gray
        #if DEBUG
        case .developer: return .red
        #endif
        }
    }

    var accessibilityIdentifier: String {
        "settings_route_\(rawValue)"
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .general:
            GeneralSettingsView()
        case .notifications:
            BriefingsSettingsView()
        case .productivity:
            ProductivitySettingsView()
        case .ai:
            AISettingsView()
        case .dataAbout:
            DataAboutSettingsView()
        #if DEBUG
        case .developer:
            FeatureFlagsDebugView()
        #endif
        }
    }

    /// Whether title or subtitle matches a search query (locale-safe)
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(query)
            || subtitle.localizedCaseInsensitiveContains(query)
    }
}
