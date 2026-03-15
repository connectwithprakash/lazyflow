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
        destination(scrollToItemID: nil)
    }

    @ViewBuilder
    func destination(scrollToItemID: String?) -> some View {
        switch self {
        case .general:
            GeneralSettingsView(scrollToItemID: scrollToItemID)
        case .notifications:
            BriefingsSettingsView(scrollToItemID: scrollToItemID)
        case .productivity:
            ProductivitySettingsView(scrollToItemID: scrollToItemID)
        case .ai:
            AISettingsView(scrollToItemID: scrollToItemID)
        case .dataAbout:
            DataAboutSettingsView(scrollToItemID: scrollToItemID)
        #if DEBUG
        case .developer:
            FeatureFlagsDebugView()
        #endif
        }
    }

    /// Whether title, subtitle, or any deep search item matches a query (locale-safe)
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(query)
            || subtitle.localizedCaseInsensitiveContains(query)
            || searchableItems.contains { $0.matches(query) }
    }

    // MARK: - Deep Search Items

    /// Individual searchable settings within this route
    var searchableItems: [SettingsSearchItem] {
        switch self {
        case .general:
            return [
                SettingsSearchItem(
                    id: "general_theme", label: "Theme",
                    section: "Appearance",
                    keywords: ["light", "dark", "system", "appearance"],
                    route: self),
                SettingsSearchItem(
                    id: "general_show_completed", label: "Show Completed Tasks",
                    section: "Tasks",
                    keywords: ["completed", "visibility", "hide"],
                    route: self),
                SettingsSearchItem(
                    id: "general_reminder_time", label: "Default Reminder Time",
                    section: "Tasks",
                    keywords: ["reminder", "notification"],
                    route: self),
                SettingsSearchItem(
                    id: "general_haptic", label: "Haptic Feedback",
                    section: "Accessibility",
                    keywords: ["haptics", "vibration"],
                    route: self),
            ]
        case .notifications:
            return [
                SettingsSearchItem(
                    id: "notifications_morning_prompt", label: "Show Prompt on Today",
                    section: "Morning Briefing",
                    keywords: ["morning", "briefing", "prompt"],
                    route: self),
                SettingsSearchItem(
                    id: "notifications_morning_reminder", label: "Morning Reminder",
                    section: "Morning Briefing",
                    keywords: ["morning", "notification", "time"],
                    route: self),
                SettingsSearchItem(
                    id: "notifications_evening_reminder", label: "Evening Reminder",
                    section: "Daily Summary",
                    keywords: ["evening", "daily", "summary", "notification"],
                    route: self),
                SettingsSearchItem(
                    id: "notifications_show_prompt_after", label: "Show Prompt After",
                    section: "Daily Summary",
                    keywords: ["time", "prompt"],
                    route: self),
                SettingsSearchItem(
                    id: "notifications_permission", label: "Notification Permissions",
                    section: "Notifications",
                    keywords: ["enabled", "disabled", "permissions"],
                    route: self),
            ]
        case .productivity:
            return [
                SettingsSearchItem(
                    id: "productivity_auto_sync", label: "Auto-Sync to Calendar",
                    section: "Calendar Sync",
                    keywords: ["calendar", "sync", "events"],
                    route: self),
                SettingsSearchItem(
                    id: "productivity_completion_policy", label: "On Task Completion",
                    section: "Calendar Sync",
                    keywords: ["completion", "keep", "delete", "event"],
                    route: self),
                SettingsSearchItem(
                    id: "productivity_busy_only", label: "Busy-Only Privacy Mode",
                    section: "Calendar Sync",
                    keywords: ["privacy", "focus block", "busy"],
                    route: self),
                SettingsSearchItem(
                    id: "productivity_auto_hide",
                    label: "Auto-Hide Frequently Skipped",
                    section: "Plan Your Day",
                    keywords: ["hide", "skip", "events"],
                    route: self),
                SettingsSearchItem(
                    id: "productivity_work_interval", label: "Work Interval",
                    section: "Focus Mode",
                    keywords: ["pomodoro", "focus", "work", "minutes"],
                    route: self),
                SettingsSearchItem(
                    id: "productivity_break_interval", label: "Break Interval",
                    section: "Focus Mode",
                    keywords: ["pomodoro", "break", "minutes"],
                    route: self),
                SettingsSearchItem(
                    id: "productivity_live_activity",
                    label: "Track Today's Progress",
                    section: "Live Activity",
                    keywords: ["live activity", "lock screen", "dynamic island"],
                    route: self),
            ]
        case .ai:
            return [
                SettingsSearchItem(
                    id: "ai_provider", label: "AI Provider",
                    section: "AI Provider",
                    keywords: ["apple", "ollama", "custom", "provider"],
                    route: self),
                SettingsSearchItem(
                    id: "ai_auto_suggest", label: "Auto-Suggest",
                    section: "AI Features",
                    keywords: ["suggestions", "tasks"],
                    route: self),
                SettingsSearchItem(
                    id: "ai_estimate_duration", label: "Estimate Duration",
                    section: "AI Features",
                    keywords: ["duration", "time"],
                    route: self),
                SettingsSearchItem(
                    id: "ai_suggest_priority", label: "Suggest Priority",
                    section: "AI Features",
                    keywords: ["priority", "level"],
                    route: self),
                SettingsSearchItem(
                    id: "ai_batch_analysis",
                    label: "Analyze Uncategorized Tasks",
                    section: "Batch Analysis",
                    keywords: ["batch", "categorize", "sparkles"],
                    route: self),
            ]
        case .dataAbout:
            return [
                SettingsSearchItem(
                    id: "data_icloud_sync", label: "iCloud Sync",
                    section: "iCloud",
                    keywords: ["icloud", "cloud", "sync"],
                    route: self),
                SettingsSearchItem(
                    id: "data_storage", label: "Storage",
                    section: "Storage",
                    keywords: ["local", "device", "tasks", "lists"],
                    route: self),
                SettingsSearchItem(
                    id: "data_resync", label: "Re-sync from iCloud",
                    section: "Storage",
                    keywords: ["resync", "redownload"],
                    route: self),
                SettingsSearchItem(
                    id: "data_clear_cache", label: "Clear Local Cache",
                    section: "Danger Zone",
                    keywords: ["delete", "cache", "reset"],
                    route: self),
                SettingsSearchItem(
                    id: "data_delete_everything", label: "Delete Everything",
                    section: "Danger Zone",
                    keywords: ["delete", "all", "local", "icloud"],
                    route: self),
                SettingsSearchItem(
                    id: "data_reset_events",
                    label: "Reset Event Preferences",
                    section: "Danger Zone",
                    keywords: ["reset", "event", "learning", "patterns"],
                    route: self),
                SettingsSearchItem(
                    id: "data_version", label: "Version",
                    section: "About",
                    keywords: ["version", "build"],
                    route: self),
                SettingsSearchItem(
                    id: "data_privacy", label: "Privacy Policy",
                    section: "About",
                    keywords: ["privacy", "legal"],
                    route: self),
                SettingsSearchItem(
                    id: "data_terms", label: "Terms of Service",
                    section: "About",
                    keywords: ["terms", "legal"],
                    route: self),
            ]
        #if DEBUG
        case .developer:
            return [
                SettingsSearchItem(
                    id: "dev_feature_flags", label: "Feature Flags",
                    section: "Developer",
                    keywords: ["flags", "debug", "overrides"],
                    route: self),
            ]
        #endif
        }
    }
}

// MARK: - Settings Search Item

/// A single searchable setting within a settings route, enabling deep search
struct SettingsSearchItem: Identifiable {
    let id: String
    let label: String
    let section: String
    let keywords: [String]
    let route: SettingsRoute

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return false }
        return label.localizedCaseInsensitiveContains(query)
            || section.localizedCaseInsensitiveContains(query)
            || keywords.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    static func allItems() -> [SettingsSearchItem] {
        SettingsRoute.allCases.flatMap { $0.searchableItems }
    }
}
