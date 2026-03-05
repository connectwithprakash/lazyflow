import Foundation
import os
import LazyflowCore

/// Lightweight feature flag system with local defaults and debug overrides.
///
/// Usage:
/// ```
/// if FeatureFlags.shared.isEnabled(.quickCapture) { ... }
/// ```
///
/// Debug overrides persist in UserDefaults and take precedence over defaults.
/// Clear overrides with `removeOverride(_:)` or `removeAllOverrides()`.
@Observable
@MainActor
final class FeatureFlags {
    static let shared = FeatureFlags()

    private let logger = Logger(subsystem: "com.lazyflow.app", category: "FeatureFlags")
    private let overridePrefix = "featureFlag_override_"

    /// Tracked version counter to trigger observation when overrides change
    private var overrideVersion = 0

    /// All available feature flags with their compile-time defaults
    enum Flag: String, CaseIterable, Identifiable {
        // AI Features
        case aiAutoSuggest = "ai_auto_suggest"
        case aiEstimateDuration = "ai_estimate_duration"
        case aiSuggestPriority = "ai_suggest_priority"
        case aiTaskExtraction = "ai_task_extraction"

        // Productivity Features
        case quickCapture = "quick_capture"
        case focusMode = "focus_mode"
        case morningBriefing = "morning_briefing"
        case dailySummary = "daily_summary"

        // Sync & Calendar
        case calendarSync = "calendar_sync"
        case calendarAutoSync = "calendar_auto_sync"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .aiAutoSuggest: return "AI Auto-Suggest"
            case .aiEstimateDuration: return "AI Duration Estimation"
            case .aiSuggestPriority: return "AI Priority Suggestion"
            case .aiTaskExtraction: return "AI Task Extraction"
            case .quickCapture: return "Quick Capture"
            case .focusMode: return "Focus Mode"
            case .morningBriefing: return "Morning Briefing"
            case .dailySummary: return "Daily Summary"
            case .calendarSync: return "Calendar Sync"
            case .calendarAutoSync: return "Calendar Auto-Sync"
            }
        }

        var description: String {
            switch self {
            case .aiAutoSuggest: return "AI suggestions when creating tasks"
            case .aiEstimateDuration: return "AI-powered duration estimates"
            case .aiSuggestPriority: return "AI-powered priority suggestions"
            case .aiTaskExtraction: return "Extract tasks from quick capture notes"
            case .quickCapture: return "Quick note capture from anywhere"
            case .focusMode: return "Focus timer and distraction blocking"
            case .morningBriefing: return "Morning task briefing card"
            case .dailySummary: return "End-of-day productivity summary"
            case .calendarSync: return "Two-way calendar synchronization"
            case .calendarAutoSync: return "Automatic calendar sync on changes"
            }
        }

        /// Compile-time default value
        var defaultValue: Bool {
            switch self {
            case .aiAutoSuggest: return true
            case .aiEstimateDuration: return true
            case .aiSuggestPriority: return true
            case .aiTaskExtraction: return true
            case .quickCapture: return true
            case .focusMode: return true
            case .morningBriefing: return true
            case .dailySummary: return true
            case .calendarSync: return true
            case .calendarAutoSync: return false
            }
        }

        /// Group for display purposes
        var group: Group {
            switch self {
            case .aiAutoSuggest, .aiEstimateDuration, .aiSuggestPriority, .aiTaskExtraction:
                return .ai
            case .quickCapture, .focusMode, .morningBriefing, .dailySummary:
                return .productivity
            case .calendarSync, .calendarAutoSync:
                return .sync
            }
        }

        enum Group: String, CaseIterable {
            case ai = "AI Features"
            case productivity = "Productivity"
            case sync = "Sync & Calendar"
        }
    }

    private init() {}

    // MARK: - Public API

    /// Check if a feature flag is enabled
    func isEnabled(_ flag: Flag) -> Bool {
        // Access tracked property to create observation dependency
        _ = overrideVersion
        #if DEBUG
        // Debug override takes priority (only in debug builds)
        if let override = getOverride(flag) {
            return override
        }
        #endif
        return flag.defaultValue
    }

    #if DEBUG
    /// Set a debug override for a flag (debug builds only)
    func setOverride(_ flag: Flag, enabled: Bool) {
        let key = overridePrefix + flag.rawValue
        UserDefaults.standard.set(enabled, forKey: key)
        logger.info("Flag '\(flag.rawValue, privacy: .public)' overridden to \(enabled, privacy: .public)")
        overrideVersion += 1
    }

    /// Remove a debug override (revert to default)
    func removeOverride(_ flag: Flag) {
        let key = overridePrefix + flag.rawValue
        UserDefaults.standard.removeObject(forKey: key)
        logger.info("Flag '\(flag.rawValue, privacy: .public)' override removed")
        overrideVersion += 1
    }

    /// Remove all debug overrides
    func removeAllOverrides() {
        for flag in Flag.allCases {
            let key = overridePrefix + flag.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }
        logger.info("All feature flag overrides removed")
        overrideVersion += 1
    }

    /// Check if a flag has a debug override
    func hasOverride(_ flag: Flag) -> Bool {
        let key = overridePrefix + flag.rawValue
        return UserDefaults.standard.object(forKey: key) != nil
    }

    /// Get the override value (nil if no override)
    func getOverride(_ flag: Flag) -> Bool? {
        let key = overridePrefix + flag.rawValue
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: key)
    }
    #endif

    #if DEBUG
    /// Get flags grouped by category (debug only)
    static var groupedFlags: [(group: Flag.Group, flags: [Flag])] {
        Flag.Group.allCases.map { group in
            (group: group, flags: Flag.allCases.filter { $0.group == group })
        }
    }
    #endif
}
