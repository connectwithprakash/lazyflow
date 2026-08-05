import Foundation
import NaturalLanguage
import LazyflowCore

/// Groups tasks that likely belong to the same effort by detecting shared salient
/// tokens (projects, people, topics) across task titles.
///
/// Deterministic and fully on-device — no LLM calls. The resulting groups are
/// rendered as a compact prompt section so AI task ordering can reason about
/// related tasks instead of scoring each in isolation.
///
/// This is the prompt-time precursor to the persistent knowledge graph (#152):
/// the same signal (shared entities across tasks) computed at read time.
enum TaskRelationshipGrouper {

    /// A set of tasks connected by a shared salient token.
    struct Group: Equatable {
        /// Normalized token the tasks share (e.g. "acme", "sarah johnson")
        let anchor: String
        let taskIDs: [UUID]
        let titles: [String]
    }

    /// Hard cap for the rendered prompt section, keeping it well inside the
    /// context budgets used elsewhere (e.g. `AppConstants.AI.maxContextCharacters`).
    static let maxPromptSectionCharacters = 600

    /// Tokens appearing in more than this fraction of tasks are too generic
    /// to signal a real relationship (e.g. "meeting" across most of the list).
    private static let genericTokenTaskFraction = 0.6

    private static let minTokenLength = 3

    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "about", "from", "into", "onto", "over",
        "this", "that", "these", "those", "then", "than", "them", "they",
        "have", "has", "had", "get", "got", "make", "made", "take", "took",
        "will", "would", "should", "could", "can", "may", "might", "must",
        "all", "any", "some", "each", "every", "more", "most", "other",
        "new", "old", "next", "last", "first", "today", "tomorrow", "week",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "morning", "afternoon", "evening", "night", "day", "date", "time",
        "task", "todo", "item", "list", "note", "notes", "stuff", "thing", "things",
        "call", "email", "text", "message", "buy", "send", "review", "check",
        "finish", "start", "complete", "update", "schedule", "book", "plan",
        "prep", "prepare", "pick", "drop", "set", "add", "fix", "clean",
        "you", "your", "our", "her", "his", "its", "their", "out", "off"
    ]

    // MARK: - Grouping

    /// Detect groups of related tasks among `tasks`.
    ///
    /// - Parameters:
    ///   - tasks: Candidate tasks (typically the same slice sent to the LLM).
    ///   - maxGroups: Upper bound on returned groups, strongest first.
    ///   - minGroupSize: Minimum tasks sharing an anchor to form a group.
    static func groups(
        for tasks: [Task],
        maxGroups: Int = 3,
        minGroupSize: Int = 2
    ) -> [Group] {
        guard tasks.count >= minGroupSize else { return [] }

        // Token → task indices sharing it. Person names from NLTagger count as
        // single high-value tokens ("sarah johnson").
        var tokenToTasks: [String: Set<Int>] = [:]
        var entityTokens: Set<String> = []

        for (index, task) in tasks.enumerated() {
            let title = task.title
            var seen = Set<String>()

            for token in salientTokens(in: title) where !seen.contains(token) {
                seen.insert(token)
                tokenToTasks[token, default: []].insert(index)
            }
            for name in namedEntities(in: title) where !seen.contains(name) {
                seen.insert(name)
                entityTokens.insert(name)
                tokenToTasks[name, default: []].insert(index)
            }
        }

        let genericCutoff = max(
            Double(minGroupSize),
            Double(tasks.count) * genericTokenTaskFraction
        )

        // Candidate anchors: shared by enough tasks, but not by too many.
        let candidates = tokenToTasks.filter { _, indices in
            indices.count >= minGroupSize && Double(indices.count) <= genericCutoff
        }

        // Strongest first: entity anchors beat plain tokens, then larger groups,
        // then longer anchors; anchor text as the deterministic tiebreak.
        let ranked = candidates.sorted { lhs, rhs in
            let lhsEntity = entityTokens.contains(lhs.key)
            let rhsEntity = entityTokens.contains(rhs.key)
            if lhsEntity != rhsEntity { return lhsEntity }
            if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
            if lhs.key.count != rhs.key.count { return lhs.key.count > rhs.key.count }
            return lhs.key < rhs.key
        }

        // Greedily keep anchors covering task sets not already represented.
        var result: [Group] = []
        var seenTaskSets: [Set<Int>] = []
        for (anchor, indices) in ranked {
            guard result.count < maxGroups else { break }
            guard !seenTaskSets.contains(where: { indices.isSubset(of: $0) }) else { continue }
            seenTaskSets.append(indices)

            let ordered = indices.sorted()
            result.append(Group(
                anchor: anchor,
                taskIDs: ordered.map { tasks[$0].id },
                titles: ordered.map { tasks[$0].title }
            ))
        }
        return result
    }

    // MARK: - Prompt Rendering

    /// Render groups as a compact prompt section, or nil when there are none.
    static func promptSection(for groups: [Group]) -> String? {
        guard !groups.isEmpty else { return nil }

        var lines = ["Related task groups (likely part of the same effort):"]
        for group in groups {
            let line = "- \"\(group.anchor)\": " + group.titles.joined(separator: "; ")
            let rendered = (lines + [line]).joined(separator: "\n")
            guard rendered.count <= maxPromptSectionCharacters else { break }
            lines.append(line)
        }
        guard lines.count > 1 else { return nil }
        return lines.joined(separator: "\n")
    }

    // MARK: - Tokenization

    /// Normalized salient tokens of a title: lowercased, diacritic-folded,
    /// stopwords and short tokens removed.
    private static func salientTokens(in title: String) -> [String] {
        title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= minTokenLength && !stopwords.contains($0) && Int($0) == nil }
    }

    /// Multi-word person/org/place names via NLTagger, normalized like tokens.
    /// High precision, low recall on short lowercase titles — a bonus signal,
    /// not the primary one.
    private static func namedEntities(in title: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = title

        var names: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(
            in: title.startIndex..<title.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, range in
            if let tag, [.personalName, .organizationName, .placeName].contains(tag) {
                let name = String(title[range])
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .lowercased()
                if name.count >= minTokenLength {
                    names.append(name)
                }
            }
            return true
        }
        return names
    }
}
