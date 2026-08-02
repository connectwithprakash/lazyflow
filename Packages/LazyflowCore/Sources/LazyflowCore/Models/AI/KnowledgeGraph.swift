import Foundation

// MARK: - Knowledge Graph Domain Types (#152)
//
// Value types describing the on-device knowledge graph. Persistence lives in
// the app target (Core Data, local-only store); these types are what services
// and the in-memory retrieval index exchange.

/// Kind of thing a knowledge node represents
public enum KnowledgeNodeType: Int16, CaseIterable, Sendable, Codable {
    case topic = 0
    case person = 1
    case organization = 2
    case place = 3
    case project = 4
    case time = 5
    case custom = 6

    public var displayName: String {
        switch self {
        case .topic: return "Topic"
        case .person: return "Person"
        case .organization: return "Organization"
        case .place: return "Place"
        case .project: return "Project"
        case .time: return "Time"
        case .custom: return "Custom"
        }
    }
}

/// Kind of relationship an edge represents
public enum KnowledgeRelationType: Int16, CaseIterable, Sendable, Codable {
    case relatedTo = 0
    case mentions = 1
    case blocks = 2
    case dependsOn = 3
    case belongsTo = 4
    case scheduledWith = 5
    case coOccursWith = 6

    /// Compact label used when linearizing triples for prompts
    public var promptLabel: String {
        switch self {
        case .relatedTo: return "related_to"
        case .mentions: return "mentions"
        case .blocks: return "blocks"
        case .dependsOn: return "depends_on"
        case .belongsTo: return "belongs_to"
        case .scheduledWith: return "scheduled_with"
        case .coOccursWith: return "co_occurs_with"
        }
    }
}

/// A node in the knowledge graph (an entity: person, topic, project, ...)
public struct KnowledgeNode: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Canonical dedup key — see `KnowledgeKey.normalize`
    public let normalizedKey: String
    public let displayName: String
    public let type: KnowledgeNodeType
    public let salience: Double
    public let confidence: Double
    public let mentionCount: Int32
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let lastActivatedAt: Date?
    public let aliases: [String]

    public init(
        id: UUID = UUID(),
        normalizedKey: String,
        displayName: String,
        type: KnowledgeNodeType,
        salience: Double = 0,
        confidence: Double = 0,
        mentionCount: Int32 = 1,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        lastActivatedAt: Date? = nil,
        aliases: [String] = []
    ) {
        self.id = id
        self.normalizedKey = normalizedKey
        self.displayName = displayName
        self.type = type
        self.salience = salience
        self.confidence = confidence
        self.mentionCount = mentionCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.lastActivatedAt = lastActivatedAt
        self.aliases = aliases
    }
}

/// A weighted, typed connection between two nodes, referenced by normalized key
public struct KnowledgeEdge: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Unique key: "sourceKey|relation|targetKey"
    public let edgeKey: String
    public let relation: KnowledgeRelationType
    public let sourceKey: String
    public let targetKey: String
    public let weight: Double
    public let confidence: Double
    public let evidenceCount: Int32
    public let firstSeenAt: Date
    public let lastSeenAt: Date

    public init(
        id: UUID = UUID(),
        relation: KnowledgeRelationType,
        sourceKey: String,
        targetKey: String,
        weight: Double = 1,
        confidence: Double = 0,
        evidenceCount: Int32 = 1,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.edgeKey = KnowledgeKey.edgeKey(source: sourceKey, relation: relation, target: targetKey)
        self.relation = relation
        self.sourceKey = sourceKey
        self.targetKey = targetKey
        self.weight = weight
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }
}

/// Provenance for a node or edge: which task/note it was extracted from.
/// References are UUIDs, not relationships — the graph store is separate from
/// the synced user data store, and cross-store relationships are forbidden.
public struct KnowledgeEvidence: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let nodeID: UUID?
    public let edgeID: UUID?
    public let sourceTaskID: UUID?
    public let sourceNoteID: UUID?
    public let snippet: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        nodeID: UUID? = nil,
        edgeID: UUID? = nil,
        sourceTaskID: UUID? = nil,
        sourceNoteID: UUID? = nil,
        snippet: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.nodeID = nodeID
        self.edgeID = edgeID
        self.sourceTaskID = sourceTaskID
        self.sourceNoteID = sourceNoteID
        self.snippet = snippet
        self.createdAt = createdAt
    }
}

/// Canonical key construction for dedup and edge identity
public enum KnowledgeKey {
    /// Normalize an entity name into its canonical dedup key:
    /// lowercased, diacritic-folded, punctuation stripped, tokens sorted
    /// (so "Smith, John" and "john smith" collide).
    public static func normalize(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: " ")
    }

    /// Deterministic unique key for an edge
    public static func edgeKey(source: String, relation: KnowledgeRelationType, target: String) -> String {
        "\(source)|\(relation.promptLabel)|\(target)"
    }
}
