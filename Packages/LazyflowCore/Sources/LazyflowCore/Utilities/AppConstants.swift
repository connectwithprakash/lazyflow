import Foundation

/// Centralized configuration constants for the Lazyflow app.
/// Prevents magic numbers and string literals scattered across views and services.
public enum AppConstants {

    // MARK: - UserDefaults Keys

    /// Type-safe UserDefaults key names shared across views and services.
    public enum StorageKey {
        // Appearance & UI
        public static let appearanceMode = "appearanceMode"
        public static let hasSeenOnboarding = "hasSeenOnboarding"
        public static let hasShownICloudPrompt = "hasShownICloudPrompt"
        public static let hapticFeedback = "hapticFeedback"
        public static let showCompletedTasks = "showCompletedTasks"

        // AI Settings
        public static let aiAutoSuggest = "aiAutoSuggest"
        public static let aiEstimateDuration = "aiEstimateDuration"
        public static let aiSuggestPriority = "aiSuggestPriority"
        public static let llmProvider = "llm_provider"

        // Notifications & Scheduling
        public static let defaultReminderTime = "defaultReminderTime"
        public static let summaryPromptHour = "summaryPromptHour"
        public static let morningBriefingEnabled = "morningBriefingEnabled"
        public static let morningBriefingNotificationEnabled = "morningBriefingNotificationEnabled"
        public static let morningBriefingNotificationHour = "morningBriefingNotificationHour"
        public static let dailySummaryNotificationEnabled = "dailySummaryNotificationEnabled"
        public static let dailySummaryNotificationHour = "dailySummaryNotificationHour"
        public static let lastMorningBriefingDate = "lastMorningBriefingDate"
        public static let lastPlanYourDayDate = "lastPlanYourDayDate"

        // Calendar
        public static let calendarViewMode = "calendarViewMode"
        public static let calendarAutoSync = "calendarAutoSync"
        public static let calendarCompletionPolicy = "calendarCompletionPolicy"
        public static let calendarBusyOnly = "calendarBusyOnly"
        public static let autoHideSkippedEvents = "autoHideSkippedEvents"

        // Pomodoro
        public static let pomodoroWorkMinutes = "pomodoroWorkMinutes"
        public static let pomodoroBreakMinutes = "pomodoroBreakMinutes"

        // Focus Session Persistence
        public static let focusSessionTaskID = "focusSessionTaskID"
        public static let focusSessionStartedAt = "focusSessionStartedAt"
        public static let focusSessionIsPaused = "focusSessionIsPaused"
        public static let focusSessionIsOnBreak = "focusSessionIsOnBreak"

        // iCloud Sync
        public static let iCloudSyncEnabled = "iCloudSyncEnabled"
        public static let lastCloudKitSyncDate = "lastCloudKitSyncDate"

        // Calendar Service
        public static let lazyflowCalendarID = "lazyflowCalendarID"

        // AI Learning
        public static let aiCorrections = "aiCorrections"
        public static let durationAccuracyData = "durationAccuracyData"
        public static let aiImpressions = "aiImpressions"
        public static let aiRefinementRequests = "aiRefinementRequests"

        // Event Preference Learning
        public static let eventSelectionRecords = "eventSelectionRecords"
        public static let eventTitlePreferences = "eventTitlePreferences"

        // Daily Summary
        public static let dailySummaryHistory = "daily_summary_history"
        public static let lastSummaryDate = "last_summary_date"
    }

    // MARK: - Default Values

    /// Default values for user-configurable settings.
    public enum Defaults {
        public static let reminderHour = 9
        public static let summaryPromptHour = 18
        public static let morningBriefingNotificationHour = 7
        public static let dailySummaryNotificationHour = 20
        public static let pomodoroWorkMinutes: Double = 25
        public static let pomodoroBreakMinutes: Double = 5
        public static let activeStartHour = 8
        public static let activeEndHour = 22
    }

    // MARK: - Service Timeouts

    /// Timeout and debounce intervals for services and UI.
    public enum Timing {
        public static let cloudKitTimeout: TimeInterval = 10
        public static let llmTimeout: TimeInterval = 5
        public static let searchDebounce: TimeInterval = 0.3
        public static let snoozeCheckInterval: TimeInterval = 60
    }

    // MARK: - Feature Limits

    /// Limits for AI learning, notifications, and batch operations.
    public enum Limits {
        // AI Learning
        public static let maxAICorrections = 100
        public static let maxAccuracyRecords = 100
        public static let maxAIImpressions = 200
        public static let maxAIRefinements = 200
        public static let correctionExpiryDays = 90

        // Event Preferences
        public static let maxEventRecords = 500
        public static let eventExpiryDays = 180

        // AI Context
        public static let recentTasksLimit = 10
        public static let maxLLMInputLength = 1000
        public static let maxContextCharacters = 1500
        public static let minContextQualityThreshold = 0.2
        public static let maxRecommendationSuggestions = 3

        // Notifications
        public static let maxIntradayNotificationsPerTask = 10

        // Persistence
        public static let batchDeleteSize = 400

        // Analytics
        public static let staleThresholdDays = 7
    }
}
