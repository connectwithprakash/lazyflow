import XCTest
import LazyflowCore
@testable import Lazyflow

@MainActor
final class KnowledgeGraphIngestionServiceTests: XCTestCase {

    private var persistence: PersistenceController!
    private var store: KnowledgeGraphStore!
    private var service: KnowledgeGraphIngestionService!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true, enableCloudKit: false)
        store = KnowledgeGraphStore(persistenceController: persistence)
        service = KnowledgeGraphIngestionService(
            store: store,
            isEnabled: { true },
            knownProjects: { ["Lazyflow"] },
            knownTopics: { [] }
        )
    }

    override func tearDown() {
        service = nil
        store = nil
        persistence = nil
        super.tearDown()
    }

    private func task(_ title: String, notes: String? = nil, category: TaskCategory = .uncategorized) -> LazyflowCore.Task {
        LazyflowCore.Task(title: title, notes: notes, category: category)
    }

    // MARK: - Task Ingestion

    func testIngestTask_UpsertsNodesForDetectedEntities() async throws {
        await service.ingest(task: task("Meet Sarah Johnson at Microsoft"))

        let nodes = try await store.fetchAllNodes()
        let keys = Set(nodes.map(\.normalizedKey))
        XCTAssertTrue(keys.contains("johnson sarah"))
        XCTAssertTrue(keys.contains("microsoft"))
    }

    func testIngestTask_CreatesCoOccurrenceEdgeBetweenEntities() async throws {
        await service.ingest(task: task("Meet Sarah Johnson at Microsoft"))

        let edges = try await store.fetchAllEdges()
        XCTAssertEqual(edges.count, 1)
        XCTAssertEqual(edges[0].relation, .coOccursWith)
        XCTAssertEqual(
            Set([edges[0].sourceKey, edges[0].targetKey]),
            ["johnson sarah", "microsoft"]
        )
    }

    func testIngestTask_RecordsEvidenceWithTaskID() async throws {
        let target = task("Send the invoice to Microsoft")
        await service.ingest(task: target)

        let evidence = try await store.evidence(forTaskID: target.id)
        let first = try XCTUnwrap(evidence.first)
        XCTAssertEqual(first.sourceTaskID, target.id)
    }

    func testIngestTask_ExtractsFromNotesToo() async throws {
        await service.ingest(task: task("Prepare slides", notes: "Include feedback from Sarah Johnson"))

        let nodes = try await store.fetchAllNodes()
        XCTAssertTrue(nodes.contains { $0.normalizedKey == "johnson sarah" })
    }

    func testIngestTask_SameEntityAcrossTasks_ReinforcesNode() async throws {
        // Prepositional phrasing: reliable for NLTagger (imperative "Email X ..." is not)
        await service.ingest(task: task("Send the invoice to Microsoft"))
        await service.ingest(task: task("Send the contract to Microsoft"))

        let nodes = try await store.fetchAllNodes()
        let microsoft = try XCTUnwrap(nodes.first { $0.normalizedKey == "microsoft" })
        XCTAssertEqual(microsoft.mentionCount, 2)
        let counts = try await store.counts()
        XCTAssertEqual(counts.nodes, 1)
    }

    func testIngestTask_KnownProjectFromListNames_BecomesProjectNode() async throws {
        await service.ingest(task: task("Ship the lazyflow release notes"))

        let nodes = try await store.fetchAllNodes()
        XCTAssertTrue(nodes.contains { $0.normalizedKey == "lazyflow" && $0.type == .project })
    }

    func testIngestTask_CustomCategory_BecomesTopicNodeLinkedToEntities() async throws {
        await service.ingest(task: task("Send the renewal quote to Microsoft", category: .work))

        let nodes = try await store.fetchAllNodes()
        XCTAssertTrue(nodes.contains { $0.normalizedKey == "work" && $0.type == .topic })

        let edges = try await store.fetchAllEdges()
        XCTAssertTrue(edges.contains {
            $0.relation == .belongsTo && ($0.sourceKey == "microsoft" && $0.targetKey == "work")
        })
    }

    func testIngestTask_NoEntities_LeavesGraphEmpty() async throws {
        await service.ingest(task: task("buy milk"))

        let counts = try await store.counts()
        XCTAssertEqual(counts.nodes, 0)
        XCTAssertEqual(counts.edges, 0)
    }

    // MARK: - Note Ingestion

    func testIngestNote_RecordsEvidenceWithNoteID() async throws {
        let note = QuickNote(text: "Sarah Johnson wants the Microsoft numbers by Friday")
        await service.ingest(note: note)

        let nodes = try await store.fetchAllNodes()
        XCTAssertTrue(nodes.contains { $0.normalizedKey == "johnson sarah" })

        let counts = try await store.counts()
        XCTAssertGreaterThan(counts.evidence, 0)
    }

    // MARK: - Feature Flag Gate

    func testIngest_FlagDisabled_IsNoOp() async throws {
        let gated = KnowledgeGraphIngestionService(
            store: store,
            isEnabled: { false },
            knownProjects: { [] },
            knownTopics: { [] }
        )

        await gated.ingest(task: task("Meet Sarah Johnson at Microsoft"))

        let counts = try await store.counts()
        XCTAssertEqual(counts.nodes, 0)
    }

    // MARK: - Task Deletion

    func testRemoveEvidence_ForDeletedTask_RemovesOnlyThatTasksEvidence() async throws {
        let first = task("Send the invoice to Microsoft")
        let second = task("Send the contract to Microsoft")
        await service.ingest(task: first)
        await service.ingest(task: second)

        await service.removeEvidence(forTaskID: first.id)

        let firstEvidence = try await store.evidence(forTaskID: first.id)
        let secondEvidence = try await store.evidence(forTaskID: second.id)
        XCTAssertTrue(firstEvidence.isEmpty)
        XCTAssertFalse(secondEvidence.isEmpty)
        // Nodes stay — salience decay handles staleness, deletion doesn't rewrite history
        let counts = try await store.counts()
        XCTAssertEqual(counts.nodes, 1)
    }
}
