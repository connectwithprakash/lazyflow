import Foundation
import Combine
import EventKit

/// Service for generating daily summaries and managing productivity streaks
final class DailySummaryService: ObservableObject {
    static let shared = DailySummaryService()

    // MARK: - Published Properties

    @Published private(set) var todaySummary: DailySummaryData?
    @Published private(set) var streakData: StreakData
    @Published private(set) var isGeneratingSummary: Bool = false
    @Published private(set) var summaryHistory: [DailySummaryData] = []

    // MARK: - Cached Data for Preloading

    @Published private(set) var cachedMorningBriefing: MorningBriefingData?
    @Published private(set) var isPreloading: Bool = false
    private var morningBriefingCacheDate: Date?

    // MARK: - Dependencies

    private let taskService: TaskService
    private let llmService: LLMService
    private let calendarService: CalendarService

    // MARK: - UserDefaults Keys

    private static let summaryHistoryKey = "daily_summary_history"
    private static let lastSummaryDateKey = "last_summary_date"

    // MARK: - Initialization

    init(taskService: TaskService = .shared, llmService: LLMService = .shared, calendarService: CalendarService = .shared) {
        self.taskService = taskService
        self.llmService = llmService
        self.calendarService = calendarService
        self.streakData = StreakData.load()
        self.summaryHistory = Self.loadSummaryHistory()
    }

    // MARK: - Summary Generation

    /// Generate a summary for a specific date
    /// - Parameters:
    ///   - date: The date to generate summary for (defaults to today)
    ///   - persist: If true (default), saves to history and updates streaks. If false, generates preview data only.
    func generateSummary(for date: Date = Date(), persist: Bool = true) async -> DailySummaryData {
        await MainActor.run { isGeneratingSummary = true }
        defer {
            _Concurrency.Task { @MainActor in
                isGeneratingSummary = false
            }
        }

        // Fetch completed tasks for the date
        let completedTasks = taskService.fetchTasksCompletedOn(date: date)
        let plannedTasks = taskService.fetchTasksDueOn(date: date)

        // Create task summaries
        let taskSummaries = completedTasks.map { CompletedTaskSummary(from: $0) }

        // Calculate top category
        let topCategory = calculateTopCategory(from: completedTasks)

        // Calculate total minutes worked
        let totalMinutes = calculateTotalMinutesWorked(from: completedTasks)

        // Calculate productivity score
        let productivityScore = calculateProductivityScore(
            completed: completedTasks.count,
            planned: plannedTasks.count
        )

        // Create initial summary without AI content
        var summary = DailySummaryData(
            date: date,
            tasksCompleted: completedTasks.count,
            totalTasksPlanned: plannedTasks.count,
            completedTasks: taskSummaries,
            topCategory: topCategory,
            totalMinutesWorked: totalMinutes,
            productivityScore: productivityScore
        )

        // Generate AI summary if LLM is available
        if llmService.isReady && !completedTasks.isEmpty {
            do {
                let (aiSummary, encouragement) = try await generateAISummary(data: summary)
                summary.aiSummary = aiSummary
                summary.encouragement = encouragement
            } catch {
                // Fall back to default encouragement
                summary.encouragement = getDefaultEncouragement(
                    streak: streakData.currentStreak,
                    score: productivityScore
                )
            }
        } else {
            summary.encouragement = getDefaultEncouragement(
                streak: streakData.currentStreak,
                score: productivityScore
            )
        }

        // Only persist if requested (default behavior)
        // Preview mode (persist: false) skips saving to allow preloading without suppressing prompts
        if persist {
            // Update streak
            updateStreak(for: date, wasProductive: summary.wasProductiveDay)

            // Save summary
            saveSummary(summary)
        }

        let finalSummary = summary
        await MainActor.run {
            self.todaySummary = finalSummary
        }

        return summary
    }

    // MARK: - AI Summary Generation

    private func generateAISummary(data: DailySummaryData) async throws -> (summary: String, encouragement: String) {
        let prompt = buildSummaryPrompt(data: data)
        let systemPrompt = "You are a supportive productivity assistant. Generate encouraging, personalized summaries. Respond in JSON format only."

        let response = try await llmService.complete(prompt: prompt, systemPrompt: systemPrompt)

        return parseSummaryResponse(response)
    }

