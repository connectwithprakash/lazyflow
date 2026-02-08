import Foundation

/// Centralized prompt templates optimized for Apple Intelligence on-device model
/// Following Apple's WWDC25 prompt design best practices
enum PromptTemplates {

    // MARK: - System Prompts (Instructions)

    /// System prompt for task analysis - provides role and behavioral guidelines
    static let taskAnalysisSystemPrompt = """
    You are a productivity coach helping users organize tasks effectively.

    Guidelines:
    - Be concise: explanations should be ONE sentence
    - Be practical: suggest realistic time estimates
    - Be encouraging: frame suggestions positively
    - Respect patterns: consider user's past preferences when provided

    DO NOT include personal opinions or unnecessary elaboration.
    DO NOT make up facts or reference external information.
    NEVER include sensitive, harmful, or inappropriate content.

    Respond ONLY in the specified JSON format.
    """

    /// System prompt for daily summaries
    static let dailySummarySystemPrompt = """
    You are a supportive productivity assistant helping users reflect on their day.

    Guidelines:
    - Be encouraging and positive
    - Keep summaries to 2-3 sentences
    - Celebrate progress, no matter how small
    - Suggest actionable next steps when appropriate

    Respond ONLY in the specified JSON format.
    """

    /// System prompt for morning briefings
    static let morningBriefingSystemPrompt = """
    You are a supportive productivity assistant helping users start their day.

    Guidelines:
    - Be warm and energizing
    - Generate encouraging, actionable briefings
    - Reference yesterday's progress to build momentum
    - Highlight priorities and suggest focus areas

    Respond ONLY in the specified JSON format.
    """

    // MARK: - Duration Estimation Prompt

    /// Build prompt for estimating task duration
    static func buildDurationEstimationPrompt(title: String, notes: String?) -> String {
        var prompt = """
        Estimate how long this task will take in minutes.

        Task: \(title)
        """

        if let notes = notes, !notes.isEmpty {
            prompt += "\nDetails: \(notes)"
        }

        prompt += """


        Example:
        Task: "Buy groceries"
        Response: {"estimated_minutes": 45, "confidence": "high", "reasoning": "Typical grocery trip including travel."}

        Respond in JSON format with reasoning in one sentence:
        {
            "estimated_minutes": <number between 5 and 480>,
            "confidence": "<low|medium|high>",
            "reasoning": "<brief one-sentence explanation>"
        }
        """

        return prompt
    }

    // MARK: - Priority Suggestion Prompt

    /// Build prompt for suggesting task priority
    static func buildPrioritySuggestionPrompt(title: String, notes: String?, dueDate: Date?) -> String {
        var prompt = """
        Suggest a priority level for this task.

        Task: \(title)
        """

        if let notes = notes, !notes.isEmpty {
            prompt += "\nDetails: \(notes)"
        }

        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            prompt += "\nDue: \(formatter.string(from: dueDate))"
        }

        prompt += """


        Priority levels:
        - none: No specific priority
        - low: Can be done anytime, not urgent
        - medium: Should be done soon
        - high: Important, needs attention this week
        - urgent: Critical, needs immediate attention

        Example:
        Task: "Submit tax forms"
        Due: Tomorrow
        Response: {"priority": "urgent", "reasoning": "Deadline is tomorrow, cannot be missed."}

        Respond in JSON format with reasoning in one sentence:
        {
            "priority": "<none|low|medium|high|urgent>",
            "reasoning": "<brief one-sentence explanation>"
        }
        """

