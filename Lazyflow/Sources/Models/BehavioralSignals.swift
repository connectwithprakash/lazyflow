import Foundation

// MARK: - Time Bucket

enum TimeBucket: String, Codable, CaseIterable {
    case morning, afternoon, evening, night

    static func from(hour: Int) -> TimeBucket {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

// MARK: - Behavioral Signals

struct BehavioralSignals {

    struct TimePreference {
        let bucket: TimeBucket
        let support: Int
        let share: Double
    }

    struct CategoryAffinity {
        let category: TaskCategory
        let score: Int
        let support: Int
    }

    struct SnoozeHotspot {
        let category: TaskCategory
        let bucket: TimeBucket
        let count: Int
    }

    struct SkipReasonHotspot {
        enum Reason: String { case wrongTime, needsFocus }
        let reason: Reason
        let category: TaskCategory
        let count: Int
    }

    struct CompletionPeak {
        let category: TaskCategory
        let bucket: TimeBucket
        let count: Int
    }

    let totalEvents: Int
    let timePreference: TimePreference?
    let categoryAffinity: [CategoryAffinity]
    let snoozeHotspot: SnoozeHotspot?
    let skipReasonHotspots: [SkipReasonHotspot]
    let completionPeak: CompletionPeak?

    var isColdStart: Bool {
        totalEvents < 10 && completionPeak == nil
    }

    // MARK: - Extraction

    /// Extract behavioral signals from feedback events and completion patterns.
    /// Returns a cold start instance when there is insufficient data to generate signals.
    static func extract(from feedback: SuggestionFeedback, completionPatterns: CompletionPatterns) -> BehavioralSignals {
        let events = feedback.events
        let totalEvents = events.count
        let hasEnoughEvents = totalEvents >= 10

        // 1) Time preference — from positive engagement events
        var timePreference: TimePreference?
        if hasEnoughEvents {
            let positive = events.filter { isPositive($0.action) }
            if positive.count >= 6 {
                let counts = Dictionary(grouping: positive, by: { TimeBucket.from(hour: $0.hourOfDay) })
                    .mapValues(\.count)
                // Deterministic tie-break: highest count, then earliest bucket in case order
                if let (bucket, count) = counts.max(by: { a, b in
                    if a.value != b.value { return a.value < b.value }
                    return TimeBucket.allCases.firstIndex(of: a.key)! > TimeBucket.allCases.firstIndex(of: b.key)!
                }) {
                    let share = Double(count) / Double(positive.count)
                    if share >= 0.40 {
                        timePreference = TimePreference(bucket: bucket, support: positive.count, share: share)
                    }
                }
            }
        }

        // 2) Category affinity — net engagement score per category
        var categoryAffinity: [CategoryAffinity] = []
        if hasEnoughEvents {
            var scoreByCategory: [TaskCategory: Int] = [:]
            var supportByCategory: [TaskCategory: Int] = [:]

            for event in events {
                supportByCategory[event.taskCategory, default: 0] += 1
                scoreByCategory[event.taskCategory, default: 0] += affinityDelta(for: event.action)
            }

            categoryAffinity = supportByCategory.compactMap { category, support in
                guard support >= 3 else { return nil }
                let score = scoreByCategory[category] ?? 0
                guard score >= 2 else { return nil }
                return CategoryAffinity(category: category, score: score, support: support)
            }
            // Deterministic sort: score desc, support desc, category rawValue asc
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.support != $1.support { return $0.support > $1.support }
                return $0.category.rawValue < $1.category.rawValue
            }

            if categoryAffinity.count > 2 {
                categoryAffinity = Array(categoryAffinity.prefix(2))
            }
        }

        // 3) Snooze hotspot — most snoozed category+time combination
        var snoozeHotspot: SnoozeHotspot?
        if hasEnoughEvents {
            let snoozes = events.filter { $0.action.isSnooze }
            if snoozes.count >= 4 {
                let counts = Dictionary(
                    grouping: snoozes,
                    by: { "\($0.taskCategory.rawValue)_\(TimeBucket.from(hour: $0.hourOfDay).rawValue)" }
                ).mapValues(\.count)

                // Deterministic tie-break: highest count, then lexicographic key
                if let (key, count) = counts.max(by: { a, b in
                    if a.value != b.value { return a.value < b.value }
                    return a.key > b.key
                }),
                   count >= 3 {
                    snoozeHotspot = parseSnoozeKey(key, count: count)
                }
            }
        }

        // 4) Skip reason hotspots
        var skipReasonHotspots: [SkipReasonHotspot] = []
        if hasEnoughEvents {
            let wrongTime = events.filter { $0.action == .skippedWrongTime }
            if wrongTime.count >= 3,
               let (category, count) = topCategory(in: wrongTime),
               count >= 3 {
                skipReasonHotspots.append(
                    SkipReasonHotspot(reason: .wrongTime, category: category, count: count)
                )
            }

            let needsFocus = events.filter { $0.action == .skippedNeedsFocus }
            if needsFocus.count >= 3,
               let (category, count) = topCategory(in: needsFocus),
               count >= 3 {
                skipReasonHotspots.append(
                    SkipReasonHotspot(reason: .needsFocus, category: category, count: count)
                )
            }
        }

        // 5) Completion peak — from CompletionPatterns.categoryTimePatterns
        //    Parse all valid entries first, then find the max among them.
        var completionPeak: CompletionPeak?
        let validPeaks: [(category: TaskCategory, bucket: TimeBucket, count: Int)] =
            completionPatterns.categoryTimePatterns.compactMap { key, count in
                guard count >= 4,
                      let parsed = parseCategoryHourKey(key) else { return nil }
                return (parsed.category, TimeBucket.from(hour: parsed.hour), count)
            }
        if let best = validPeaks.max(by: { a, b in
            if a.count != b.count { return a.count < b.count }
            if a.category.rawValue != b.category.rawValue { return a.category.rawValue > b.category.rawValue }
            let aBucketIdx = TimeBucket.allCases.firstIndex(of: a.bucket) ?? 0
            let bBucketIdx = TimeBucket.allCases.firstIndex(of: b.bucket) ?? 0
            return aBucketIdx > bBucketIdx
        }) {
            completionPeak = CompletionPeak(category: best.category, bucket: best.bucket, count: best.count)
        }

        return BehavioralSignals(
            totalEvents: totalEvents,
            timePreference: timePreference,
            categoryAffinity: categoryAffinity,
            snoozeHotspot: snoozeHotspot,
            skipReasonHotspots: skipReasonHotspots,
            completionPeak: completionPeak
        )
    }

    // MARK: - Prompt Generation

    func toPromptString() -> String {
        if isColdStart {
            return ""
        }

        var signalLines: [String] = []

        if let t = timePreference {
            let pct = Int((t.share * 100).rounded())
            signalLines.append("- Prefers engaging in the \(t.bucket.rawValue) (\(pct)% of starts, n=\(t.support)).")
        }

        if !categoryAffinity.isEmpty {
            let text = categoryAffinity.map {
                "\($0.category.displayName) (+\($0.score), n=\($0.support))"
            }.joined(separator: ", ")
            signalLines.append("- Strongest categories: \(text).")
        }

        if let s = snoozeHotspot {
            signalLines.append("- Often snoozed: \(s.category.displayName) in the \(s.bucket.rawValue) (n=\(s.count)).")
        }

        for hotspot in skipReasonHotspots {
            switch hotspot.reason {
            case .wrongTime:
                signalLines.append("- Skips \(hotspot.category.displayName) as 'wrong time' (n=\(hotspot.count)).")
            case .needsFocus:
                signalLines.append("- Skips \(hotspot.category.displayName) as 'needs focus' (n=\(hotspot.count), weak signal).")
            }
        }

        if let c = completionPeak {
            signalLines.append("- Completes \(c.category.displayName) tasks most in the \(c.bucket.rawValue) (n=\(c.count)).")
        }

        // Only emit context when at least one concrete signal is present
        guard !signalLines.isEmpty else { return "" }

        var lines = ["User behavior from \(totalEvents) interactions:"]
        lines.append(contentsOf: signalLines)
        lines.append("Use these as soft preferences. Keep reordering within 2 positions unless strongly justified.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private static func isPositive(_ action: FeedbackAction) -> Bool {
        action == .startedImmediately || action == .viewedDetails
    }

    private static func affinityDelta(for action: FeedbackAction) -> Int {
        switch action {
        case .startedImmediately: return 2
        case .viewedDetails: return 1
        case .snoozed1Hour, .snoozedEvening, .snoozedTomorrow: return -1
        case .skippedNotRelevant, .skippedWrongTime, .skippedNeedsFocus: return -2
        }
    }

    private static func topCategory(in events: [FeedbackEvent]) -> (TaskCategory, Int)? {
        let counts = Dictionary(grouping: events, by: \.taskCategory).mapValues(\.count)
        // Deterministic tie-break: highest count, then lowest category rawValue
        return counts.max(by: { a, b in
            if a.value != b.value { return a.value < b.value }
            return a.key.rawValue > b.key.rawValue
        })
    }

    private static func parseSnoozeKey(_ key: String, count: Int) -> SnoozeHotspot? {
        // Key format: "rawValue_bucketName" e.g. "1_morning"
        guard let underscoreIndex = key.firstIndex(of: "_") else { return nil }
        let rawStr = String(key[key.startIndex..<underscoreIndex])
        let bucketStr = String(key[key.index(after: underscoreIndex)...])
        guard let raw = Int16(rawStr),
              let category = TaskCategory(rawValue: raw),
              let bucket = TimeBucket(rawValue: bucketStr) else {
            return nil
        }
        return SnoozeHotspot(category: category, bucket: bucket, count: count)
    }

    private static func parseCategoryHourKey(_ key: String) -> (category: TaskCategory, hour: Int)? {
        // Key format: "rawValue_hour" e.g. "1_9"
        let parts = key.split(separator: "_")
        guard parts.count == 2,
              let raw = Int16(String(parts[0])),
              let hour = Int(String(parts[1])),
              (0...23).contains(hour),
              let category = TaskCategory(rawValue: raw) else {
            return nil
        }
        return (category, hour)
    }
}
