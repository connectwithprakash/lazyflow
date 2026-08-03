import Foundation
import NaturalLanguage
import LazyflowCore

/// An entity detected in task/note text, before graph ingestion
struct ExtractedEntity: Equatable {
    let name: String
    let type: KnowledgeNodeType
    let confidence: Double
}

/// On-device entity extraction for the knowledge graph (#152).
///
/// Tier-1 extractor: `NLTagger` named-entity recognition (people, organizations,
/// places) plus whole-word matching against the user's own project/topic names
/// (task lists and categories act as a permission-free gazetteer). Deterministic,
/// no LLM, no network.
///
/// NLTagger is precision-oriented: it rarely mislabels but misses lowercase or
/// ambiguous names. The gazetteer names recover recall for the vocabulary that
/// matters most — the user's own projects.
enum EntityExtractionService {

    /// NER confidence for NLTagger hits (high precision, so high trust)
    private static let nerConfidence = 0.8

    /// Known-name matches are the user's own vocabulary — highest trust
    private static let knownNameConfidence = 0.9

    /// Extract entities from free text.
    ///
    /// - Parameters:
    ///   - text: Task title/notes or note text.
    ///   - knownProjects: User's project-like names (e.g. task list names).
    ///   - knownTopics: User's topic-like names (e.g. category names).
    static func extract(
        from text: String,
        knownProjects: [String] = [],
        knownTopics: [String] = []
    ) -> [ExtractedEntity] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [ExtractedEntity] = []
        results.append(contentsOf: namedEntities(in: trimmed))
        results.append(contentsOf: knownNameMatches(in: trimmed, names: knownProjects, type: .project))
        results.append(contentsOf: knownNameMatches(in: trimmed, names: knownTopics, type: .topic))

        // Dedup by normalized key, keeping the highest-confidence detection
        var byKey: [String: ExtractedEntity] = [:]
        for entity in results {
            let key = KnowledgeKey.normalize(entity.name)
            guard !key.isEmpty else { continue }
            if let existing = byKey[key], existing.confidence >= entity.confidence { continue }
            byKey[key] = entity
        }
        return byKey.values.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            return lhs.name < rhs.name
        }
    }

    // MARK: - NLTagger NER

    private static func namedEntities(in text: String) -> [ExtractedEntity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var entities: [ExtractedEntity] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, range in
            guard let tag, let type = nodeType(for: tag) else { return true }
            let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                entities.append(ExtractedEntity(name: name, type: type, confidence: nerConfidence))
            }
            return true
        }
        return entities
    }

    private static func nodeType(for tag: NLTag) -> KnowledgeNodeType? {
        switch tag {
        case .personalName: return .person
        case .organizationName: return .organization
        case .placeName: return .place
        default: return nil
        }
    }

    // MARK: - Known Names

    /// Case-insensitive whole-word matches of the user's own names
    private static func knownNameMatches(
        in text: String,
        names: [String],
        type: KnowledgeNodeType
    ) -> [ExtractedEntity] {
        guard !names.isEmpty else { return [] }
        let tokens = Set(
            text
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )

        return names.compactMap { name in
            let nameTokens = name
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            guard !nameTokens.isEmpty, nameTokens.allSatisfy(tokens.contains) else { return nil }
            return ExtractedEntity(name: name, type: type, confidence: knownNameConfidence)
        }
    }
}