        return prompt
    }

    // MARK: - Task Ordering Prompt

    /// Build prompt for suggesting optimal task order
    static func buildTaskOrderingPrompt(tasks: [(index: Int, title: String, dueDate: Date?, priority: String)]) -> String {
        let taskList = tasks.map { task in
            var item = "\(task.index). \(task.title)"
            if let dueDate = task.dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                item += " (Due: \(formatter.string(from: dueDate)))"
            }
            item += " [Priority: \(task.priority)]"
            return item
        }.joined(separator: "\n")

        return """
        Suggest the best order to complete these tasks today.

        Tasks:
        \(taskList)

        Consider: due dates first, then priority, then quick wins (short tasks).

        Respond in JSON format:
        {
            "order": [<task numbers in suggested order>],
            "reasoning": "<brief one-sentence explanation>"
        }
        """
    }

    // MARK: - Full Analysis Prompt

    /// Build comprehensive task analysis prompt with few-shot examples
    static func buildFullAnalysisPrompt(task: Task, learningContext: String, customCategories: [String]) -> String {
        // Build category list
        let systemCategories = "work, personal, health, finance, shopping, errands, learning, home"
        let allCategories = customCategories.isEmpty
            ? systemCategories
            : systemCategories + ", " + customCategories.joined(separator: ", ")

        var prompt = """
        Analyze this task and provide suggestions.

        Task: \(task.title)
        """

        if let notes = task.notes, !notes.isEmpty {
            prompt += "\nDetails: \(notes)"
        }

        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            prompt += "\nDue: \(formatter.string(from: dueDate))"
        }

        prompt += "\nCurrent Priority: \(task.priority.displayName)"

        // Add learning context if available
        if !learningContext.isEmpty {
            prompt += "\n\nUser Preferences:\n\(learningContext)"
        }

        prompt += """


        Available categories: \(allCategories)

        If no existing category fits well, you may propose creating a new one.

        Examples:
        Task: "Call mom"
        Response: {"estimated_minutes": 15, "suggested_priority": "medium", "best_time": "evening", "category": "personal", "proposed_new_category": null, "refined_title": null, "suggested_description": null, "subtasks": [], "tips": "Find a quiet spot."}

        Task: "Prepare presentation for Monday meeting"
        Response: {"estimated_minutes": 90, "suggested_priority": "high", "best_time": "morning", "category": "work", "proposed_new_category": null, "refined_title": null, "suggested_description": "Create slides and rehearse key points", "subtasks": ["Outline main points", "Create slides", "Practice delivery"], "tips": "Start with the conclusion."}

        Task: "Volunteer at food bank"
        Response: {"estimated_minutes": 180, "suggested_priority": "medium", "best_time": "morning", "category": "uncategorized", "proposed_new_category": {"name": "Volunteering", "color_hex": "#4CAF50", "icon_name": "heart.fill"}, "refined_title": null, "suggested_description": null, "subtasks": [], "tips": "Wear comfortable shoes."}

        Provide analysis. Only include subtasks for complex tasks that benefit from breakdown:
        {
            "estimated_minutes": <number between 5 and 480>,
            "suggested_priority": "<none|low|medium|high|urgent>",
            "best_time": "<morning|afternoon|evening|anytime>",
            "category": "<one of the available categories, or 'uncategorized' if proposing new>",
            "proposed_new_category": <null, or {"name": "...", "color_hex": "#RRGGBB", "icon_name": "sf.symbol.name"} if suggesting new category>,
            "refined_title": "<improved title or null if original is good>",
            "suggested_description": "<helpful description or null if not needed>",
            "subtasks": [<empty array for simple tasks, up to 3 items for complex tasks>],
            "tips": "<one brief productivity tip, 10 words or less>"
        }
        """

        return prompt
    }

    // MARK: - Response Parsing

    /// Parse duration estimation response
    static func parseDurationResponse(_ response: String) -> TaskEstimate {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return TaskEstimate(estimatedMinutes: 30, confidence: .low, reasoning: "Could not parse response")
        }

        // Accept Int or Double (round decimals)
        var minutes: Int
        if let intValue = json["estimated_minutes"] as? Int {
            minutes = intValue
        } else if let doubleValue = json["estimated_minutes"] as? Double {
            minutes = Int(doubleValue.rounded())
        } else {
            minutes = 30
        }

        // Clamp to prompt-specified range (5-480 minutes)
        minutes = max(5, min(480, minutes))

        let confidenceStr = json["confidence"] as? String ?? "low"
        let reasoning = json["reasoning"] as? String ?? ""

        let confidence: TaskEstimate.Confidence
        switch confidenceStr.lowercased() {
        case "high": confidence = .high
        case "medium": confidence = .medium
        default: confidence = .low
        }

        return TaskEstimate(estimatedMinutes: minutes, confidence: confidence, reasoning: reasoning)
    }

    /// Parse priority suggestion response
    static func parsePriorityResponse(_ response: String) -> PrioritySuggestion {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return PrioritySuggestion(priority: .medium, reasoning: "Could not parse response")
        }

        let priorityStr = json["priority"] as? String ?? "medium"
        let reasoning = json["reasoning"] as? String ?? ""

        let priority: Priority
        switch priorityStr.lowercased() {
        case "urgent": priority = .urgent
        case "high": priority = .high
        case "medium": priority = .medium
        case "low": priority = .low
        default: priority = .none
        }

        return PrioritySuggestion(priority: priority, reasoning: reasoning)
    }

    /// Parse full task analysis response
    static func parseFullAnalysisResponse(_ response: String) -> TaskAnalysis {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return TaskAnalysis.default
        }

        // Accept Int or Double (round decimals)
        var minutes: Int
        if let intValue = json["estimated_minutes"] as? Int {
            minutes = intValue
        } else if let doubleValue = json["estimated_minutes"] as? Double {
            minutes = Int(doubleValue.rounded())
        } else {
            minutes = 30
        }
        // Clamp to prompt-specified range (5-480 minutes)
        minutes = max(5, min(480, minutes))

        let priorityStr = json["suggested_priority"] as? String ?? "medium"
        let priority: Priority
        switch priorityStr.lowercased() {
        case "urgent": priority = .urgent
        case "high": priority = .high
        case "medium": priority = .medium
        case "low": priority = .low
        default: priority = .none
        }

        let bestTimeStr = json["best_time"] as? String ?? "anytime"
        let bestTime: TaskAnalysis.BestTime
        switch bestTimeStr.lowercased() {
        case "morning": bestTime = .morning
        case "afternoon": bestTime = .afternoon
        case "evening": bestTime = .evening
        default: bestTime = .anytime
        }

        let categoryStr = json["category"] as? String ?? "uncategorized"

        // Match system category
        var category: TaskCategory = .uncategorized
        var customCategoryID: UUID?

        switch categoryStr.lowercased() {
        case "work": category = .work
        case "personal": category = .personal
        case "health": category = .health
        case "finance": category = .finance
        case "shopping": category = .shopping
        case "errands": category = .errands
        case "learning": category = .learning
        case "home": category = .home
        default:
            // Check for custom category match
            if let customCategory = CategoryService.shared.getCategory(byName: categoryStr) {
                customCategoryID = customCategory.id
                category = .uncategorized
            }
        }

        // Limit subtasks to 3
        var subtasks = json["subtasks"] as? [String] ?? []
        if subtasks.count > 3 {
            subtasks = Array(subtasks.prefix(3))
        }

        let tips = json["tips"] as? String ?? ""

        // Handle null values for optional fields
        let refinedTitle: String?
        if let title = json["refined_title"], !(title is NSNull) {
            refinedTitle = title as? String
        } else {
            refinedTitle = nil
        }

        let suggestedDescription: String?
        if let desc = json["suggested_description"], !(desc is NSNull) {
            suggestedDescription = desc as? String
        } else {
            suggestedDescription = nil
        }

        // Parse proposed new category (only when category is uncategorized to avoid conflicting guidance)
        let proposedNewCategory: ProposedCategory?
        if category == .uncategorized && customCategoryID == nil,
           let proposedJson = json["proposed_new_category"] as? [String: Any],
           let name = proposedJson["name"] as? String,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let colorHex = proposedJson["color_hex"] as? String ?? ProposedCategory.defaultColorHex
            let iconName = proposedJson["icon_name"] as? String ?? ProposedCategory.defaultIconName
            proposedNewCategory = ProposedCategory(name: trimmedName, colorHex: colorHex, iconName: iconName)
        } else {
            proposedNewCategory = nil
        }

        return TaskAnalysis(
            estimatedMinutes: minutes,
            suggestedPriority: priority,
            bestTime: bestTime,
            suggestedCategory: category,
            suggestedCustomCategoryID: customCategoryID,
            proposedNewCategory: proposedNewCategory,
            subtasks: subtasks,
            tips: tips,
            refinedTitle: refinedTitle,
            suggestedDescription: suggestedDescription
        )
    }

    // MARK: - Daily Summary Prompt

    /// Build prompt for daily summary generation
    static func buildDailySummaryPrompt(
        tasksCompleted: Int,
        totalPlanned: Int,
        topCategory: String?,
        timeWorked: String,
        currentStreak: Int,
        taskList: String,
        learningContext: String,
        isFirstDay: Bool = false,
        timeOfDay: String = "evening"
    ) -> String {
        let contextSection = learningContext.isEmpty ? "" : """

        User Learning Context:
        \(learningContext)

        """

        // Build scenario-specific guidance
        var scenarioGuidance = ""
        if tasksCompleted == 0 {
            scenarioGuidance = """

        IMPORTANT - Zero tasks completed scenario:
        - Do NOT say "positive start" or "great progress" - be honest
        - Acknowledge the day without accomplishments gently
        - Focus on tomorrow being a fresh start
        - Suggest starting with one small task tomorrow

        """
        } else if tasksCompleted >= totalPlanned && totalPlanned > 0 {
            scenarioGuidance = """

        IMPORTANT - All tasks completed scenario:
        - Celebrate this genuine achievement
        - Reference the specific completion rate (\(tasksCompleted)/\(totalPlanned))
        - Acknowledge the effort

        """
        }

        if isFirstDay {
            scenarioGuidance += """

        IMPORTANT - First day user:
        - Welcome them warmly
        - Don't reference "yesterday" or past performance
        - Focus on starting their productivity journey

        """
        }

        return """
        Generate a brief daily summary for a productivity app user.

        Time of day: \(timeOfDay)

        Today's Stats:
        - Tasks completed: \(tasksCompleted) of \(totalPlanned) planned
        - Top category: \(topCategory ?? "Various")
        - Time worked: \(timeWorked)
        - Current streak: \(currentStreak) days

        Completed tasks:
        \(taskList.isEmpty ? "No tasks completed" : taskList)
        \(scenarioGuidance)\(contextSection)
        CRITICAL RULES:
        - Your message MUST match the actual data above
        - If tasks completed is 0, do NOT use positive words like "great", "awesome", "positive start"
        - If tasks completed is 0, acknowledge it honestly and kindly
        - Never say someone made "progress" if they completed zero tasks
        - Be encouraging about FUTURE potential, not false praise for the past

        PERSONALIZATION RULES:
        - Reference 1-2 specific task names from the completed tasks list above if available (do not just say "tasks")
        - Mention the top category by name if available
        - Adjust greeting and tone for \(timeOfDay): morning=energizing, afternoon=encouraging, evening=reflective and wind-down, night=brief and restful

        Provide:
        1. A 2-3 sentence summary that honestly reflects their day, mentioning specific task names when available
        2. One sentence of encouragement focused on tomorrow or their potential

        Respond in JSON format only:
        {
            "summary": "<honest recap of day matching the stats>",
            "encouragement": "<forward-looking motivating message>"
        }

        Keep tone warm, honest, and supportive.
        """
    }

    /// Parse daily summary response
    static func parseDailySummaryResponse(_ response: String) -> (summary: String?, encouragement: String?) {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }

        let summary = json["summary"] as? String
        let encouragement = json["encouragement"] as? String

        return (summary: summary, encouragement: encouragement)
    }

    // MARK: - Morning Briefing Prompt

    /// Build prompt for morning briefing generation
    static func buildMorningBriefingPrompt(
        yesterdayCompleted: Int,
        yesterdayPlanned: Int,
        yesterdayTopCategory: String?,
        todayTaskCount: Int,
        todayHighPriority: Int,
        todayOverdue: Int,
        todayTimeEstimate: String,
        weeklyTasksCompleted: Int,
        weeklyCompletionRate: String,
        currentStreak: Int,
        todayTaskList: String,
        scheduleContext: String?,
        learningContext: String,
        hasCalendarData: Bool,
        isFirstDay: Bool = false,
        streakJustBroken: Bool = false,
        previousStreak: Int = 0,
        timeOfDay: String = "morning"
    ) -> String {
        let scheduleSection = scheduleContext.map { "\n\nToday's Calendar:\n\($0)" } ?? ""
        let contextSection = learningContext.isEmpty ? "" : """

        User Learning Context:
        \(learningContext)

        """

        // Build scenario-specific guidance
        var scenarioGuidance = ""

        // Handle yesterday's performance
        if yesterdayCompleted == 0 && yesterdayPlanned > 0 {
            scenarioGuidance += """

        IMPORTANT - Yesterday had zero completions:
        - Do NOT say "positive start", "great progress", or celebrate yesterday
        - Acknowledge yesterday briefly and pivot to today's fresh start
        - Focus on today's opportunities, not yesterday's shortcomings

        """
        } else if yesterdayCompleted == 0 && yesterdayPlanned == 0 {
            scenarioGuidance += """

        IMPORTANT - No tasks were planned yesterday:
        - Skip mentioning yesterday entirely
        - Focus on welcoming the new day and today's plan

        """
        } else if yesterdayCompleted >= yesterdayPlanned && yesterdayPlanned > 0 {
            scenarioGuidance += """

        IMPORTANT - Yesterday was fully productive:
        - Genuinely celebrate completing all planned tasks
        - Reference the achievement to build momentum

        """
        }

        // Handle first-time users
        if isFirstDay {
            scenarioGuidance += """

        IMPORTANT - First day user:
        - Welcome them warmly to the app
        - Don't reference "yesterday" at all
        - Focus on starting their productivity journey today

        """
        }

        // Handle broken streaks
        if streakJustBroken && previousStreak > 0 {
            scenarioGuidance += """

        IMPORTANT - Streak was recently broken (was \(previousStreak) days):
        - Be empathetic, not guilt-inducing
        - Streaks reset but progress and habits remain
        - Focus on rebuilding, not what was lost

        """
        }

        // Handle overdue tasks
        if todayOverdue > 0 {
            scenarioGuidance += """

        IMPORTANT - Has \(todayOverdue) overdue tasks:
        - Acknowledge overdue items without judgment
        - Suggest prioritizing them today
        - Frame as opportunity to clear the backlog

        """
        }

        // "Morning briefing" is the product feature name; timeOfDay adapts the tone
        // so it reads naturally even when opened in the afternoon or evening.
        return """
        Generate a morning briefing for a productivity app user.

        Time of day: \(timeOfDay)

        Yesterday's Results:
        - Completed: \(yesterdayCompleted) of \(yesterdayPlanned) tasks
        - Top category: \(yesterdayTopCategory ?? "Various")

        Today's Plan:
        - Total tasks: \(todayTaskCount)
        - High priority: \(todayHighPriority)
        - Overdue: \(todayOverdue)
        - Estimated time: \(todayTimeEstimate)\(scheduleSection)

        Weekly Progress:
        - Tasks completed this week: \(weeklyTasksCompleted)
        - Completion rate: \(weeklyCompletionRate)
        - Current streak: \(currentStreak) days

        Today's Top Priorities:
        \(todayTaskList.isEmpty ? "No tasks scheduled yet" : todayTaskList)
        \(scenarioGuidance)\(contextSection)
        CRITICAL RULES:
        - Your message MUST accurately reflect the data above
        - If yesterday had 0 completions, do NOT use words like "great start", "positive", "awesome"
        - If yesterday had 0 completions, acknowledge it honestly then pivot to today
        - Never claim someone made "progress" when they completed zero tasks
        - Match your enthusiasm level to the actual metrics
        - Be encouraging about TODAY and the future, not falsely positive about poor past results

        PERSONALIZATION RULES:
        - Reference specific task names from the priorities list above if available (do not just say "your tasks")
        - Mention the top category by name when relevant
        - Adjust greeting and tone for \(timeOfDay): morning=energizing, afternoon=encouraging, evening=reflective and wind-down, night=brief and restful

        Provide:
        1. A 2-3 sentence greeting that honestly reflects yesterday\(hasCalendarData ? " and today's schedule" : ""), referencing specific task names when available
        2. One sentence highlighting today's focus areas based on priorities\(hasCalendarData ? " and available time" : ""), naming specific tasks when available
        3. A brief motivational message about today's potential

        Respond in JSON format only:
        {
            "summary": "<honest greeting matching the stats>",
            "todayFocus": "<today's priorities and focus>",
            "motivation": "<forward-looking encouraging message>"
        }

        Keep tone warm, honest, and action-oriented.
        """
    }

    /// Parse morning briefing response
    static func parseMorningBriefingResponse(_ response: String) -> (summary: String?, todayFocus: String?, motivation: String?) {
        guard let data = extractJSON(from: response),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil, nil)
        }

        let summary = json["summary"] as? String
        let todayFocus = json["todayFocus"] as? String
        let motivation = json["motivation"] as? String

        return (summary: summary, todayFocus: todayFocus, motivation: motivation)
    }

    // MARK: - Helpers

    /// Extract JSON from response that might contain extra text
    private static func extractJSON(from response: String) -> Data? {
        // Try direct parsing first
        if let data = response.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        // Try to find JSON in the response
        let pattern = "\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range, in: response) {
            let jsonString = String(response[range])
            return jsonString.data(using: .utf8)
        }

        return nil
    }
}
