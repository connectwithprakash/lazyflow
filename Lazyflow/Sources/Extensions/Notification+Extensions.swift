import Foundation

extension Notification.Name {
    /// Triggered when user presses Cmd+N keyboard shortcut
    static let newTaskShortcut = Notification.Name("newTaskShortcut")

    /// Triggered when user presses Cmd+F keyboard shortcut
    static let searchShortcut = Notification.Name("searchShortcut")

    /// Triggered when user presses Cmd+1-5 to navigate tabs
    /// Object contains tab name as String: "today", "calendar", "upcoming", "lists", "settings"
    static let navigateToTab = Notification.Name("navigateToTab")

    /// Triggered when user taps "View Summary" notification action
    static let showDailySummary = Notification.Name("showDailySummary")

    /// Triggered when user taps "Start My Day" notification action
    static let showMorningBriefing = Notification.Name("showMorningBriefing")
}
