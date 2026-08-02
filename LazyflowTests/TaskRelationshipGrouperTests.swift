import XCTest
import LazyflowCore
@testable import Lazyflow

final class TaskRelationshipGrouperTests: XCTestCase {

    // MARK: - Helpers

    private func task(_ title: String) -> LazyflowCore.Task {
        LazyflowCore.Task(title: title)
    }

    // MARK: - Grouping

    func testGroups_TasksSharingSalientToken_AreGrouped() {
        let tasks = [
            task("Call John about Acme contract"),
            task("Prep Acme demo for Friday"),
            task("Buy groceries")
        ]

        let groups = TaskRelationshipGrouper.groups(for: tasks)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].anchor, "acme")
        XCTAssertEqual(groups[0].titles.count, 2)
        XCTAssertTrue(groups[0].titles.contains("Call John about Acme contract"))
        XCTAssertTrue(groups[0].titles.contains("Prep Acme demo for Friday"))
    }

    func testGroups_NoSharedTokens_ReturnsEmpty() {
        let tasks = [
            task("Buy groceries"),
            task("Schedule dentist appointment"),
            task("Water the plants")
        ]

        XCTAssertTrue(TaskRelationshipGrouper.groups(for: tasks).isEmpty)
    }

    func testGroups_StopwordsAndShortTokensDoNotAnchor() {
        // "the", "for", "and" are stopwords; "to" is too short — none may form a group
        let tasks = [
            task("Go to the bank and the post office"),
            task("Take the dog for a walk to the park")
        ]

        let groups = TaskRelationshipGrouper.groups(for: tasks)

        XCTAssertTrue(
            groups.allSatisfy { $0.anchor.count >= 3 },
            "Anchors must be salient tokens, got: \(groups.map(\.anchor))"
        )
        XCTAssertFalse(groups.contains { ["the", "for", "and", "to"].contains($0.anchor) })
    }

    func testGroups_TokenInMostTasks_IsTooGenericToAnchor() {
        // "meeting" appears in 3 of 4 tasks (75% > 60% cap) — too generic to signal a relationship
        let tasks = [
            task("Prepare meeting agenda"),
            task("Book meeting room"),
            task("Send meeting notes"),
            task("Buy groceries")
        ]

        let groups = TaskRelationshipGrouper.groups(for: tasks)

        XCTAssertFalse(groups.contains { $0.anchor == "meeting" })
    }

    func testGroups_CaseAndDiacriticsNormalized() {
        let tasks = [
            task("Email BEYONCÉ tickets to mom"),
            task("Print beyonce tickets")
        ]

        let groups = TaskRelationshipGrouper.groups(for: tasks)

        XCTAssertTrue(groups.contains { $0.anchor == "beyonce" })
    }

    func testGroups_RespectsMaxGroupsCap() {
        let tasks = [
            task("Alpha report draft"), task("Alpha report review"),
            task("Bravo launch plan"), task("Bravo launch checklist"),
            task("Charlie budget sheet"), task("Charlie budget approval"),
            task("Delta sync notes"), task("Delta sync agenda")
        ]

        let groups = TaskRelationshipGrouper.groups(for: tasks, maxGroups: 2)

        XCTAssertEqual(groups.count, 2)
    }

    func testGroups_MinGroupSizeIsTwo() {
        let tasks = [
            task("Renew passport"),
            task("Buy milk")
        ]

        XCTAssertTrue(TaskRelationshipGrouper.groups(for: tasks).isEmpty)
    }

    func testGroups_PersonNameSharedAcrossTasks_Groups() {
        let tasks = [
            task("Meet Sarah Johnson for lunch"),
            task("Email Sarah Johnson the quarterly report"),
            task("Fix the garden fence")
        ]

        let groups = TaskRelationshipGrouper.groups(for: tasks)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].titles.count, 2)
    }

    func testGroups_DuplicateTaskSetsCollapseToOneGroup() {
        // "acme" and "contract" both match the same two tasks — one group, not two
        let tasks = [
            task("Review Acme contract terms"),
            task("Sign Acme contract"),
            task("Buy groceries")
        ]

        let groups = TaskRelationshipGrouper.groups(for: tasks)

        XCTAssertEqual(groups.count, 1)
    }

    func testGroups_Deterministic() {
        let tasks = [
            task("Call John about Acme contract"),
            task("Prep Acme demo for Friday"),
            task("Email John the slides"),
            task("Buy groceries")
        ]

        let first = TaskRelationshipGrouper.groups(for: tasks)
        let second = TaskRelationshipGrouper.groups(for: tasks)

        XCTAssertEqual(first.map(\.anchor), second.map(\.anchor))
        XCTAssertEqual(first.map(\.titles), second.map(\.titles))
    }

    func testGroups_EmptyInput_ReturnsEmpty() {
        XCTAssertTrue(TaskRelationshipGrouper.groups(for: []).isEmpty)
    }

    // MARK: - Prompt Section

    func testPromptSection_FormatsGroupsAsLines() {
        let tasks = [
            task("Call John about Acme contract"),
            task("Prep Acme demo for Friday"),
            task("Buy groceries")
        ]
        let groups = TaskRelationshipGrouper.groups(for: tasks)

        let section = TaskRelationshipGrouper.promptSection(for: groups)

        XCTAssertNotNil(section)
        XCTAssertTrue(section!.contains("acme"))
        XCTAssertTrue(section!.contains("Call John about Acme contract"))
        XCTAssertTrue(section!.contains("Prep Acme demo for Friday"))
    }

    func testPromptSection_EmptyGroups_ReturnsNil() {
        XCTAssertNil(TaskRelationshipGrouper.promptSection(for: []))
    }

    func testPromptSection_StaysWithinCharacterBudget() throws {
        // Six distinct long-titled groups must render trimmed, not blow the budget.
        // Each pair shares a unique anchor; the common words are diluted across
        // enough distinct tasks to stay below the generic-token cutoff.
        let anchors = ["kestrel", "wombat", "granite", "meridian", "obsidian", "juniper"]
        let tasks = anchors.flatMap { anchor in
            [
                task("Draft the exhaustive \(anchor) initiative rollout memorandum before quarter close"),
                task("Circulate the exhaustive \(anchor) initiative rollout memorandum before quarter close")
            ]
        }
        let groups = TaskRelationshipGrouper.groups(for: tasks, maxGroups: 6)
        XCTAssertGreaterThan(groups.count, 1, "Fixture must produce multiple groups")

        let section = try XCTUnwrap(TaskRelationshipGrouper.promptSection(for: groups))

        XCTAssertLessThanOrEqual(section.count, TaskRelationshipGrouper.maxPromptSectionCharacters)
    }
}
