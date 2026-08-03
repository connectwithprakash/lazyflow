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

    /// Effective gate: the feature-flag kill-switch AND the user's opt-in
    /// toggle in AI Settings must both be on
    static var isActive: Bool {
        FeatureFlags.shared.isEnabled(.knowledgeGraph)
            && UserDefaults.standard.bool(forKey: AppConstants.StorageKey.knowledgeGraphEnabled)
    }

    init(
        store: KnowledgeGraphStore = .shared,
        isEnabled: @escaping @MainActor () -> Bool = { KnowledgeGraphIngestionService.isActive },
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

    // MARK: - Backfill

    /// Bounded look-back for the one-time backfill (days)
    static let backfillHorizonDays = 90.0

    /// Cap on tasks ingested during backfill
    static let backfillTaskLimit = 200

    /// Guards against concurrent backfills (launch hook racing the settings
    /// toggle). Evidence dedup makes overlap harmless for correctness, but
    /// running twice is still wasted work.
    private var isBackfilling = false

    /// One-time backfill of recent existing tasks after the user enables the
    /// feature. Guarded by a UserDefaults marker; safe to call on every launch.
    func backfillIfNeeded(now: Date = Date()) async {
        guard isEnabled() else {
            Logger.ai.debug("KG: backfill skipped — feature not active")
            return
        }
        let marker = AppConstants.StorageKey.knowledgeGraphBackfillDone
        guard !UserDefaults.standard.bool(forKey: marker) else {
            Logger.ai.debug("KG: backfill skipped — already completed")
            return
        }
        guard !isBackfilling else {
            Logger.ai.debug("KG: backfill skipped — already running")
            return
        }
        isBackfilling = true
        defer { isBackfilling = false }

        await backfill(tasks: TaskService.shared.tasks, now: now)
        UserDefaults.standard.set(true, forKey: marker)
        Logger.ai.info("KG: backfill completed")
    }

    /// Ingest tasks created/updated within the backfill horizon (bounded)
    func backfill(tasks: [Task], now: Date = Date()) async {
        guard isEnabled() else { return }
        let cutoff = now.addingTimeInterval(-Self.backfillHorizonDays * 86_400)
        let recent = tasks
            .filter { max($0.createdAt, $0.updatedAt) >= cutoff && !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(Self.backfillTaskLimit)

        Logger.ai.info("KG: backfilling \(recent.count) recent tasks")
        for task in recent {
            await ingest(task: task, at: max(task.createdAt, task.updatedAt))
        }
    }

    /// Drop provenance rows for a deleted task. Nodes and edges stay —
    /// recency weighting handles staleness; deletion doesn't rewrite history.
    ///
    /// Deliberately NOT gated on `isEnabled`: cleanup of past ingestion must
    /// run even after the user turns the feature off, or deleted tasks'
    /// snippets would be retained for a feature they opted out of.
    func removeEvidence(forTaskID taskID: UUID) async {
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
        // Extraction is CPU-bound NLP — keep it off the main actor
        let projects = knownProjects()
        let topics = knownTopics()
        let entities = await _Concurrency.Task.detached(priority: .utility) {
            EntityExtractionService.extract(from: text, knownProjects: projects, knownTopics: topics)
        }.value
        guard !entities.isEmpty else { return }

        let snippet = String(text.prefix(120))

        do {
            // Each source (task/note) may credit a node or edge only ONCE —
            // otherwise every updateTask (completion toggles, drags, calendar
            // syncs) inflates counts/weights and grows evidence without bound.
            // This also makes backfill and re-ingestion idempotent.
            let priorEvidence: [KnowledgeEvidence]
            if let sourceTaskID {
                priorEvidence = try await store.evidence(forTaskID: sourceTaskID)
            } else if let sourceNoteID {
                priorEvidence = try await store.evidence(forNoteID: sourceNoteID)
            } else {
                priorEvidence = []
            }
            let creditedNodeIDs = Set(priorEvidence.compactMap(\.nodeID))
            let creditedEdgeIDs = Set(priorEvidence.compactMap(\.edgeID))
            var wroteAnything = false

            // 1. Upsert entity nodes + evidence (skip nodes this source already credited)
            var keys: [String] = []
            for entity in entities {
                let key = KnowledgeKey.normalize(entity.name)
                if let existing = try await store.node(forKey: key),
                   creditedNodeIDs.contains(existing.id) {
                    keys.append(existing.normalizedKey)
                    continue
                }
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
                wroteAnything = true
            }

            // 2. Pairwise co-occurrence edges (deterministic order, capped,
            //    each pair credited once per source)
            let sortedKeys = keys.sorted()
            var pairCount = 0
            outer: for firstIndex in 0..<sortedKeys.count {
                for secondIndex in (firstIndex + 1)..<sortedKeys.count {
                    guard pairCount < Self.maxCoOccurrencePairs else { break outer }
                    pairCount += 1
                    let reinforced = try await reinforceEdge(
                        sourceKey: sortedKeys[firstIndex],
                        targetKey: sortedKeys[secondIndex],
                        relation: .coOccursWith,
                        creditedEdgeIDs: creditedEdgeIDs,
                        sourceTaskID: sourceTaskID,
                        sourceNoteID: sourceNoteID,
                        at: date
                    )
                    wroteAnything = wroteAnything || reinforced
                }
            }

            // 3. Category as a topic node, entities belong to it
            if let categoryName {
                let categoryKey = KnowledgeKey.normalize(categoryName)
                let categoryCredited = try await store.node(forKey: categoryKey)
                    .map { creditedNodeIDs.contains($0.id) } ?? false
                let categoryNode: KnowledgeNode
                if categoryCredited, let existing = try await store.node(forKey: categoryKey) {
                    categoryNode = existing
                } else {
                    categoryNode = try await store.upsertNode(
                        displayName: categoryName,
                        type: .topic,
                        confidence: 1.0,
                        at: date
                    )
                    wroteAnything = true
                }
                for key in sortedKeys where key != categoryNode.normalizedKey {
                    let reinforced = try await reinforceEdge(
                        sourceKey: key,
                        targetKey: categoryNode.normalizedKey,
                        relation: .belongsTo,
                        creditedEdgeIDs: creditedEdgeIDs,
                        sourceTaskID: sourceTaskID,
                        sourceNoteID: sourceNoteID,
                        at: date
                    )
                    wroteAnything = wroteAnything || reinforced
                }
            }

            // New facts invalidate the retrieval snapshot
            if wroteAnything {
                GraphRetrievalService.shared.invalidate()
                Logger.ai.debug("KG: ingested \(entities.count) entities from \(sourceTaskID != nil ? "task" : "note")")
            }
        } catch {
            Logger.ai.error("KG: ingestion failed: \(error)")
        }
    }

    /// Upsert an edge and record edge evidence — unless this source already
    /// credited the edge. Returns true when a write happened.
    private func reinforceEdge(
        sourceKey: String,
        targetKey: String,
        relation: KnowledgeRelationType,
        creditedEdgeIDs: Set<UUID>,
        sourceTaskID: UUID?,
        sourceNoteID: UUID?,
        at date: Date
    ) async throws -> Bool {
        let edgeKey = KnowledgeKey.edgeKey(source: sourceKey, relation: relation, target: targetKey)
        if let existing = try await store.edge(forKey: edgeKey),
           creditedEdgeIDs.contains(existing.id) {
            return false
        }
        let edge = try await store.upsertEdge(
            sourceKey: sourceKey,
            targetKey: targetKey,
            relation: relation,
            at: date
        )
        _ = try await store.addEvidence(
            edgeID: edge.id,
            sourceTaskID: sourceTaskID,
            sourceNoteID: sourceNoteID,
            at: date
        )
        return true
    }
}