    private func buildSummaryPrompt(data: DailySummaryData) -> String {
        let taskList = data.completedTasks
            .prefix(10)
            .map { "- \($0.title) (\($0.category.displayName))" }
            .joined(separator: "\n")

        return """
        Generate a brief, encouraging daily summary for a productivity app user.

        Today's Stats:
        - Tasks completed: \(data.tasksCompleted) of \(data.totalTasksPlanned) planned
        - Top category: \(data.topCategory?.displayName ?? "Various")
        - Time worked: \(data.formattedTimeWorked)
        - Current streak: \(streakData.currentStreak) days

        Completed tasks:
        \(taskList.isEmpty ? "No tasks completed yet" : taskList)

        Provide:
        1. A 2-3 sentence natural language summary of their day (reference specific accomplishments if any)
        2. One sentence of encouragement based on their streak and progress

        Respond in JSON format only:
        {
            "summary": "<natural recap of day>",
            "encouragement": "<motivating message>"
        }

        Keep tone warm, supportive, and concise.
        """
    }

    private func parseSummaryResponse(_ response: String) -> (summary: String, encouragement: String) {
        // Try to extract JSON from response
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (
                summary: "Great job staying productive today!",
                encouragement: getDefaultEncouragement(streak: streakData.currentStreak, score: 50)
            )
        }

        let summary = json["summary"] as? String ?? "Great job staying productive today!"
        let encouragement = json["encouragement"] as? String ?? getDefaultEncouragement(streak: streakData.currentStreak, score: 50)

