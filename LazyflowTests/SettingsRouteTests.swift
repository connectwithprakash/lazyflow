import XCTest
@testable import Lazyflow

final class SettingsRouteTests: XCTestCase {

    // MARK: - Case Count

    func testAllCasesCount() {
        #if DEBUG
        XCTAssertEqual(SettingsRoute.allCases.count, 6, "DEBUG should have 6 cases (includes developer)")
        #else
        XCTAssertEqual(SettingsRoute.allCases.count, 5, "Release should have 5 cases")
        #endif
    }

    // MARK: - Identity & Uniqueness

    func testRawValuesAreUnique() {
        let rawValues = SettingsRoute.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "Raw values must be unique")
    }

    func testIdentifiable_IdEqualsRawValue() {
        for route in SettingsRoute.allCases {
            XCTAssertEqual(route.id, route.rawValue, "\(route) id should equal rawValue")
        }
    }

    // MARK: - Metadata

    func testTitlesAreNonEmpty() {
        for route in SettingsRoute.allCases {
            XCTAssertFalse(route.title.isEmpty, "\(route.rawValue) should have a non-empty title")
        }
    }

    func testSubtitlesAreNonEmpty() {
        for route in SettingsRoute.allCases {
            XCTAssertFalse(route.subtitle.isEmpty, "\(route.rawValue) should have a non-empty subtitle")
        }
    }

    func testIconsAreNonEmpty() {
        for route in SettingsRoute.allCases {
            XCTAssertFalse(route.icon.isEmpty, "\(route.rawValue) should have a non-empty icon")
        }
    }

    func testAccessibilityIdentifiers() {
        for route in SettingsRoute.allCases {
            XCTAssertEqual(
                route.accessibilityIdentifier,
                "settings_route_\(route.rawValue)",
                "\(route.rawValue) accessibility identifier should follow naming convention"
            )
        }
    }

    func testSpecificRouteMetadata_General() {
        let route = SettingsRoute.general
        XCTAssertEqual(route.title, "General")
        XCTAssertEqual(route.icon, "slider.horizontal.3")
        XCTAssertEqual(route.subtitle, "Appearance, tasks & accessibility")
    }

    // MARK: - Search Matching

    func testMatchesEmptyQuery() {
        for route in SettingsRoute.allCases {
            XCTAssertTrue(route.matches(""), "\(route.rawValue) should match empty query")
        }
    }

    func testMatchesTitleExact() {
        XCTAssertTrue(SettingsRoute.general.matches("General"))
    }

    func testMatchesTitleCaseInsensitive() {
        XCTAssertTrue(SettingsRoute.general.matches("general"))
    }

    func testMatchesSubstringInSubtitle() {
        // Productivity subtitle: "Calendar, focus & live activity"
        XCTAssertTrue(SettingsRoute.productivity.matches("calendar"))
    }

    func testMatchesNoResult() {
        for route in SettingsRoute.allCases {
            XCTAssertFalse(route.matches("xyznonexistent"), "\(route.rawValue) should not match nonsense query")
        }
    }

    func testMatchesPartialWord() {
        // General subtitle: "Appearance, tasks & accessibility"
        XCTAssertTrue(SettingsRoute.general.matches("Appear"))
    }
}
