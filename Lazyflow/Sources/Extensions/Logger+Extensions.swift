import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lazyflow.app"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let tasks = Logger(subsystem: subsystem, category: "tasks")
    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let categories = Logger(subsystem: subsystem, category: "categories")
    static let lists = Logger(subsystem: subsystem, category: "lists")
    static let notes = Logger(subsystem: subsystem, category: "notes")
}
