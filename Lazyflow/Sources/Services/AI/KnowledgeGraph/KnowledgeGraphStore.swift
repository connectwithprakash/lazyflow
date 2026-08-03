import CoreData
import Foundation
import LazyflowCore
import os

/// Repository for the on-device knowledge graph (#152).
///
/// Persists nodes, edges, and evidence into the device-local `LocalGraph`
/// Core Data store (never synced to CloudKit). All access goes through a
/// dedicated background context; callers receive value types, never managed
/// objects. Retrieval-time traversal happens on in-memory snapshots from
/// `fetchAllNodes()`/`fetchAllEdges()` — Core Data relationships are only an
/// integrity mechanism here, not a traversal path.
final class KnowledgeGraphStore: @unchecked Sendable {
    static let shared = KnowledgeGraphStore()

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.name = "KnowledgeGraphStore"
        self.context = context
    }

    // MARK: - Nodes

    /// Insert a node, or bump an existing one with the same normalized key.
    /// Returns the resulting domain node.
    @discardableResult
    func upsertNode(
        displayName: String,
        type: KnowledgeNodeType,
        confidence: Double = 0.5,
        salienceBoost: Double = 1,
        at date: Date = Date()
    ) async throws -> KnowledgeNode {
        let key = KnowledgeKey.normalize(displayName)
        guard !key.isEmpty else { throw KnowledgeGraphStoreError.emptyKey }

        return try await context.perform { [context] in
            let entity = try Self.fetchNodeEntity(forKey: key, in: context)
                ?? Self.makeNodeEntity(key: key, displayName: displayName, type: type, date: date, in: context)

            entity.mentionCount += 1
            // Monotonic timestamps: out-of-order ingestion (backfill runs
            // newest-first) must never regress recency or advance first-seen
            entity.lastSeenAt = max(entity.lastSeenAt ?? .distantPast, date)
            entity.firstSeenAt = min(entity.firstSeenAt ?? .distantFuture, date)
            entity.salience += salienceBoost
            entity.confidence = max(entity.confidence, confidence)

            try context.save()
            return Self.domainNode(from: entity)
        }
    }

    /// Fetch a single node by its normalized key
    func node(forKey key: String) async throws -> KnowledgeNode? {
        try await context.perform { [context] in
            try Self.fetchNodeEntity(forKey: key, in: context).map(Self.domainNode(from:))
        }
    }

    /// All nodes, for building the in-memory retrieval index
    func fetchAllNodes() async throws -> [KnowledgeNode] {
        try await context.perform { [context] in
            let request = KnowledgeNodeEntity.fetchRequest()
            request.returnsObjectsAsFaults = false
            return try context.fetch(request).map(Self.domainNode(from:))
        }
    }

    /// Delete a node and (via cascade) all edges touching it
    func deleteNode(forKey key: String) async throws {
        try await context.perform { [context] in
            guard let entity = try Self.fetchNodeEntity(forKey: key, in: context) else { return }
            context.delete(entity)
            try context.save()
        }
    }

    // MARK: - Edges

    /// Insert an edge between two existing nodes, or reinforce an existing one.
    /// Both endpoints must already exist (upsert nodes first).
    @discardableResult
    func upsertEdge(
        sourceKey: String,
        targetKey: String,
        relation: KnowledgeRelationType,
        weightDelta: Double = 1,
        confidence: Double = 0.5,
        at date: Date = Date()
    ) async throws -> KnowledgeEdge {
        let edgeKey = KnowledgeKey.edgeKey(source: sourceKey, relation: relation, target: targetKey)

        return try await context.perform { [context] in
            guard let source = try Self.fetchNodeEntity(forKey: sourceKey, in: context),
                  let target = try Self.fetchNodeEntity(forKey: targetKey, in: context) else {
                throw KnowledgeGraphStoreError.missingEndpoint(edgeKey)
            }

            let entity: KnowledgeEdgeEntity
            if let existing = try Self.fetchEdgeEntity(forKey: edgeKey, in: context) {
                entity = existing
            } else {
                entity = KnowledgeEdgeEntity(context: context)
                entity.id = UUID()
                entity.edgeKey = edgeKey
                entity.relationTypeRaw = relation.rawValue
                entity.sourceNode = source
                entity.targetNode = target
                entity.firstSeenAt = date
            }

            entity.evidenceCount += 1
            entity.weight += weightDelta
            entity.confidence = max(entity.confidence, confidence)
            // Monotonic (see upsertNode): backfill ingests newest-first
            entity.lastSeenAt = max(entity.lastSeenAt ?? .distantPast, date)

            try context.save()
            guard let edge = Self.domainEdge(from: entity) else {
                throw KnowledgeGraphStoreError.missingEndpoint(edgeKey)
            }
            return edge
        }
    }

    /// Fetch a single edge by its deterministic edge key
    func edge(forKey key: String) async throws -> KnowledgeEdge? {
        try await context.perform { [context] in
            try Self.fetchEdgeEntity(forKey: key, in: context).flatMap(Self.domainEdge(from:))
        }
    }

    /// All edges, for building the in-memory retrieval index
    func fetchAllEdges() async throws -> [KnowledgeEdge] {
        try await context.perform { [context] in
            let request = KnowledgeEdgeEntity.fetchRequest()
            request.returnsObjectsAsFaults = false
            request.relationshipKeyPathsForPrefetching = ["sourceNode", "targetNode"]
            return try context.fetch(request).compactMap(Self.domainEdge(from:))
        }
    }

    // MARK: - Evidence

    /// Record provenance linking a node/edge back to the task or note it came from
    @discardableResult
    func addEvidence(
        nodeID: UUID? = nil,
        edgeID: UUID? = nil,
        sourceTaskID: UUID? = nil,
        sourceNoteID: UUID? = nil,
        snippet: String? = nil,
        at date: Date = Date()
    ) async throws -> KnowledgeEvidence {
        try await context.perform { [context] in
            let entity = KnowledgeEvidenceEntity(context: context)
            entity.id = UUID()
            entity.nodeID = nodeID
            entity.edgeID = edgeID
            entity.sourceTaskID = sourceTaskID
            entity.sourceNoteID = sourceNoteID
            entity.snippet = snippet
            entity.createdAt = date
            try context.save()
            return KnowledgeEvidence(
                id: entity.id ?? UUID(),
                nodeID: nodeID,
                edgeID: edgeID,
                sourceTaskID: sourceTaskID,
                sourceNoteID: sourceNoteID,
                snippet: snippet,
                createdAt: date
            )
        }
    }

    /// Evidence recorded for a given source task
    func evidence(forTaskID taskID: UUID) async throws -> [KnowledgeEvidence] {
        try await context.perform { [context] in
            let request = KnowledgeEvidenceEntity.fetchRequest()
            request.predicate = NSPredicate(format: "sourceTaskID == %@", taskID as CVarArg)
            return try context.fetch(request).map(Self.domainEvidence(from:))
        }
    }

    /// Evidence recorded for a given source note
    func evidence(forNoteID noteID: UUID) async throws -> [KnowledgeEvidence] {
        try await context.perform { [context] in
            let request = KnowledgeEvidenceEntity.fetchRequest()
            request.predicate = NSPredicate(format: "sourceNoteID == %@", noteID as CVarArg)
            return try context.fetch(request).map(Self.domainEvidence(from:))
        }
    }

    /// Delete all evidence rows recorded for a source task (task deletion)
    func deleteEvidence(forTaskID taskID: UUID) async throws {
        try await context.perform { [context] in
            let request = KnowledgeEvidenceEntity.fetchRequest()
            request.predicate = NSPredicate(format: "sourceTaskID == %@", taskID as CVarArg)
            request.includesPropertyValues = false
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Maintenance

    /// Counts for diagnostics and tests
    func counts() async throws -> (nodes: Int, edges: Int, evidence: Int) {
        try await context.perform { [context] in
            let nodes = try context.count(for: KnowledgeNodeEntity.fetchRequest())
            let edges = try context.count(for: KnowledgeEdgeEntity.fetchRequest())
            let evidence = try context.count(for: KnowledgeEvidenceEntity.fetchRequest())
            return (nodes, edges, evidence)
        }
    }

    /// Wipe the entire graph (settings "reset graph" action; user data untouched)
    func deleteAllGraphData() async throws {
        try await context.perform { [context] in
            let requests: [NSFetchRequest<NSManagedObject>] = [
                NSFetchRequest(entityName: "KnowledgeEvidenceEntity"),
                NSFetchRequest(entityName: "KnowledgeEdgeEntity"),
                NSFetchRequest(entityName: "KnowledgeNodeEntity")
            ]
            for request in requests {
                request.includesPropertyValues = false
                for object in try context.fetch(request) {
                    context.delete(object)
                }
            }
            try context.save()
            Logger.persistence.info("Knowledge graph data deleted")
        }
    }

    // MARK: - Fetch Helpers

    private static func fetchNodeEntity(
        forKey key: String,
        in context: NSManagedObjectContext
    ) throws -> KnowledgeNodeEntity? {
        let request = KnowledgeNodeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "normalizedKey == %@", key)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func fetchEdgeEntity(
        forKey key: String,
        in context: NSManagedObjectContext
    ) throws -> KnowledgeEdgeEntity? {
        let request = KnowledgeEdgeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "edgeKey == %@", key)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func makeNodeEntity(
        key: String,
        displayName: String,
        type: KnowledgeNodeType,
        date: Date,
        in context: NSManagedObjectContext
    ) -> KnowledgeNodeEntity {
        let entity = KnowledgeNodeEntity(context: context)
        entity.id = UUID()
        entity.normalizedKey = key
        entity.displayName = displayName
        entity.nodeTypeRaw = type.rawValue
        entity.firstSeenAt = date
        return entity
    }

    // MARK: - Domain Mapping

    private static func domainNode(from entity: KnowledgeNodeEntity) -> KnowledgeNode {
        let aliases: [String] = entity.aliasesJSON
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        return KnowledgeNode(
            id: entity.id ?? UUID(),
            normalizedKey: entity.normalizedKey ?? "",
            displayName: entity.displayName ?? "",
            type: KnowledgeNodeType(rawValue: entity.nodeTypeRaw) ?? .custom,
            salience: entity.salience,
            confidence: entity.confidence,
            mentionCount: entity.mentionCount,
            firstSeenAt: entity.firstSeenAt ?? .distantPast,
            lastSeenAt: entity.lastSeenAt ?? .distantPast,
            lastActivatedAt: entity.lastActivatedAt,
            aliases: aliases
        )
    }

    private static func domainEdge(from entity: KnowledgeEdgeEntity) -> KnowledgeEdge? {
        guard let sourceKey = entity.sourceNode?.normalizedKey,
              let targetKey = entity.targetNode?.normalizedKey else { return nil }
        return KnowledgeEdge(
            id: entity.id ?? UUID(),
            relation: KnowledgeRelationType(rawValue: entity.relationTypeRaw) ?? .relatedTo,
            sourceKey: sourceKey,
            targetKey: targetKey,
            weight: entity.weight,
            confidence: entity.confidence,
            evidenceCount: entity.evidenceCount,
            firstSeenAt: entity.firstSeenAt ?? .distantPast,
            lastSeenAt: entity.lastSeenAt ?? .distantPast
        )
    }

    private static func domainEvidence(from entity: KnowledgeEvidenceEntity) -> KnowledgeEvidence {
        KnowledgeEvidence(
            id: entity.id ?? UUID(),
            nodeID: entity.nodeID,
            edgeID: entity.edgeID,
            sourceTaskID: entity.sourceTaskID,
            sourceNoteID: entity.sourceNoteID,
            snippet: entity.snippet,
            createdAt: entity.createdAt ?? .distantPast
        )
    }
}

/// Errors surfaced by the knowledge graph store
enum KnowledgeGraphStoreError: Error, Equatable {
    /// Node display name normalized to an empty key
    case emptyKey
    /// Edge upsert attempted before both endpoint nodes exist
    case missingEndpoint(String)
}
