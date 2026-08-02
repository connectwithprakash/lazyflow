import CoreData
import XCTest
import LazyflowCore
@testable import Lazyflow

final class KnowledgeGraphStoreTests: XCTestCase {

    private var persistence: PersistenceController!
    private var store: KnowledgeGraphStore!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true, enableCloudKit: false)
        store = KnowledgeGraphStore(persistenceController: persistence)
    }

    override func tearDown() {
        store = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Key Normalization (LazyflowCore)

    func testNormalize_LowercasesFoldsAndSortsTokens() {
        XCTAssertEqual(KnowledgeKey.normalize("Smith, John"), "john smith")
        XCTAssertEqual(KnowledgeKey.normalize("john SMITH"), "john smith")
        XCTAssertEqual(KnowledgeKey.normalize("Beyoncé"), "beyonce")
        XCTAssertEqual(KnowledgeKey.normalize("  Acme   Corp.  "), "acme corp")
    }

    func testEdgeKey_IsDeterministic() {
        let key = KnowledgeKey.edgeKey(source: "john smith", relation: .mentions, target: "acme")
        XCTAssertEqual(key, "john smith|mentions|acme")
    }

    // MARK: - Node Upsert

    func testUpsertNode_CreatesNodeWithNormalizedKey() async throws {
        let node = try await store.upsertNode(displayName: "Acme Corp.", type: .organization)

        XCTAssertEqual(node.normalizedKey, "acme corp")
        XCTAssertEqual(node.displayName, "Acme Corp.")
        XCTAssertEqual(node.type, .organization)
        XCTAssertEqual(node.mentionCount, 1)
    }

    func testUpsertNode_SameKeyTwice_DedupsAndBumpsMentionCount() async throws {
        _ = try await store.upsertNode(displayName: "John Smith", type: .person)
        let second = try await store.upsertNode(displayName: "Smith, John", type: .person)

        XCTAssertEqual(second.mentionCount, 2)
        let counts = try await store.counts()
        XCTAssertEqual(counts.nodes, 1)
    }

    func testUpsertNode_KeepsMaxConfidence() async throws {
        _ = try await store.upsertNode(displayName: "Acme", type: .organization, confidence: 0.9)
        let updated = try await store.upsertNode(displayName: "acme", type: .organization, confidence: 0.3)

        XCTAssertEqual(updated.confidence, 0.9, accuracy: 0.0001)
    }

    func testUpsertNode_EmptyName_Throws() async {
        do {
            _ = try await store.upsertNode(displayName: "  …  ", type: .topic)
            XCTFail("Expected emptyKey error")
        } catch let error as KnowledgeGraphStoreError {
            XCTAssertEqual(error, .emptyKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Edge Upsert

    func testUpsertEdge_CreatesEdgeBetweenExistingNodes() async throws {
        _ = try await store.upsertNode(displayName: "John", type: .person)
        _ = try await store.upsertNode(displayName: "Acme", type: .organization)

        let edge = try await store.upsertEdge(sourceKey: "john", targetKey: "acme", relation: .mentions)

        XCTAssertEqual(edge.sourceKey, "john")
        XCTAssertEqual(edge.targetKey, "acme")
        XCTAssertEqual(edge.relation, .mentions)
        XCTAssertEqual(edge.evidenceCount, 1)
    }

    func testUpsertEdge_SameEdgeTwice_ReinforcesInsteadOfDuplicating() async throws {
        _ = try await store.upsertNode(displayName: "John", type: .person)
        _ = try await store.upsertNode(displayName: "Acme", type: .organization)

        _ = try await store.upsertEdge(sourceKey: "john", targetKey: "acme", relation: .mentions, weightDelta: 1)
        let second = try await store.upsertEdge(sourceKey: "john", targetKey: "acme", relation: .mentions, weightDelta: 2)

        XCTAssertEqual(second.evidenceCount, 2)
        XCTAssertEqual(second.weight, 3, accuracy: 0.0001)
        let counts = try await store.counts()
        XCTAssertEqual(counts.edges, 1)
    }

    func testUpsertEdge_MissingEndpoint_Throws() async throws {
        _ = try await store.upsertNode(displayName: "John", type: .person)

        do {
            _ = try await store.upsertEdge(sourceKey: "john", targetKey: "ghost", relation: .relatedTo)
            XCTFail("Expected missingEndpoint error")
        } catch is KnowledgeGraphStoreError {
            // expected
        }
    }

    // MARK: - Fetch & Delete

    func testFetchAll_RoundTripsNodesAndEdges() async throws {
        _ = try await store.upsertNode(displayName: "John", type: .person)
        _ = try await store.upsertNode(displayName: "Acme", type: .organization)
        _ = try await store.upsertEdge(sourceKey: "john", targetKey: "acme", relation: .mentions)

        let nodes = try await store.fetchAllNodes()
        let edges = try await store.fetchAllEdges()

        XCTAssertEqual(Set(nodes.map(\.normalizedKey)), ["john", "acme"])
        XCTAssertEqual(edges.count, 1)
        XCTAssertEqual(edges[0].edgeKey, "john|mentions|acme")
    }

    func testDeleteNode_CascadesItsEdges() async throws {
        _ = try await store.upsertNode(displayName: "John", type: .person)
        _ = try await store.upsertNode(displayName: "Acme", type: .organization)
        _ = try await store.upsertEdge(sourceKey: "john", targetKey: "acme", relation: .mentions)

        try await store.deleteNode(forKey: "john")

        let counts = try await store.counts()
        XCTAssertEqual(counts.nodes, 1)
        XCTAssertEqual(counts.edges, 0, "Edges must cascade when an endpoint node is deleted")
    }

    // MARK: - Evidence

    func testAddEvidence_LinksNodeToSourceTaskByUUID() async throws {
        let node = try await store.upsertNode(displayName: "Acme", type: .organization)
        let taskID = UUID()

        _ = try await store.addEvidence(nodeID: node.id, sourceTaskID: taskID, snippet: "Call Acme")

        let found = try await store.evidence(forTaskID: taskID)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].nodeID, node.id)
        XCTAssertEqual(found[0].snippet, "Call Acme")
    }

    // MARK: - Store Isolation (the point of the LocalGraph configuration)

    func testGraphEntities_LiveInLocalGraphStore_TasksInCloudStore() async throws {
        _ = try await store.upsertNode(displayName: "Acme", type: .organization)

        let context = persistence.viewContext
        let nodeRequest = KnowledgeNodeEntity.fetchRequest()
        let nodes = try context.fetch(nodeRequest)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(
            nodes[0].objectID.persistentStore?.configurationName,
            PersistenceController.graphConfigurationName,
            "Graph entities must live in the local-only store"
        )

        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Test task"
        task.createdAt = Date()
        try context.save()
        XCTAssertEqual(
            task.objectID.persistentStore?.configurationName,
            PersistenceController.cloudConfigurationName,
            "User data must stay in the cloud-synced store"
        )
    }

    func testDeleteAllGraphData_LeavesUserDataIntact() async throws {
        _ = try await store.upsertNode(displayName: "John", type: .person)
        _ = try await store.upsertNode(displayName: "Acme", type: .organization)
        _ = try await store.upsertEdge(sourceKey: "john", targetKey: "acme", relation: .mentions)

        let context = persistence.viewContext
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Survivor"
        try context.save()

        try await store.deleteAllGraphData()

        let counts = try await store.counts()
        XCTAssertEqual(counts.nodes, 0)
        XCTAssertEqual(counts.edges, 0)
        XCTAssertEqual(counts.evidence, 0)
        let tasks = try context.fetch(TaskEntity.fetchRequest())
        XCTAssertEqual(tasks.count, 1, "Wiping the graph must not touch user data")
    }
}
