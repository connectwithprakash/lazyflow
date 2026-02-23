import Foundation

/// Two-stage extraction pipeline: deterministic parsing + optional LLM enhancement
@MainActor
final class NoteParsingService: ObservableObject {
    static let shared = NoteParsingService()

    private let llmService = LLMService.shared
    private let contextService = AIContextService.shared
    private let learningService = AILearningService.shared
    private let categoryService = CategoryService.shared

    /// Maximum characters sent to LLM
    private let maxLLMInputLength = 1000

    /// LLM timeout in seconds
    private let llmTimeout: TimeInterval = 5.0

    private init() {}

    // MARK: - Public API

    /// Extract task drafts from a note's text
    /// Uses LLM when available, falls back to deterministic parsing
    func extractTasks(from text: String) async -> [TaskDraft] {
        let segments = deterministicParse(text)

        // Try LLM extraction if available
        if llmService.isReady {
            do {
                let (drafts, didParse) = try await withTimeout(seconds: llmTimeout) {
                    try await self.llmExtract(text: text, segments: segments)
                }
                // If LLM successfully parsed (even to empty), trust its result
                if didParse {
                    return drafts
                }
            } catch {
                // Fall through to deterministic fallback
            }
        }

        // Deterministic fallback: convert segments to drafts
        return segments.map { segment in
            TaskDraft(
                title: segment.text,
                dueDate: segment.parsedDate,
                dueTime: segment.parsedTime
            )
        }
    }

    // MARK: - Deterministic Parsing (Stage 1)

    /// Raw segment from deterministic parsing
    struct RawSegment {
        let text: String
        let parsedDate: Date?
        let parsedTime: Date?
    }

    /// Split text into segments on sentence/clause boundaries and parse dates
    func deterministicParse(_ text: String) -> [RawSegment] {
        let lines = splitIntoSegments(text)

        return lines.compactMap { line -> RawSegment? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count > 1 else { return nil }

            // Try to extract date from the segment
            if let parsed = Date.parse(from: trimmed) {
                let cleanTitle = parsed.cleanedTitle(from: trimmed)
                let title = cleanTitle.isEmpty ? trimmed : cleanTitle
                return RawSegment(
                    text: title,
                    parsedDate: parsed.date,
                    parsedTime: parsed.time
                )
            }

            return RawSegment(text: trimmed, parsedDate: nil, parsedTime: nil)
        }
    }

    /// Split text on sentence boundaries, newlines, and conjunctions
    private func splitIntoSegments(_ text: String) -> [String] {
        // First split on newlines
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var segments: [String] = []

        for line in lines {
            // Split on sentence-ending punctuation
            let sentencePattern = #"(?<=[.!?])\s+"#
            if let regex = try? NSRegularExpression(pattern: sentencePattern) {
                let range = NSRange(line.startIndex..., in: line)
                let sentences = regex.splitString(line, range: range)

                for sentence in sentences {
                    let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Split on ", and " conjunctions for compound sentences
                    let parts = trimmed.components(separatedBy: ", and ")
                    for part in parts {
                        let p = part.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !p.isEmpty {
                            // Remove trailing punctuation for cleaner task titles
                            let cleaned = p.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleaned.isEmpty {
                                segments.append(cleaned)
                            }
                        }
                    }
                }
            } else {
                segments.append(line)
            }
        }

        return segments
    }

    // MARK: - LLM Extraction (Stage 2)

    /// Returns (drafts, didParse) — didParse is true when JSON was valid (even if empty array)
    private func llmExtract(text: String, segments: [RawSegment]) async throws -> ([TaskDraft], Bool) {
        let truncatedText = String(text.prefix(maxLLMInputLength))
        let customCategories = categoryService.categories.map { $0.name }
        let lists = TaskListService.shared.lists
        let learningContext = learningService.getCorrectionsContext()

        let prompt = PromptTemplates.buildNoteExtractionPrompt(
            noteText: truncatedText,
            customCategories: customCategories,
            listNames: lists.map { $0.name },
            learningContext: learningContext
        )

        let response = try await llmService.complete(
            prompt: prompt,
            systemPrompt: PromptTemplates.noteExtractionSystemPrompt
        )

        return parseExtractionResponse(response, segments: segments, lists: lists)
    }

    /// Parse LLM JSON array response into TaskDrafts
    /// Returns (drafts, didParse) — didParse is true when JSON was valid (even if empty)
    private func parseExtractionResponse(
        _ response: String,
        segments: [RawSegment],
        lists: [TaskList]
    ) -> ([TaskDraft], Bool) {
        guard let data = PromptTemplates.extractJSONArray(from: response),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return ([], false)
        }

        let drafts = jsonArray.compactMap { json -> TaskDraft? in
            guard let rawTitle = json["title"] as? String else { return nil }
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            // Parse priority
            let priorityStr = json["priority"] as? String ?? "none"
            let priority: Priority
            switch priorityStr.lowercased() {
            case "urgent": priority = .urgent
            case "high": priority = .high
            case "medium": priority = .medium
            case "low": priority = .low
            default: priority = .none
            }

            // Parse category
            let categoryStr = json["category"] as? String ?? "uncategorized"
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
                if let custom = categoryService.getCategory(byName: categoryStr) {
                    customCategoryID = custom.id
                }
            }

            // Parse due date from LLM or merge from deterministic
            var dueDate: Date?
            var dueTime: Date?

            if let dueDateStr = json["due_date"] as? String, !dueDateStr.isEmpty {
                if let parsed = Date.parse(from: dueDateStr) {
                    dueDate = parsed.date
                    dueTime = parsed.time
                }
            }

            // If LLM didn't find a date, fuzzy-match against deterministic segments
            if dueDate == nil {
                let titleWords = Set(title.lowercased().split(separator: " ").map(String.init))
                let matchingSegment = segments.first { segment in
                    guard segment.parsedDate != nil else { return false }
                    let segmentWords = Set(segment.text.lowercased().split(separator: " ").map(String.init))
                    // Match if at least 2 significant words overlap
                    return titleWords.intersection(segmentWords).count >= min(2, segmentWords.count)
                }
                if let segment = matchingSegment {
                    dueDate = segment.parsedDate
                    dueTime = segment.parsedTime
                }
            }

            // Match list by name
            var listID: UUID?
            if let listName = json["list"] as? String, !listName.isEmpty {
                listID = lists.first { $0.name.lowercased() == listName.lowercased() }?.id
            }

            return TaskDraft(
                title: title,
                dueDate: dueDate,
                dueTime: dueTime,
                priority: priority,
                category: category,
                customCategoryID: customCategoryID,
                listID: listID
            )
        }
        return (drafts, true)
    }

    // MARK: - Timeout Helper

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NoteParsingError.timeout
            }

            guard let result = try await group.next() else {
                throw NoteParsingError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    enum NoteParsingError: Error {
        case timeout
        case parsingFailed
    }
}

// MARK: - NSRegularExpression Helper

private extension NSRegularExpression {
    func splitString(_ string: String, range: NSRange) -> [String] {
        var results: [String] = []
        var lastEnd = string.startIndex

        enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let matchRange = Range(match.range, in: string) else { return }

            let segment = String(string[lastEnd..<matchRange.lowerBound])
            if !segment.isEmpty {
                results.append(segment)
            }
            lastEnd = matchRange.upperBound
        }

        // Add remaining text
        let remaining = String(string[lastEnd...])
        if !remaining.isEmpty {
            results.append(remaining)
        }

        return results
    }
}
