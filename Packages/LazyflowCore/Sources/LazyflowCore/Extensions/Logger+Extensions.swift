import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lazyflow.app"

    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let tasks = Logger(subsystem: subsystem, category: "tasks")
    public static let calendar = Logger(subsystem: subsystem, category: "calendar")
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")
    public static let ai = Logger(subsystem: subsystem, category: "ai")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let categories = Logger(subsystem: subsystem, category: "categories")
    public static let lists = Logger(subsystem: subsystem, category: "lists")
    public static let notes = Logger(subsystem: subsystem, category: "notes")
}
