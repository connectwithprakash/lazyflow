import Foundation
import os
import LazyflowCore

/// Retrieves knowledge-graph context for AI prompts (#152).
///
/// Holds an in-memory `GraphIndex` snapshot rebuilt from the store on demand.
/// Retrieval itself is synchronous over the snapshot, so prompt builders that
/// aren't async (AIContextService, DailySummaryService's context assembly)
/// can consume graph context without plumbing changes; async entry points
/// call `refreshIfStale()` first to warm the snapshot.
///
/// Fail-open by design: an empty/unbuilt index or disabled flag yields `nil`
/// and callers keep their existing flat-context behavior.
final class GraphRetrievalService: @unchecked Sendable {
    static let shared = GraphRetrievalService()

    /// Snapshot considered fresh for this long; ingestion also invalidates
    private static let defaultMaxSnapshotAge: TimeInterval = 60

    private let store: KnowledgeGraphStore
    private let lock = NSLock()
    private var index: GraphIndex?
    private var refreshedAt: Date?

    init(store: KnowledgeGraphStore = .shared) {
        self.store = store
    }

    // MARK: - Snapshot Lifecycle

    /// Rebuild the snapshot when missing or older than `maxAge`
    func refreshIfStale(maxAge: TimeInterval = GraphRetrievalService.defaultMaxSnapshotAge) async {
        let needsRefresh: Bool = {
            lock.lock()
            defer { lock.unlock() }
            guard let refreshedAt else { return true }
            return Date().timeIntervalSince(refreshedAt) > maxAge
        }()
        guard needsRefresh else { return }
        await refresh()
    }

    /// Rebuild the snapshot from the store now
    func refresh() async {
        do {
            let nodes = try await store.fetchAllNodes()
            let edges = try await store.fetchAllEdges()
            let rebuilt = GraphIndex(nodes: nodes, edges: edges)
            lock.lock()
            index = rebuilt
            refreshedAt = Date()
            lock.unlock()
            Logger.ai.debug("KG: retrieval index refreshed (\(nodes.count) nodes, \(edges.count) edges)")
        } catch {
            Logger.ai.error("KG: index refresh failed: \(error)")
        }
    }

    /// Drop the snapshot so the next consumer rebuilds (called after ingestion)
    func invalidate() {
        lock.lock()
        refreshedAt = nil
        lock.unlock()
    }

    // MARK: - Retrieval

    /// Graph context for free text (task title/notes), or nil when the graph
    /// has nothing relevant. Synchronous over the current snapshot.
    func contextSection(
        for text: String,
        knownProjects: [String] = [],
        knownTopics: [String] = [],
        maxCharacters: Int = 400
    ) -> String? {
        let snapshot: GraphIndex? = {
            lock.lock()
            defer { lock.unlock() }
            return index
        }()
        guard let snapshot, !snapshot.isEmpty else { return nil }

        let seeds = Set(
            EntityExtractionService.extract(
                from: text,
                knownProjects: knownProjects,
                knownTopics: knownTopics
            )
            .map { KnowledgeKey.normalize($0.name) }
        )
        guard !seeds.isEmpty else { return nil }

        return snapshot.promptSection(seeds: seeds, maxCharacters: maxCharacters)
    }
}
