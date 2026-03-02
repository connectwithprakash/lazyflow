import XCTest
@testable import Lazyflow

@MainActor
final class FeatureFlagsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear all overrides before each test
        FeatureFlags.shared.removeAllOverrides()
    }

    override func tearDown() {
        FeatureFlags.shared.removeAllOverrides()
        super.tearDown()
    }

    // MARK: - Default Values

    func testDefaultValues() {
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.aiAutoSuggest))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.aiEstimateDuration))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.aiSuggestPriority))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.aiTaskExtraction))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.quickCapture))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.focusMode))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.morningBriefing))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.dailySummary))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.calendarSync))
        XCTAssertFalse(FeatureFlags.shared.isEnabled(.calendarAutoSync))
    }

    // MARK: - Overrides

    func testSetOverride_EnablesDisabledFlag() {
        XCTAssertFalse(FeatureFlags.shared.isEnabled(.calendarAutoSync))

        FeatureFlags.shared.setOverride(.calendarAutoSync, enabled: true)

        XCTAssertTrue(FeatureFlags.shared.isEnabled(.calendarAutoSync))
    }

    func testSetOverride_DisablesEnabledFlag() {
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.aiAutoSuggest))

        FeatureFlags.shared.setOverride(.aiAutoSuggest, enabled: false)

        XCTAssertFalse(FeatureFlags.shared.isEnabled(.aiAutoSuggest))
    }

    func testHasOverride_ReturnsFalseByDefault() {
        XCTAssertFalse(FeatureFlags.shared.hasOverride(.aiAutoSuggest))
    }

    func testHasOverride_ReturnsTrueAfterSet() {
        FeatureFlags.shared.setOverride(.aiAutoSuggest, enabled: true)
        XCTAssertTrue(FeatureFlags.shared.hasOverride(.aiAutoSuggest))
    }

    func testGetOverride_ReturnsNilByDefault() {
        XCTAssertNil(FeatureFlags.shared.getOverride(.quickCapture))
    }

    func testGetOverride_ReturnsValueAfterSet() {
        FeatureFlags.shared.setOverride(.quickCapture, enabled: false)
        XCTAssertEqual(FeatureFlags.shared.getOverride(.quickCapture), false)
    }

    // MARK: - Remove Override

    func testRemoveOverride_RevertsToDefault() {
        FeatureFlags.shared.setOverride(.aiAutoSuggest, enabled: false)
        XCTAssertFalse(FeatureFlags.shared.isEnabled(.aiAutoSuggest))

        FeatureFlags.shared.removeOverride(.aiAutoSuggest)

        XCTAssertTrue(FeatureFlags.shared.isEnabled(.aiAutoSuggest))
        XCTAssertFalse(FeatureFlags.shared.hasOverride(.aiAutoSuggest))
    }

    func testRemoveAllOverrides() {
        FeatureFlags.shared.setOverride(.aiAutoSuggest, enabled: false)
        FeatureFlags.shared.setOverride(.quickCapture, enabled: false)
        FeatureFlags.shared.setOverride(.calendarAutoSync, enabled: true)

        FeatureFlags.shared.removeAllOverrides()

        XCTAssertTrue(FeatureFlags.shared.isEnabled(.aiAutoSuggest))
        XCTAssertTrue(FeatureFlags.shared.isEnabled(.quickCapture))
        XCTAssertFalse(FeatureFlags.shared.isEnabled(.calendarAutoSync))
        XCTAssertFalse(FeatureFlags.shared.hasOverride(.aiAutoSuggest))
        XCTAssertFalse(FeatureFlags.shared.hasOverride(.quickCapture))
        XCTAssertFalse(FeatureFlags.shared.hasOverride(.calendarAutoSync))
    }

    // MARK: - Flag Metadata

    func testAllFlagsHaveDisplayName() {
        for flag in FeatureFlags.Flag.allCases {
            XCTAssertFalse(flag.displayName.isEmpty, "\(flag.rawValue) should have a display name")
        }
    }

    func testAllFlagsHaveDescription() {
        for flag in FeatureFlags.Flag.allCases {
            XCTAssertFalse(flag.description.isEmpty, "\(flag.rawValue) should have a description")
        }
    }

    func testGroupedFlags_ContainsAllFlags() {
        let grouped = FeatureFlags.groupedFlags
        let totalFlags = grouped.reduce(0) { $0 + $1.flags.count }
        XCTAssertEqual(totalFlags, FeatureFlags.Flag.allCases.count)
    }

    func testGroupedFlags_AllGroupsPresent() {
        let grouped = FeatureFlags.groupedFlags
        let groupNames = Set(grouped.map(\.group))
        XCTAssertEqual(groupNames.count, FeatureFlags.Flag.Group.allCases.count)
    }

    // MARK: - Flag Identity

    func testFlagRawValues_AreUnique() {
        let rawValues = FeatureFlags.Flag.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "Flag raw values must be unique")
    }
}
