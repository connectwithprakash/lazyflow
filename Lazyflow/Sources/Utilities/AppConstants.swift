import Foundation

/// Centralized configuration constants for the Lazyflow app.
/// Prevents magic numbers and string literals scattered across views and services.
enum AppConstants {

    // MARK: - UserDefaults Keys

    /// Type-safe UserDefaults key names shared across views and services.
    enum StorageKey {
        // Appearance & UI
        static let appearanceMode = "appearanceMode"
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let hasShownICloudPrompt = "hasShownICloudPrompt"
        static let hapticFeedback = "hapticFeedback"
        static let showCompletedTasks = "showCompletedTasks"

        // AI Settings
        static let aiAutoSuggest = "aiAutoSuggest"
        static let aiEstimateDuration = "aiEstimateDuration"
        static let aiSuggestPriority = "aiSuggestPriority"
        static let llmProvider = "llm_provider"

        // Notifications & Scheduling
        static let defaultReminderTime = "defaultReminderTime"
        static let summaryPromptHour = "summaryPromptHour"
        static let morningBriefingEnabled = "morningBriefingEnabled"
        static let morningBriefingNotificationEnabled = "morningBriefingNotificationEnabled"
        static let morningBriefingNotificationHour = "morningBriefingNotificationHour"
        static let dailySummaryNotificationEnabled = "dailySummaryNotificationEnabled"
        static let dailySummaryNotificationHour = "dailySummaryNotificationHour"
        static let lastMorningBriefingDate = "lastMorningBriefingDate"
        static let lastPlanYourDayDate = "lastPlanYourDayDate"

        // Calendar
        static let calendarViewMode = "calendarViewMode"
        static let calendarAutoSync = "calendarAutoSync"
        static let calendarCompletionPolicy = "calendarCompletionPolicy"
        static let calendarBusyOnly = "calendarBusyOnly"
        static let autoHideSkippedEvents = "autoHideSkippedEvents"

        // Pomodoro
        static let pomodoroWorkMinutes = "pomodoroWorkMinutes"
        static let pomodoroBreakMinutes = "pomodoroBreakMinutes"

        // Focus Session Persistence
        static let focusSessionTaskID = "focusSessionTaskID"
        static let focusSessionStartedAt = "focusSessionStartedAt"
        static let focusSessionIsPaused = "focusSessionIsPaused"
        static let focusSessionIsOnBreak = "focusSessionIsOnBreak"

        // iCloud Sync
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let lastCloudKitSyncDate = "lastCloudKitSyncDate"

        // Calendar Service
        static let lazyflowCalendarID = "lazyflowCalendarID"

        // AI Learning
        static let aiCorrections = "aiCorrections"
        static let durationAccuracyData = "durationAccuracyData"
        static let aiImpressions = "aiImpressions"
        static let aiRefinementRequests = "aiRefinementRequests"

        // Event Preference Learning
        static let eventSelectionRecords = "eventSelectionRecords"
        static let eventTitlePreferences = "eventTitlePreferences"

        // Daily Summary
        static let dailySummaryHistory = "daily_summary_history"
        static let lastSummaryDate = "last_summary_date"
    }

    // MARK: - Default Values

    /// Default values for user-configurable settings.
    enum Defaults {
        static let reminderHour = 9
        static let summaryPromptHour = 18
        static let morningBriefingNotificationHour = 7
        static let dailySummaryNotificationHour = 20
        static let pomodoroWorkMinutes: Double = 25
        static let pomodoroBreakMinutes: Double = 5
        static let activeStartHour = 8
        static let activeEndHour = 22
    }

    // MARK: - Service Timeouts

    /// Timeout and debounce intervals for services and UI.
    enum Timing {
        static let cloudKitTimeout: TimeInterval = 10
        static let llmTimeout: TimeInterval = 5
        static let searchDebounce: TimeInterval = 0.3
        static let snoozeCheckInterval: TimeInterval = 60
    }

    // MARK: - Feature Limits

    /// Limits for AI learning, notifications, and batch operations.
    enum Limits {
        // AI Learning
        static let maxAICorrections = 100
        static let maxAccuracyRecords = 100
        static let maxAIImpressions = 200
        static let maxAIRefinements = 200
        static let correctionExpiryDays = 90

        // Event Preferences
        static let maxEventRecords = 500
        static let eventExpiryDays = 180

        // AI Context
        static let recentTasksLimit = 10
        static let maxLLMInputLength = 1000
        static let maxContextCharacters = 1500
        static let minContextQualityThreshold = 0.2
        static let maxRecommendationSuggestions = 3

        // Notifications
        static let maxIntradayNotificationsPerTask = 10

        // Persistence
        static let batchDeleteSize = 400

        // Analytics
        static let staleThresholdDays = 7
    }
}
