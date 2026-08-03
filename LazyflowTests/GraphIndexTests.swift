import XCTest
import LazyflowCore
@testable import Lazyflow

final class GraphIndexTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func node(_ key: String, mentions: Int32 = 1, lastSeen: TimeInterval = 0) -> KnowledgeNode {
        KnowledgeNode(
            normalizedKey: key,
            displayName: key.capitalized,
            type: .topic,
            mentionCount: mentions,
            firstSeenAt: now.addingTimeInterval(-86_400),
            lastSeenAt: now.addingTimeInterval(lastSeen)
        )
    }

    private func edge(
        _ source: String,
        _ target: String,
        relation: KnowledgeRelationType = .coOccursWith,
        weight: Double = 1,
        lastSeen: TimeInterval = 0
    ) -> KnowledgeEdge {
        KnowledgeEdge(
            relation: relation,
            sourceKey: source,
            targetKey: target,
            weight: weight,
            lastSeenAt: now.addingTimeInterval(lastSeen)
        )
    }

    // MARK: - Personalized PageRank

    func testPPR_SeedRanksHighest() {
        let index = GraphIndex(
            nodes: [node("acme"), node("john"), node("paris")],
            edges: [edge("acme", "john"), edge("john", "paris")],
            referenceDate: now
        )

        let scores = index.personalizedPageRank(seeds: ["acme"])

        XCTAssertGreaterThan(scores["acme"] ?? 0, scores["john"] ?? 0)
        XCTAssertGreaterThan(scores["john"] ?? 0, scores["paris"] ?? 0)
    }

    func testPPR_MultiHopRelevancePropagates() {
        // chain: a - b - c - d; seeding a must rank c above d
        let index = GraphIndex(
            nodes: [node("a"), node("b"), node("c"), node("d")],
            edges: [edge("a", "b"), edge("b", "c"), edge("c", "d")],
            referenceDate: now
        )

        let scores = index.personalizedPageRank(seeds: ["a"])

        XCTAssertGreaterThan(scores["c"] ?? 0, scores["d"] ?? 0)
    }

    func testPPR_UnknownSeeds_ReturnsEmpty() {
        let index = GraphIndex(nodes: [node("a")], edges: [], referenceDate: now)

        XCTAssertTrue(index.personalizedPageRank(seeds: ["ghost"]).isEmpty)
        XCTAssertTrue(index.personalizedPageRank(seeds: []).isEmpty)
    }

    func testPPR_FresherEdgeOutranksStaleEdge() {
        // Same topology either side of the seed; only edge recency differs
        let index = GraphIndex(
            nodes: [node("seed"), node("fresh"), node("stale")],
            edges: [
                edge("seed", "fresh", lastSeen: 0),
                edge("seed", "stale", lastSeen: -90 * 86_400)
            ],
            referenceDate: now
        )

        let scores = index.personalizedPageRank(seeds: ["seed"])

        XCTAssertGreaterThan(scores["fresh"] ?? 0, scores["stale"] ?? 0)
    }

    // MARK: - Triple Retrieval

    func testTopTriples_ReturnsEdgesTouchingRelevantNodes() {
        let index = GraphIndex(
            nodes: [node("acme"), node("john"), node("unrelated"), node("island")],
            edges: [
                edge("acme", "john"),
                edge("unrelated", "island")
            ],
            referenceDate: now
        )

        let triples = index.topTriples(seeds: ["acme"], limit: 5)

        XCTAssertFalse(triples.isEmpty)
        XCTAssertEqual(triples.first?.sourceName, "Acme")
        XCTAssertTrue(triples.allSatisfy { $0.sourceName != "Unrelated" })
    }

    func testTopTriples_RespectsLimit() {
        let nodes = (0..<10).map { node("n\($0)") } + [node("hub")]
        let edges = (0..<10).map { edge("hub", "n\($0)") }
        let index = GraphIndex(nodes: nodes, edges: edges, referenceDate: now)

        XCTAssertEqual(index.topTriples(seeds: ["hub"], limit: 4).count, 4)
    }

    func testTopTriples_Deterministic() {
        let index = GraphIndex(
            nodes: [node("a"), node("b"), node("c")],
            edges: [edge("a", "b"), edge("a", "c"), edge("b", "c")],
            referenceDate: now
        )

        XCTAssertEqual(
            index.topTriples(seeds: ["a"], limit: 3),
            index.topTriples(seeds: ["a"], limit: 3)
        )
    }

    // MARK: - Prompt Section

    func testPromptSection_GroupsBySubjectAndStaysInBudget() {
        let index = GraphIndex(
            nodes: [node("acme"), node("john"), node("work")],
            edges: [
                edge("acme", "john"),
                edge("acme", "work", relation: .belongsTo)
            ],
            referenceDate: now
        )

        let section = index.promptSection(seeds: ["acme"], maxCharacters: 400)

        XCTAssertNotNil(section)
        XCTAssertTrue(section!.contains("Acme"))
        XCTAssertLessThanOrEqual(section!.count, 400)
        // Grouped: subject appears once as a line prefix, not once per triple
        let acmeLines = section!.split(separator: "\n").filter { $0.hasPrefix("- Acme") }
        XCTAssertEqual(acmeLines.count, 1)
    }

    func testPromptSection_EmptyGraphOrNoSeeds_ReturnsNil() {
        let empty = GraphIndex(nodes: [], edges: [], referenceDate: now)
        XCTAssertNil(empty.promptSection(seeds: ["a"], maxCharacters: 400))

        let index = GraphIndex(nodes: [node("a")], edges: [], referenceDate: now)
        XCTAssertNil(index.promptSection(seeds: [], maxCharacters: 400))
        XCTAssertNil(index.promptSection(seeds: ["ghost"], maxCharacters: 400))
    }

    func testIsEmpty() {
        XCTAssertTrue(GraphIndex(nodes: [], edges: [], referenceDate: now).isEmpty)
        XCTAssertFalse(GraphIndex(nodes: [node("a")], edges: [], referenceDate: now).isEmpty)
    }
}
