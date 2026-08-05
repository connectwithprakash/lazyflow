import XCTest
import LazyflowCore
@testable import Lazyflow

final class EntityExtractionServiceTests: XCTestCase {

    /// NLTagger NER needs on-device linguistic assets that headless CI
    /// simulators may lack (NER silently returns nothing there). Probe with
    /// an unambiguous sentence and skip NER-dependent tests when unavailable.
    /// The ingestion/retrieval pipeline stays fully tested via the
    /// deterministic gazetteer path; the feature itself fails open by design.
    private func skipUnlessNERAvailable() throws {
        let probe = EntityExtractionService.extract(from: "Tim Cook met Steve Jobs in Paris")
        try XCTSkipIf(probe.isEmpty, "NLTagger NER assets unavailable in this environment")
    }

    // MARK: - Named Entity Recognition

    func testExtract_PersonName_DetectedAsPerson() throws {
        try skipUnlessNERAvailable()
        let entities = EntityExtractionService.extract(from: "Meet Sarah Johnson for lunch")

        XCTAssertTrue(entities.contains { $0.name == "Sarah Johnson" && $0.type == .person })
    }

    func testExtract_OrganizationName_DetectedAsOrganization() throws {
        try skipUnlessNERAvailable()
        let entities = EntityExtractionService.extract(from: "Send the proposal to Microsoft tomorrow")

        XCTAssertTrue(entities.contains { $0.name == "Microsoft" && $0.type == .organization })
    }

    func testExtract_PlaceName_DetectedAsPlace() throws {
        try skipUnlessNERAvailable()
        let entities = EntityExtractionService.extract(from: "Book flights to Paris for the conference")

        XCTAssertTrue(entities.contains { $0.name == "Paris" && $0.type == .place })
    }

    func testExtract_NoEntities_ReturnsEmpty() {
        let entities = EntityExtractionService.extract(from: "buy milk and eggs")

        XCTAssertTrue(entities.isEmpty)
    }

    func testExtract_EmptyText_ReturnsEmpty() {
        XCTAssertTrue(EntityExtractionService.extract(from: "").isEmpty)
        XCTAssertTrue(EntityExtractionService.extract(from: "   ").isEmpty)
    }

    // MARK: - Known Names (user's own lists/categories as gazetteer)

    func testExtract_KnownProjectName_DetectedCaseInsensitively() {
        let entities = EntityExtractionService.extract(
            from: "finish the lazyflow onboarding screen",
            knownProjects: ["Lazyflow"]
        )

        XCTAssertTrue(entities.contains { $0.name == "Lazyflow" && $0.type == .project })
    }

    func testExtract_KnownTopicName_Detected() {
        let entities = EntityExtractionService.extract(
            from: "Review fitness plan for the week",
            knownTopics: ["Fitness"]
        )

        XCTAssertTrue(entities.contains { $0.name == "Fitness" && $0.type == .topic })
    }

    func testExtract_KnownNameRequiresWholeWordMatch() {
        // "art" must not match inside "start"
        let entities = EntityExtractionService.extract(
            from: "start the engine",
            knownTopics: ["Art"]
        )

        XCTAssertFalse(entities.contains { $0.type == .topic })
    }

    // MARK: - Dedup & Confidence

    func testExtract_SameEntityViaNERAndKnownNames_DedupsKeepingHigherConfidence() {
        let entities = EntityExtractionService.extract(
            from: "Sync with Acme about the renewal",
            knownProjects: ["Acme"]
        )

        let acmeMatches = entities.filter { KnowledgeKey.normalize($0.name) == "acme" }
        XCTAssertEqual(acmeMatches.count, 1, "Same normalized entity must appear once")
    }

    func testExtract_EntitiesCarryConfidenceAboveZero() throws {
        try skipUnlessNERAvailable()
        // Note: NLTagger recall drops on short imperative titles ("Email X the Y");
        // prepositional phrasing is reliable. Known tier-1 limitation, mitigated
        // by the known-names gazetteer.
        let entities = EntityExtractionService.extract(from: "Meet Sarah Johnson at Microsoft")

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.allSatisfy { $0.confidence > 0 && $0.confidence <= 1 })
    }

    func testExtract_Deterministic() {
        let text = "Meet Sarah Johnson at Microsoft in Paris"
        let first = EntityExtractionService.extract(from: text)
        let second = EntityExtractionService.extract(from: text)

        XCTAssertEqual(first, second)
    }
}
