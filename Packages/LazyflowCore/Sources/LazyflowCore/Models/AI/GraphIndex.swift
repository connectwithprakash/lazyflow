import Foundation

/// In-memory retrieval index over the knowledge graph (#152).
///
/// Built wholesale from node/edge snapshots — never traverses Core Data
/// relationships (fault-per-hop). At personal-todo scale (≤ thousands of
/// nodes) exact personalized PageRank via power iteration runs in well under
/// a millisecond, so no approximation is needed.
///
/// Edge weights are recency-decayed at build time: stale connections fade
/// without ever rewriting history in the store.
public struct GraphIndex: Sendable {

    /// A retrieved fact, ready for prompt linearization
    public struct Triple: Equatable, Sendable {
        public let sourceName: String
        public let relation: KnowledgeRelationType
        public let targetName: String
        public let score: Double
    }

    private struct Neighbor {
        let targetKey: String
        let relation: KnowledgeRelationType
        let decayedWeight: Double
        /// Canonical (source, target) pair for stable triple output
        let sourceName: String
        let targetName: String
        let isForward: Bool
    }

    /// Half-life style decay horizon for edge recency (days)
    private static let recencyHorizonDays = 30.0

    private let displayNames: [String: String]
    private let adjacency: [String: [Neighbor]]

    public var isEmpty: Bool { displayNames.isEmpty }

    // MARK: - Build

    public init(nodes: [KnowledgeNode], edges: [KnowledgeEdge], referenceDate: Date = Date()) {
        var names: [String: String] = [:]
        for node in nodes {
            names[node.normalizedKey] = node.displayName
        }

        var adjacency: [String: [Neighbor]] = [:]
        for edge in edges {
            guard let sourceName = names[edge.sourceKey],
                  let targetName = names[edge.targetKey] else { continue }

            let ageDays = max(0, referenceDate.timeIntervalSince(edge.lastSeenAt) / 86_400)
            let decayed = edge.weight * exp(-ageDays / Self.recencyHorizonDays)
            guard decayed > 0 else { continue }

            adjacency[edge.sourceKey, default: []].append(Neighbor(
                targetKey: edge.targetKey,
                relation: edge.relation,
                decayedWeight: decayed,
                sourceName: sourceName,
                targetName: targetName,
                isForward: true
            ))
            adjacency[edge.targetKey, default: []].append(Neighbor(
                targetKey: edge.sourceKey,
                relation: edge.relation,
                decayedWeight: decayed,
                sourceName: sourceName,
                targetName: targetName,
                isForward: false
            ))
        }

        self.displayNames = names
        self.adjacency = adjacency
    }

    // MARK: - Personalized PageRank

    /// Exact PPR by power iteration. Reset probability concentrates on `seeds`,
    /// relevance propagates along recency-weighted edges.
    ///
    /// Damping is deliberately low (0.5 vs the classic 0.85): retrieval wants
    /// seed-neighborhood locality, and a strong teleport keeps seeds dominant
    /// instead of letting a well-connected hub take over the ranking.
    public func personalizedPageRank(
        seeds: Set<String>,
        damping: Double = 0.5,
        iterations: Int = 25
    ) -> [String: Double] {
        let validSeeds = seeds.filter { displayNames[$0] != nil }
        guard !validSeeds.isEmpty else { return [:] }

        let seedMass = 1.0 / Double(validSeeds.count)
        var reset: [String: Double] = [:]
        for seed in validSeeds { reset[seed] = seedMass }

        var scores = reset
        for _ in 0..<iterations {
            var next: [String: Double] = [:]
            // Teleport component
            for (key, mass) in reset {
                next[key, default: 0] += (1 - damping) * mass
            }
            // Propagation component
            for (key, score) in scores {
                guard score > 0, let neighbors = adjacency[key], !neighbors.isEmpty else {
                    // Dangling mass returns to the seeds
                    for (seedKey, mass) in reset {
                        next[seedKey, default: 0] += damping * score * mass
                    }
                    continue
                }
                let totalWeight = neighbors.reduce(0) { $0 + $1.decayedWeight }
                for neighbor in neighbors {
                    let share = neighbor.decayedWeight / totalWeight
                    next[neighbor.targetKey, default: 0] += damping * score * share
                }
            }
            scores = next
        }
        return scores
    }

    // MARK: - Retrieval

    /// Highest-relevance triples for the given seed entities
    public func topTriples(seeds: Set<String>, limit: Int) -> [Triple] {
        let scores = personalizedPageRank(seeds: seeds)
        guard !scores.isEmpty, limit > 0 else { return [] }

        // Score each unique edge by endpoint relevance × edge strength
        var seen = Set<String>()
        var scored: [(triple: Triple, sortKey: String)] = []

        for (key, neighbors) in adjacency {
            for neighbor in neighbors where neighbor.isForward {
                let edgeIdentity = "\(neighbor.sourceName)|\(neighbor.relation.rawValue)|\(neighbor.targetName)"
                guard !seen.contains(edgeIdentity) else { continue }
                seen.insert(edgeIdentity)

                let relevance = (scores[key] ?? 0) + (scores[neighbor.targetKey] ?? 0)
                let score = relevance * neighbor.decayedWeight
                guard score > 0 else { continue }

                scored.append((
                    Triple(
                        sourceName: neighbor.sourceName,
                        relation: neighbor.relation,
                        targetName: neighbor.targetName,
                        score: score
                    ),
                    edgeIdentity
                ))
            }
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.triple.score != rhs.triple.score { return lhs.triple.score > rhs.triple.score }
                return lhs.sortKey < rhs.sortKey
            }
            .prefix(limit)
            .map(\.triple)
    }

    // MARK: - Prompt Rendering

    /// Linearize top triples grouped by subject into a compact prompt section.
    /// Grouping halves repeated-subject tokens vs one-triple-per-line.
    public func promptSection(
        seeds: Set<String>,
        maxCharacters: Int,
        tripleLimit: Int = 12
    ) -> String? {
        let triples = topTriples(seeds: seeds, limit: tripleLimit)
        guard !triples.isEmpty else { return nil }

        // Group by subject, preserving overall relevance order
        var order: [String] = []
        var grouped: [String: [Triple]] = [:]
        for triple in triples {
            if grouped[triple.sourceName] == nil { order.append(triple.sourceName) }
            grouped[triple.sourceName, default: []].append(triple)
        }

        var lines = ["Known connections from your task history:"]
        for subject in order {
            let facts = grouped[subject]!
                .map { "\($0.relation.promptLabel) \($0.targetName)" }
                .joined(separator: ", ")
            let line = "- \(subject): \(facts)"
            let rendered = (lines + [line]).joined(separator: "\n")
            guard rendered.count <= maxCharacters else { break }
            lines.append(line)
        }
        guard lines.count > 1 else { return nil }
        return lines.joined(separator: "\n")
    }
}
