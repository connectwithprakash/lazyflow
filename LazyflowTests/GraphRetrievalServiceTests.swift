import XCTest
import LazyflowCore
@testable import Lazyflow

final class GraphRetrievalServiceTests: XCTestCase {

    private var persistence: PersistenceController!
    private var store: KnowledgeGraphStore!
    private var retrieval: GraphRetrievalService!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true, enableCloudKit: false)
        store = KnowledgeGraphStore(persistenceController: persistence)
        retrieval = GraphRetrievalService(store: store)
    }

    override func tearDown() {
        retrieval = nil
        store = nil
        persistence = nil
        super.tearDown()
    }

    private func seedGraph() async throws {
        _ = try await store.upsertNode(displayName: "Microsoft", type: .organization)
        _ = try await store.upsertNode(displayName: "Sarah Johnson", type: .person)
        _ = try await store.upsertNode(displayName: "Work", type: .topic)
        _ = try await store.upsertEdge(sourceKey: "microsoft", targetKey: "johnson sarah", relation: .coOccursWith)
        _ = try await store.upsertEdge(sourceKey: "microsoft", targetKey: "work", relation: .belongsTo)
    }

    func testContextSection_BeforeRefresh_ReturnsNil() async throws {
        try await seedGraph()

        XCTAssertNil(retrieval.contextSection(for: "Send the invoice to Microsoft"))
    }

    func testContextSection_AfterRefresh_ReturnsRelatedConnections() async throws {
        try await seedGraph()
        await retrieval.refresh()

        let section = retrieval.contextSection(for: "Send the invoice to Microsoft", knownProjects: ["Microsoft"])

        let unwrapped = try XCTUnwrap(section)
        XCTAssertTrue(unwrapped.contains("Microsoft"))
        XCTAssertTrue(unwrapped.contains("Sarah Johnson") || unwrapped.contains("Work"))
    }

    func testContextSection_TextWithNoKnownEntities_ReturnsNil() async throws {
        try await seedGraph()
        await retrieval.refresh()

        XCTAssertNil(retrieval.contextSection(for: "buy milk and eggs"))
    }

    func testContextSection_EmptyGraph_ReturnsNil() async {
        await retrieval.refresh()

        XCTAssertNil(retrieval.contextSection(for: "Send the invoice to Microsoft"))
    }

    func testContextSection_RespectsCharacterBudget() async throws {
        try await seedGraph()
        await retrieval.refresh()

        let section = retrieval.contextSection(for: "Send the invoice to Microsoft", knownProjects: ["Microsoft"], maxCharacters: 120)

        if let section {
            XCTAssertLessThanOrEqual(section.count, 120)
        }
    }

    // Adversarial review B1: lowercase short titles defeat NLTagger; the
    // user's own list/category names must seed retrieval
    func testContextSection_LowercaseTitleSeededByKnownProjectName() async throws {
        _ = try await store.upsertNode(displayName: "Acme", type: .project)
        _ = try await store.upsertNode(displayName: "Sarah Johnson", type: .person)
        _ = try await store.upsertEdge(sourceKey: "acme", targetKey: "johnson sarah", relation: .coOccursWith)
        await retrieval.refresh()

        // NLTagger finds nothing in this title...
        XCTAssertNil(retrieval.contextSection(for: "update acme deck"))
        // ...but the gazetteer does
        let section = retrieval.contextSection(for: "update acme deck", knownProjects: ["Acme"])
        XCTAssertNotNil(section)
        XCTAssertTrue(try XCTUnwrap(section).contains("Sarah Johnson"))
    }

    func testRefreshIfStale_PicksUpNewData() async throws {
        await retrieval.refresh()
        XCTAssertNil(retrieval.contextSection(for: "Send the invoice to Microsoft"))

        try await seedGraph()
        retrieval.invalidate()
        await retrieval.refreshIfStale()

        XCTAssertNotNil(retrieval.contextSection(for: "Send the invoice to Microsoft", knownProjects: ["Microsoft"]))
    }
}
