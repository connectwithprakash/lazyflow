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
    private let maxLLMInputLength = AppConstants.Limits.maxLLMInputLength

    /// LLM timeout in seconds
    private let llmTimeout: TimeInterval = AppConstants.Timing.llmTimeout

    private init() {}

    // MARK: - Public API

    /// Extract task drafts from a note's text
    /// Uses LLM when available, falls back to deterministic parsing
    func extractTasks(from text: String) async -> [TaskDraft] {
        let hierarchical = deterministicParseHierarchical(text)
        let deterministicHasHierarchy = hierarchical.contains { !$0.children.isEmpty }

        // Flatten for LLM segment matching
        let flatSegments = hierarchical.flatMap { group -> [RawSegment] in
            [group.parent] + group.children
        }

        // Try LLM extraction if available
        if llmService.isReady {
            do {
                let (drafts, didParse) = try await withTimeout(seconds: llmTimeout) {
                    try await self.llmExtract(text: text, segments: flatSegments)
                }
                if didParse {
                    let llmHasHierarchy = drafts.contains { !$0.subtasks.isEmpty }

                    // If deterministic detected hierarchy but LLM flattened it,
                    // merge LLM metadata into the deterministic structure
                    if deterministicHasHierarchy && !llmHasHierarchy {
                        return mergeHierarchy(
                            deterministicGroups: hierarchical,
                            llmDrafts: drafts
                        )
                    }
                    return drafts
                }
            } catch {
                // Fall through to deterministic fallback
            }
        }

        // Deterministic fallback: convert hierarchical segments to drafts with subtasks
        return hierarchical.map { group in
            let subtaskDrafts = group.children.map { child in
                TaskDraft(
                    title: child.text,
                    dueDate: child.parsedDate,
                    dueTime: child.parsedTime
                )
            }
            return TaskDraft(
                title: group.parent.text,
                dueDate: group.parent.parsedDate,
                dueTime: group.parent.parsedTime,
                subtasks: subtaskDrafts
            )
        }
    }

    /// Merge deterministic hierarchy structure with LLM-enriched metadata.
    /// Uses deterministic parent/child grouping but takes LLM's categories, priorities, etc.
    func mergeHierarchy(
        deterministicGroups: [HierarchicalSegment],
        llmDrafts: [TaskDraft]
    ) -> [TaskDraft] {
        // Index LLM drafts by lowercase title for fuzzy matching
        let llmIndex = Dictionary(
            llmDrafts.map { (normalizeTitle($0.title), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return deterministicGroups.map { group in
            let parentTitle = group.parent.text
            let parentMatch = findMatch(for: parentTitle, in: llmIndex)

            let subtaskDrafts = group.children.map { child -> TaskDraft in
                let childMatch = findMatch(for: child.text, in: llmIndex)
                return TaskDraft(
                    title: childMatch?.title ?? child.text,
                    dueDate: childMatch?.dueDate ?? child.parsedDate,
                    dueTime: childMatch?.dueTime ?? child.parsedTime,
                    priority: childMatch?.priority ?? .none
                )
            }

            return TaskDraft(
                title: parentMatch?.title ?? parentTitle,
                dueDate: parentMatch?.dueDate ?? group.parent.parsedDate,
                dueTime: parentMatch?.dueTime ?? group.parent.parsedTime,
                priority: parentMatch?.priority ?? .none,
                category: parentMatch?.category ?? .uncategorized,
                customCategoryID: parentMatch?.customCategoryID,
                listID: parentMatch?.listID,
                subtasks: subtaskDrafts
            )
        }
    }

    private func normalizeTitle(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Find best matching LLM draft for a deterministic segment title
    private func findMatch(for title: String, in index: [String: TaskDraft]) -> TaskDraft? {
        let normalized = normalizeTitle(title)
        // Exact match
        if let match = index[normalized] { return match }
        // Substring match — find LLM draft whose title contains (or is contained by) the segment
        let titleWords = Set(normalized.split(separator: " ").map(String.init))
        return index.values.first { draft in
            let draftWords = Set(normalizeTitle(draft.title).split(separator: " ").map(String.init))
            let overlap = titleWords.intersection(draftWords).count
            return overlap >= min(2, min(titleWords.count, draftWords.count))
        }
    }

    // MARK: - Deterministic Parsing (Stage 1)

    /// Raw segment from deterministic parsing
    struct RawSegment {
        let text: String
        let parsedDate: Date?
        let parsedTime: Date?
    }

    /// A parent segment with optional child segments (one level deep)
    struct HierarchicalSegment {
        let parent: RawSegment
        let children: [RawSegment]
    }

    /// Split text into segments on sentence/clause boundaries and parse dates (flat — no hierarchy)
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

    /// Parse text into hierarchical segments, detecting parent-child relationships
    func deterministicParseHierarchical(_ text: String) -> [HierarchicalSegment] {
        let hierarchy = detectHierarchy(text)

        // If hierarchy was detected, use it
        if !hierarchy.isEmpty {
            return hierarchy.map { group in
                let parentSegment = makeSegment(from: group.parent)
                let childSegments = group.children.compactMap { child -> RawSegment? in
                    let seg = makeSegment(from: child)
                    guard seg.text.count > 1 else { return nil }
                    return seg
                }
                return HierarchicalSegment(parent: parentSegment, children: childSegments)
            }.filter { $0.parent.text.count > 1 }
        }

        // No hierarchy detected — fall through to flat parsing
        let flatSegments = deterministicParse(text)
        return flatSegments.map { HierarchicalSegment(parent: $0, children: []) }
    }

    // MARK: - Hierarchy Detection

    /// Intermediate structure for raw line grouping before date parsing
    struct RawLineGroup {
        let parent: String
        let children: [String]
    }

    /// Regex pattern for child line prefixes: checkboxes, bullets, numbered lists
    /// Checkboxes must come first since `- [ ]` would otherwise match `- ` prefix
    /// Includes en-dash (–) and em-dash (—) since iOS may auto-substitute these
    private static let childPrefixPattern = #"^(\s*[-–—*•]\s\[[ x]\]\s+|\s*[-–—*•]\s+|\s*\d+\.\s+)"#

    /// Detect if a line is a "child" line (bullet, number, checkbox, or indented)
    private func isChildLine(_ line: String) -> Bool {
        // Check for bullet/number/checkbox prefix
        if let regex = try? NSRegularExpression(pattern: Self.childPrefixPattern),
           regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return true
        }
        // Check for indentation (2+ spaces or tab) without being a bullet
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && (line.hasPrefix("  ") || line.hasPrefix("\t")) {
            return true
        }
        return false
    }

    /// Strip child prefix (bullet, number, checkbox) from a line
    private func stripChildPrefix(_ line: String) -> String {
        // Match against original line (preserving leading spaces) to ensure prefix regex works
        if let regex = try? NSRegularExpression(pattern: Self.childPrefixPattern) {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range) {
                let matchEnd = line.index(line.startIndex, offsetBy: match.range.length)
                return String(line[matchEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if a line is a colon header (e.g., "Groceries:")
    private func isColonHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix(":") && trimmed.count > 1 && !isChildLine(line)
    }

    /// Strip trailing colon from a header line
    private func stripColonSuffix(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(":") {
            return String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    /// Detect parent-child hierarchy patterns in text.
    /// Returns empty array if no hierarchy is found (caller should fall back to flat parsing).
    func detectHierarchy(_ text: String) -> [RawLineGroup] {
        let lines = text.components(separatedBy: .newlines)

        // Quick check: does this text have any child-like lines at all?
        let hasChildLines = lines.contains { isChildLine($0) }
        guard hasChildLines else { return [] }

        // Check if ALL non-empty lines are child lines (no parent header)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let allAreChildren = nonEmptyLines.allSatisfy { isChildLine($0) }
        if allAreChildren {
            // No parent header — treat as flat independent tasks
            return []
        }

        var groups: [RawLineGroup] = []
        var currentParent: String?
        var currentChildren: [String] = []
        var pendingNonChildLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if isChildLine(line) {
                let childText = stripChildPrefix(line)
                guard !childText.isEmpty else { continue }

                if currentParent == nil {
                    // Children before any parent — flush pending non-child lines as standalone
                    for pending in pendingNonChildLines {
                        groups.append(RawLineGroup(parent: pending, children: []))
                    }
                    pendingNonChildLines.removeAll()
                    // Skip orphaned child (shouldn't happen given allAreChildren check)
                    continue
                }
                currentChildren.append(childText)
            } else {
                // Non-child line — potential parent
                // First, flush any in-progress group
                if let parent = currentParent {
                    if currentChildren.isEmpty {
                        // Previous "parent" had no children — it's a standalone task
                        pendingNonChildLines.append(parent)
                    } else {
                        // Flush pending standalone lines first
                        for pending in pendingNonChildLines {
                            groups.append(RawLineGroup(parent: pending, children: []))
                        }
                        pendingNonChildLines.removeAll()
                        groups.append(RawLineGroup(parent: parent, children: currentChildren))
                    }
                }

                // Start new potential parent
                let parentText = isColonHeader(line) ? stripColonSuffix(line) : trimmed
                currentParent = parentText
                currentChildren = []
            }
        }

        // Flush final group
        if let parent = currentParent {
            if currentChildren.isEmpty {
                pendingNonChildLines.append(parent)
            } else {
                for pending in pendingNonChildLines {
                    groups.append(RawLineGroup(parent: pending, children: []))
                }
                pendingNonChildLines.removeAll()
                groups.append(RawLineGroup(parent: parent, children: currentChildren))
            }
        }

        // Flush remaining standalone lines
        for pending in pendingNonChildLines {
            groups.append(RawLineGroup(parent: pending, children: []))
        }

        // Only return hierarchy if at least one group has children
        let hasHierarchy = groups.contains { !$0.children.isEmpty }
        return hasHierarchy ? groups : []
    }

    /// Convert a raw text line into a RawSegment with date parsing
    private func makeSegment(from text: String) -> RawSegment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = Date.parse(from: trimmed) {
            let cleanTitle = parsed.cleanedTitle(from: trimmed)
            let title = cleanTitle.isEmpty ? trimmed : cleanTitle
            return RawSegment(text: title, parsedDate: parsed.date, parsedTime: parsed.time)
        }
        return RawSegment(text: trimmed, parsedDate: nil, parsedTime: nil)
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
            parseSingleDraft(from: json, segments: segments, lists: lists)
        }
        return (drafts, true)
    }

    /// Parse a single task JSON object into a TaskDraft (with optional subtasks)
    private func parseSingleDraft(
        from json: [String: Any],
        segments: [RawSegment],
        lists: [TaskList]
    ) -> TaskDraft? {
        guard let rawTitle = json["title"] as? String else { return nil }
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        // Parse priority
        let priorityStr = json["priority"] as? String ?? "none"
        let priority = parsePriority(from: priorityStr)

        // Parse category
        let categoryStr = json["category"] as? String ?? "uncategorized"
        let (category, customCategoryID) = parseCategory(from: categoryStr)

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

        // Parse subtasks
        var subtaskDrafts: [TaskDraft] = []
        if let subtasksJSON = json["subtasks"] as? [[String: Any]] {
            subtaskDrafts = subtasksJSON.compactMap { sub in
                guard let subTitle = sub["title"] as? String,
                      !subTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                let cleanTitle = subTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                var subDueDate: Date?
                var subDueTime: Date?
                if let dueDateStr = sub["due_date"] as? String, !dueDateStr.isEmpty {
                    if let parsed = Date.parse(from: dueDateStr) {
                        subDueDate = parsed.date
                        subDueTime = parsed.time
                    }
                }
                var subPriority: Priority = .none
                if let priorityStr = sub["priority"] as? String, !priorityStr.isEmpty {
                    subPriority = parsePriority(from: priorityStr)
                }
                return TaskDraft(
                    title: cleanTitle,
                    dueDate: subDueDate,
                    dueTime: subDueTime,
                    priority: subPriority
                )
            }
        }

        return TaskDraft(
            title: title,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority,
            category: category,
            customCategoryID: customCategoryID,
            listID: listID,
            subtasks: subtaskDrafts
        )
    }

    // MARK: - Parsing Helpers

    private func parsePriority(from string: String) -> Priority {
        switch string.lowercased() {
        case "urgent": return .urgent
        case "high": return .high
        case "medium": return .medium
        case "low": return .low
        default: return .none
        }
    }

    private func parseCategory(from string: String) -> (TaskCategory, UUID?) {
        switch string.lowercased() {
        case "work": return (.work, nil)
        case "personal": return (.personal, nil)
        case "health": return (.health, nil)
        case "finance": return (.finance, nil)
        case "shopping": return (.shopping, nil)
        case "errands": return (.errands, nil)
        case "learning": return (.learning, nil)
        case "home": return (.home, nil)
        default:
            if let custom = categoryService.getCategory(byName: string) {
                return (.uncategorized, custom.id)
            }
            return (.uncategorized, nil)
        }
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
