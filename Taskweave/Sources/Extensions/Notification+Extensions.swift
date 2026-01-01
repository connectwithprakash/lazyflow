import Foundation

extension Notification.Name {
    /// Triggered when user presses Cmd+N keyboard shortcut
    static let newTaskShortcut = Notification.Name("newTaskShortcut")

    /// Triggered when user presses Cmd+F keyboard shortcut
    static let searchShortcut = Notification.Name("searchShortcut")

    /// Triggered when user presses Cmd+1-5 to navigate tabs
    /// Object contains tab name as String: "today", "calendar", "upcoming", "lists", "settings"
    static let navigateToTab = Notification.Name("navigateToTab")
}
