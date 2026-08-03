import Foundation
import os
import LazyflowCore

/// Feeds task and note content into the knowledge graph (#152).
///
/// Extraction (`EntityExtractionService`) finds entities; this service turns
/// them into graph writes: node upserts, pairwise co-occurrence edges,
/// category/list topic linkage, and evidence provenance rows.
///
/// Fully gated by the `knowledgeGraph` feature flag — when disabled every
/// entry point is a no-op. Writes happen on the store's background context;
/// callers fire-and-forget from the main actor.
@MainActor
@Observable
final class KnowledgeGraphIngestionService {
    static let shared = KnowledgeGraphIngestionService()

    private let store: KnowledgeGraphStore
    private let isEnabled: @MainActor () -> Bool
    private let knownProjects: @MainActor () -> [String]
    private let knownTopics: @MainActor () -> [String]

    /// Cap on pairwise co-occurrence edges per ingested item; guards against
    /// pathological texts producing O(n²) edge writes.
    private static let maxCoOccurrencePairs = 10

    init(
        store: KnowledgeGraphStore = .shared,
        isEnabled: @escaping @MainActor () -> Bool = { FeatureFlags.shared.isEnabled(.knowledgeGraph) },
        knownProjects: @escaping @MainActor () -> [String] = { TaskListService.shared.lists.map(\.name) },
        knownTopics: @escaping @MainActor () -> [String] = { CategoryService.shared.categories.map(\.name) }
    ) {
        self.store = store
        self.isEnabled = isEnabled
        self.knownProjects = knownProjects
        self.knownTopics = knownTopics
    }

    // MARK: - Ingestion

    /// Ingest a task's title and notes into the graph
    func ingest(task: Task, at date: Date = Date()) async {
        guard isEnabled() else { return }

        let text = [task.title, task.notes ?? ""].joined(separator: "\n")
        let categoryName = task.category == .uncategorized ? nil : task.category.displayName
        await ingest(text: text, sourceTaskID: task.id, sourceNoteID: nil, categoryName: categoryName, at: date)
    }

    /// Ingest a quick note's text into the graph
    func ingest(note: QuickNote, at date: Date = Date()) async {
        guard isEnabled() else { return }
        await ingest(text: note.text, sourceTaskID: nil, sourceNoteID: note.id, categoryName: nil, at: date)
    }

    /// Drop provenance rows for a deleted task. Nodes and edges stay —
    /// recency weighting handles staleness; deletion doesn't rewrite history.
    func removeEvidence(forTaskID taskID: UUID) async {
        guard isEnabled() else { return }
        do {
            try await store.deleteEvidence(forTaskID: taskID)
        } catch {
            Logger.ai.error("KG: failed to remove evidence for task \(taskID): \(error)")
        }
    }

    // MARK: - Core Pipeline

    private func ingest(
        text: String,
        sourceTaskID: UUID?,
        sourceNoteID: UUID?,
        categoryName: String?,
        at date: Date
    ) async {
        let entities = EntityExtractionService.extract(
            from: text,
            knownProjects: knownProjects(),
            knownTopics: knownTopics()
        )
        guard !entities.isEmpty else { return }

        let snippet = String(text.prefix(120))

        do {
            // 1. Upsert entity nodes + evidence
            var keys: [String] = []
            for entity in entities {
                let node = try await store.upsertNode(
                    displayName: entity.name,
                    type: entity.type,
                    confidence: entity.confidence,
                    at: date
                )
                keys.append(node.normalizedKey)
                _ = try await store.addEvidence(
                    nodeID: node.id,
                    sourceTaskID: sourceTaskID,
                    sourceNoteID: sourceNoteID,
                    snippet: snippet,
                    at: date
                )
            }

            // 2. Pairwise co-occurrence edges (deterministic order, capped)
            let sortedKeys = keys.sorted()
            var pairCount = 0
            outer: for i in 0..<sortedKeys.count {
                for j in (i + 1)..<sortedKeys.count {
                    guard pairCount < Self.maxCoOccurrencePairs else { break outer }
                    _ = try await store.upsertEdge(
                        sourceKey: sortedKeys[i],
                        targetKey: sortedKeys[j],
                        relation: .coOccursWith,
                        at: date
                    )
                    pairCount += 1
                }
            }

            // 3. Category as a topic node, entities belong to it
            if let categoryName {
                let categoryNode = try await store.upsertNode(
                    displayName: categoryName,
                    type: .topic,
                    confidence: 1.0,
                    at: date
                )
                for key in sortedKeys where key != categoryNode.normalizedKey {
                    _ = try await store.upsertEdge(
                        sourceKey: key,
                        targetKey: categoryNode.normalizedKey,
                        relation: .belongsTo,
                        at: date
                    )
                }
            }

            Logger.ai.debug("KG: ingested \(entities.count) entities from \(sourceTaskID != nil ? "task" : "note")")
        } catch {
            Logger.ai.error("KG: ingestion failed: \(error)")
        }
    }
}