        return (summary: summary, encouragement: encouragement)
    }

    private func extractJSON(from response: String) -> Data? {
        // Try direct parsing first
        if let data = response.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        // Try to extract JSON object from response text
        let pattern = "\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            return nil
        }

        return String(response[range]).data(using: .utf8)
    }

    // MARK: - Calculations

    private func calculateTopCategory(from tasks: [Task]) -> TaskCategory? {
        guard !tasks.isEmpty else { return nil }

        let categoryCounts = Dictionary(grouping: tasks, by: { $0.category })
            .mapValues { $0.count }

        return categoryCounts.max(by: { $0.value < $1.value })?.key
    }

    private func calculateTotalMinutesWorked(from tasks: [Task]) -> Int {
        let totalSeconds = tasks.compactMap { $0.estimatedDuration }.reduce(0, +)
        return Int(totalSeconds / 60)
    }

    func calculateProductivityScore(completed: Int, planned: Int) -> Double {
        guard completed > 0 else { return 0 }

        // Base score from completion rate
        var score: Double
        if planned > 0 {
            score = min(100, (Double(completed) / Double(planned)) * 100)
        } else {
            // Bonus for completing tasks when none were planned
            score = min(100, Double(completed) * 20)
        }

        return score
    }

    // MARK: - Streak Management

    func updateStreak(for date: Date, wasProductive: Bool) {
        streakData.recordDay(date: date, wasProductive: wasProductive)
    }

    // MARK: - Encouragement Messages

    func getDefaultEncouragement(streak: Int, score: Double) -> String {
        if streak >= 30 {
            return "Incredible! \(streak) days strong. You're unstoppable!"
        } else if streak >= 14 {
            return "Two weeks of consistency! Your dedication is inspiring."
        } else if streak >= 7 {
            return "A full week streak! You're building great habits."
        } else if streak >= 3 {
            return "Keep the momentum going! \(streak) days and counting."
        } else if streak == 1 {
            return "Great start! Every journey begins with a single step."
        } else if score >= 80 {
            return "Excellent productivity today! Well done."
        } else if score >= 50 {
            return "Solid progress! Keep up the good work."
        } else if score > 0 {
            return "Every completed task counts. Tomorrow is a fresh start!"
        } else {
            return "Ready to tackle some tasks? You've got this!"
        }
    }

    // MARK: - Persistence

    private func saveSummary(_ summary: DailySummaryData) {
        // Add to history (keep last 30 days)
        var history = Self.loadSummaryHistory()

        // Remove any existing summary for the same date
        let calendar = Calendar.current
        history.removeAll { calendar.isDate($0.date, inSameDayAs: summary.date) }

        // Add new summary
        history.append(summary)

        // Keep only last 30 days
        history = Array(history.suffix(30))

        // Sort by date descending
        history.sort { $0.date > $1.date }

        // Save
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Self.summaryHistoryKey)
        }

        // Update last summary date
        UserDefaults.standard.set(summary.date, forKey: Self.lastSummaryDateKey)

        _Concurrency.Task { @MainActor in
            self.summaryHistory = history
        }
    }

    static func loadSummaryHistory() -> [DailySummaryData] {
        guard let data = UserDefaults.standard.data(forKey: summaryHistoryKey),
              let history = try? JSONDecoder().decode([DailySummaryData].self, from: data) else {
            return []
        }
        return history
    }

    /// Check if summary was already generated today
    var hasTodaySummary: Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: Self.lastSummaryDateKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastDate)
    }

    /// Get summary for a specific date from history
    func getSummary(for date: Date) -> DailySummaryData? {
        let calendar = Calendar.current
        return summaryHistory.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Check if summary needs refresh (task counts changed since last generation)
    func needsRefresh(for date: Date) -> Bool {
        guard let cached = getSummary(for: date) else { return true }

        let currentCompleted = taskService.fetchTasksCompletedOn(date: date).count
        let currentPlanned = taskService.fetchTasksDueOn(date: date).count

        return cached.tasksCompleted != currentCompleted || cached.totalTasksPlanned != currentPlanned
    }

    // MARK: - Preloading

    /// Preload morning briefing and daily summary data in the background
    /// Call this when MoreView appears to have data ready when user taps
    func preloadInsightsData() {
        guard !isPreloading else { return }

        _Concurrency.Task {
            await MainActor.run { isPreloading = true }
            defer {
                _Concurrency.Task { @MainActor in
                    isPreloading = false
                }
            }

            // Preload morning briefing if cache is stale or missing
            if morningBriefingNeedsRefresh() {
                let briefing = await generateMorningBriefingInternal()
                await MainActor.run {
                    cachedMorningBriefing = briefing
                    morningBriefingCacheDate = Date()
                }
            }

            // Preload today's summary if not already generated
            // Use persist: false to avoid suppressing the Daily Summary prompt in TodayView
            if todaySummary == nil || needsRefresh(for: Date()) {
                let summary = await generateSummary(for: Date(), persist: false)
                await MainActor.run {
                    todaySummary = summary
                }
            }
        }
    }

    /// Check if morning briefing cache needs refresh
    /// Only refreshes on a new day - users can manually refresh via the refresh button
    private func morningBriefingNeedsRefresh() -> Bool {
        guard let cacheDate = morningBriefingCacheDate,
              cachedMorningBriefing != nil else {
            return true
        }

        // Only refresh if it's a different day - morning briefing data is stable for the day
        let calendar = Calendar.current
        return !calendar.isDate(cacheDate, inSameDayAs: Date())
    }

    /// Get cached morning briefing if available, otherwise generate new one
    func getMorningBriefing() async -> MorningBriefingData {
        // Return cached if fresh
        if !morningBriefingNeedsRefresh(), let cached = cachedMorningBriefing {
            return cached
        }

        // Generate and cache
        let briefing = await generateMorningBriefingInternal()
        await MainActor.run {
            cachedMorningBriefing = briefing
            morningBriefingCacheDate = Date()
        }
        return briefing
    }

    /// Force refresh morning briefing, bypassing cache (for manual refresh button)
    func forceRefreshMorningBriefing() async -> MorningBriefingData {
        let briefing = await generateMorningBriefingInternal()
        await MainActor.run {
            cachedMorningBriefing = briefing
            morningBriefingCacheDate = Date()
        }
        return briefing
    }

    // MARK: - Morning Briefing Generation

    /// Generate morning briefing with yesterday's recap, today's plan, and weekly stats
    func generateMorningBriefing() async -> MorningBriefingData {
        // Use cached version if fresh, otherwise generate new
        return await getMorningBriefing()
    }

    /// Internal method to generate morning briefing (always generates fresh)
    private func generateMorningBriefingInternal() async -> MorningBriefingData {
        await MainActor.run { isGeneratingSummary = true }
        defer {
            _Concurrency.Task { @MainActor in
                isGeneratingSummary = false
            }
        }

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Yesterday's data
        let yesterdayCompleted = taskService.fetchTasksCompletedOn(date: yesterday)
        let yesterdayPlanned = taskService.fetchTasksDueOn(date: yesterday)
        let yesterdayTopCategory = calculateTopCategory(from: yesterdayCompleted)

        // Today's tasks
        let todayTasks = taskService.fetchTodayTasks()
        let todayOverdue = taskService.fetchOverdueTasks()
        let todayTaskSummaries = todayTasks
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
            .prefix(10)
            .map { TaskBriefingSummary(from: $0) }
        let todayHighPriority = todayTasks.filter { $0.priority == .high || $0.priority == .urgent }.count
        let todayEstimatedMinutes = calculateTotalMinutesWorked(from: todayTasks)

        // Weekly stats
        let weeklyStats = calculateWeeklyStats()

        // Calendar schedule summary (nil if no calendar access)
        let scheduleSummary = calculateScheduleSummary(for: today)

        // Create initial briefing without AI content
        var briefing = MorningBriefingData(
            date: today,
            yesterdayCompleted: yesterdayCompleted.count,
            yesterdayPlanned: yesterdayPlanned.count,
            yesterdayTopCategory: yesterdayTopCategory,
            todayTasks: Array(todayTaskSummaries),
            todayHighPriority: todayHighPriority,
            todayOverdue: todayOverdue.count,
            todayEstimatedMinutes: todayEstimatedMinutes,
            weeklyStats: weeklyStats,
            scheduleSummary: scheduleSummary
        )

        // Generate AI content if available
        if llmService.isReady {
            do {
                let aiContent = try await generateAIMorningBriefing(data: briefing)
                briefing.aiSummary = aiContent.summary
                briefing.todayFocus = aiContent.todayFocus
                briefing.motivationalMessage = aiContent.motivation
            } catch {
                // Fall back to defaults
                briefing.motivationalMessage = getDefaultMorningMotivation(briefing: briefing)
            }
        } else {
            briefing.motivationalMessage = getDefaultMorningMotivation(briefing: briefing)
        }

        return briefing
    }

    /// Calculate weekly productivity statistics
    func calculateWeeklyStats() -> WeeklyStats {
        let calendar = Calendar.current
        let today = Date()

        // Get start of week (Sunday or Monday based on locale)
        let weekStart = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: today))!

        // Get all summaries from this week
        let weekSummaries = summaryHistory.filter {
            $0.date >= weekStart && $0.date <= today
        }

        let totalCompleted = weekSummaries.reduce(0) { $0 + $1.tasksCompleted }
        let totalPlanned = weekSummaries.reduce(0) { $0 + $1.totalTasksPlanned }
        let avgRate = totalPlanned > 0 ? (Double(totalCompleted) / Double(totalPlanned)) * 100 : 0

        // Find most productive day
        let mostProductive = weekSummaries.max(by: { $0.tasksCompleted < $1.tasksCompleted })
        let dayName = mostProductive?.date.formatted(.dateTime.weekday(.wide))

        // Calculate days until weekend
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilWeekEnd = weekday == 1 ? 0 : (7 - weekday + 1) // Sunday = 1

        return WeeklyStats(
            tasksCompletedThisWeek: totalCompleted,
            totalTasksPlannedThisWeek: totalPlanned,
            averageCompletionRate: avgRate,
            mostProductiveDay: dayName,
            currentStreak: streakData.currentStreak,
            daysUntilWeekEnd: daysUntilWeekEnd
        )
    }

    // MARK: - Schedule Summary Calculation

    /// Calculate today's schedule summary from calendar events
    func calculateScheduleSummary(for date: Date = Date()) -> ScheduleSummary? {
        guard calendarService.hasCalendarAccess else { return nil }

        let events = calendarService.fetchEvents(for: date)
        guard !events.isEmpty else {
            // No events today - return summary with full day as free block
            return ScheduleSummary(
                totalMeetingMinutes: 0,
                meetingCount: 0,
                nextEvent: nil,
                largestFreeBlockMinutes: calculateWorkdayMinutes(),
                allDayEvents: []
            )
        }

        let calendar = Calendar.current
        let now = Date()

        // Separate all-day and timed events
        let allDayEvents = events.filter { $0.isAllDay }
        let timedEvents = events.filter { !$0.isAllDay }

        // Convert to CalendarEventSummary
        let allDaySummaries = allDayEvents.map { event in
            CalendarEventSummary(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: true,
                location: event.location
            )
        }

        // Calculate total meeting time (non-all-day events only)
        let totalMeetingMinutes = timedEvents.reduce(0) { total, event in
            total + Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        }

        // Find next event (first event starting >= now, or first today if all passed)
        let upcomingEvents = timedEvents.filter { $0.startDate >= now }
        let nextEvent: CalendarEventSummary?
        if let upcoming = upcomingEvents.first {
            nextEvent = CalendarEventSummary(
                id: upcoming.eventIdentifier ?? UUID().uuidString,
                title: upcoming.title ?? "Untitled",
                startDate: upcoming.startDate,
                endDate: upcoming.endDate,
                isAllDay: false,
                location: upcoming.location
            )
        } else {
            // All events have passed - return nil
            nextEvent = nil
        }

        // Calculate largest free block using merged intervals
        let largestFreeBlock = calculateLargestFreeBlock(events: timedEvents, for: date)

        return ScheduleSummary(
            totalMeetingMinutes: totalMeetingMinutes,
            meetingCount: timedEvents.count,
            nextEvent: nextEvent,
            largestFreeBlockMinutes: largestFreeBlock,
            allDayEvents: allDaySummaries
        )
    }

    /// Calculate the largest free block between events
    private func calculateLargestFreeBlock(events: [EKEvent], for date: Date) -> Int {
        let calendar = Calendar.current

        // Define workday bounds (8 AM to 6 PM)
        let startOfDay = calendar.startOfDay(for: date)
        let workdayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay)!
        let workdayEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay)!

        guard !events.isEmpty else {
            return calculateWorkdayMinutes()
        }

        // Sort events by start time
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        // Merge overlapping intervals
        var mergedIntervals: [(start: Date, end: Date)] = []
        for event in sortedEvents {
            let eventStart = max(event.startDate, workdayStart)
            let eventEnd = min(event.endDate, workdayEnd)

            if eventStart >= eventEnd { continue } // Event outside workday

            if mergedIntervals.isEmpty {
                mergedIntervals.append((eventStart, eventEnd))
            } else if let last = mergedIntervals.last, eventStart <= last.end {
                // Overlapping - extend the last interval
                mergedIntervals[mergedIntervals.count - 1] = (last.start, max(last.end, eventEnd))
            } else {
                mergedIntervals.append((eventStart, eventEnd))
            }
        }

        // If all events are outside workday, return full workday
        guard !mergedIntervals.isEmpty else {
            return calculateWorkdayMinutes()
        }

        // Calculate gaps
        var largestGap = 0

        // Gap before first event
        if let first = mergedIntervals.first {
            let gapBefore = Int(first.start.timeIntervalSince(workdayStart) / 60)
            largestGap = max(largestGap, gapBefore)
        }

        // Gaps between events
        for i in 0..<(mergedIntervals.count - 1) {
            let gap = Int(mergedIntervals[i + 1].start.timeIntervalSince(mergedIntervals[i].end) / 60)
            largestGap = max(largestGap, gap)
        }

        // Gap after last event
        if let last = mergedIntervals.last {
            let gapAfter = Int(workdayEnd.timeIntervalSince(last.end) / 60)
            largestGap = max(largestGap, gapAfter)
        }

        return max(0, largestGap)
    }

    /// Calculate total workday minutes (8 AM to 6 PM = 10 hours)
    func calculateWorkdayMinutes() -> Int {
        return 10 * 60 // 600 minutes
    }

    // MARK: - Testable Schedule Calculations

    /// Calculate largest free block from event intervals (internal for testing)
    /// - Parameters:
    ///   - intervals: Array of (start, end) date tuples representing events
    ///   - workdayStart: Start of workday
    ///   - workdayEnd: End of workday
    /// - Returns: Largest free block in minutes
    func calculateLargestFreeBlockFromIntervals(
        _ intervals: [(start: Date, end: Date)],
        workdayStart: Date,
        workdayEnd: Date
    ) -> Int {
        guard !intervals.isEmpty else {
            return calculateWorkdayMinutes()
        }

        // Sort by start time
        let sorted = intervals.sorted { $0.start < $1.start }

        // Merge overlapping intervals, clipping to workday
        var merged: [(start: Date, end: Date)] = []
        for interval in sorted {
            let clippedStart = max(interval.start, workdayStart)
            let clippedEnd = min(interval.end, workdayEnd)

            if clippedStart >= clippedEnd { continue } // Outside workday

            if merged.isEmpty {
                merged.append((clippedStart, clippedEnd))
            } else if let last = merged.last, clippedStart <= last.end {
                merged[merged.count - 1] = (last.start, max(last.end, clippedEnd))
            } else {
                merged.append((clippedStart, clippedEnd))
            }
        }

        // If all events outside workday, return full workday
        guard !merged.isEmpty else {
            return calculateWorkdayMinutes()
        }

        // Calculate gaps
        var largestGap = 0

        // Gap before first event
        if let first = merged.first {
            largestGap = max(largestGap, Int(first.start.timeIntervalSince(workdayStart) / 60))
        }

        // Gaps between events
        for i in 0..<(merged.count - 1) {
            let gap = Int(merged[i + 1].start.timeIntervalSince(merged[i].end) / 60)
            largestGap = max(largestGap, gap)
        }

        // Gap after last event
        if let last = merged.last {
            largestGap = max(largestGap, Int(workdayEnd.timeIntervalSince(last.end) / 60))
        }

        return max(0, largestGap)
    }

    /// Determine next event from a list of events (internal for testing)
    /// - Parameters:
    ///   - events: Array of calendar event summaries
    ///   - now: Current time
    /// - Returns: Next upcoming event, or nil if all have passed
    func findNextEvent(from events: [CalendarEventSummary], now: Date) -> CalendarEventSummary? {
        events.filter { $0.startDate >= now }.first
    }

    // MARK: - Morning Briefing AI

    private func generateAIMorningBriefing(data: MorningBriefingData) async throws -> (summary: String, todayFocus: String, motivation: String) {
        let prompt = buildMorningBriefingPrompt(data: data)
        let systemPrompt = "You are a supportive productivity assistant helping users start their day. Generate encouraging, actionable morning briefings. Respond in JSON format only."

        let response = try await llmService.complete(prompt: prompt, systemPrompt: systemPrompt)

        return parseMorningBriefingResponse(response, briefing: data)
    }

    private func buildMorningBriefingPrompt(data: MorningBriefingData) -> String {
        let todayTaskList = data.todayTasks
            .prefix(5)
            .map { task in
                let priority = task.priority == .urgent ? "[URGENT]" : task.priority == .high ? "[HIGH]" : ""
                return "- \(priority) \(task.title) (\(task.category.displayName))"
            }
            .joined(separator: "\n")

        // Build schedule context if available
        var scheduleSection = ""
        if let schedule = data.scheduleSummary {
            var scheduleLines: [String] = []
            if schedule.hasMeetings {
                scheduleLines.append("- Meetings: \(schedule.meetingCount) (\(schedule.formattedMeetingTime) total)")
            } else {
                scheduleLines.append("- No meetings scheduled")
            }
            if let nextEvent = schedule.nextEvent {
                scheduleLines.append("- Next: \(nextEvent.title) at \(nextEvent.formattedStartTime)")
            }
            if schedule.hasSignificantFreeBlock {
                scheduleLines.append("- Largest free block: \(schedule.formattedFreeBlock)")
            }
            if !schedule.allDayEvents.isEmpty {
                let allDayTitles = schedule.allDayEvents.prefix(2).map { $0.title }.joined(separator: ", ")
                scheduleLines.append("- All-day: \(allDayTitles)")
            }
            scheduleSection = """

            Today's Calendar:
            \(scheduleLines.joined(separator: "\n"))
            """
        }

        return """
        Generate a motivating morning briefing for a productivity app user.

        Yesterday's Results:
        - Completed: \(data.yesterdayCompleted) of \(data.yesterdayPlanned) tasks
        - Top category: \(data.yesterdayTopCategory?.displayName ?? "Various")

        Today's Plan:
        - Total tasks: \(data.todayTasks.count)
        - High priority: \(data.todayHighPriority)
        - Overdue: \(data.todayOverdue)
        - Estimated time: \(data.formattedTodayTime)\(scheduleSection)

        Weekly Progress:
        - Tasks completed this week: \(data.weeklyStats.tasksCompletedThisWeek)
        - Completion rate: \(data.weeklyStats.formattedCompletionRate)
        - Current streak: \(data.weeklyStats.currentStreak) days

        Today's Top Priorities:
        \(todayTaskList.isEmpty ? "No tasks scheduled yet" : todayTaskList)

        Provide:
        1. A 2-3 sentence morning greeting that briefly mentions yesterday's progress\(data.hasCalendarData ? " and today's schedule" : "")
        2. One sentence highlighting today's focus areas based on priorities\(data.hasCalendarData ? " and available time" : "")
        3. A brief motivational message based on streak and weekly progress

        Respond in JSON format only:
        {
            "summary": "<morning greeting with yesterday recap>",
            "todayFocus": "<today's priorities and focus>",
            "motivation": "<encouraging message>"
        }

        Keep tone warm, energizing, and action-oriented.
        """
    }

    private func parseMorningBriefingResponse(_ response: String, briefing: MorningBriefingData) -> (summary: String, todayFocus: String, motivation: String) {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (
                summary: getDefaultMorningSummary(briefing: briefing),
                todayFocus: getDefaultTodayFocus(briefing: briefing),
                motivation: getDefaultMorningMotivation(briefing: briefing)
            )
        }

        let summary = json["summary"] as? String ?? getDefaultMorningSummary(briefing: briefing)
        let todayFocus = json["todayFocus"] as? String ?? getDefaultTodayFocus(briefing: briefing)
        let motivation = json["motivation"] as? String ?? getDefaultMorningMotivation(briefing: briefing)

        return (summary: summary, todayFocus: todayFocus, motivation: motivation)
    }

    // MARK: - Default Morning Messages

    private func getDefaultMorningSummary(briefing: MorningBriefingData) -> String {
        if briefing.yesterdayCompleted > 0 {
            return "Good morning! Yesterday you completed \(briefing.yesterdayCompleted) tasks. Let's build on that momentum today."
        } else {
            return "Good morning! Today is a fresh start with \(briefing.todayTasks.count) tasks waiting for you."
        }
    }

    private func getDefaultTodayFocus(briefing: MorningBriefingData) -> String {
        if briefing.todayHighPriority > 0 {
            return "Focus on your \(briefing.todayHighPriority) high-priority tasks first."
        } else if briefing.todayOverdue > 0 {
            return "Start by clearing your \(briefing.todayOverdue) overdue tasks."
        } else if briefing.todayTasks.isEmpty {
            return "Plan your day by adding some tasks to tackle."
        } else {
            return "You have \(briefing.todayTasks.count) tasks lined up for today."
        }
    }

    private func getDefaultMorningMotivation(briefing: MorningBriefingData) -> String {
        let streak = briefing.weeklyStats.currentStreak
        if streak >= 7 {
            return "Amazing \(streak)-day streak! Keep the momentum going!"
        } else if streak >= 3 {
            return "\(streak) days strong! You're building great habits."
        } else if briefing.weeklyStats.averageCompletionRate >= 70 {
            return "Great week so far! You've got this."
        } else {
            return "Every day is a chance to be productive. Let's make today count!"
        }
    }
}
