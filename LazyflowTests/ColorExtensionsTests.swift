import SwiftUI
import XCTest
import LazyflowCore
@testable import Lazyflow

final class ColorExtensionsTests: XCTestCase {

    // MARK: - Hex Initialization

    func testHexInit_SixCharWithHash() {
        let color = Color(hex: "#218A8D")
        XCTAssertNotNil(color)
    }

    func testHexInit_SixCharWithoutHash() {
        let color = Color(hex: "218A8D")
        XCTAssertNotNil(color)
    }

    func testHexInit_EightChar_WithAlpha() {
        let color = Color(hex: "#218A8DFF")
        XCTAssertNotNil(color)
    }

    func testHexInit_InvalidHex_ReturnsNil() {
        XCTAssertNil(Color(hex: "ZZZZZZ"))
    }

    func testHexInit_WrongLength_ReturnsNil() {
        XCTAssertNil(Color(hex: "#FFF"))
        XCTAssertNil(Color(hex: "#FFFFF"))
    }

    func testHexInit_EmptyString_ReturnsNil() {
        XCTAssertNil(Color(hex: ""))
    }

    func testHexInit_WhitespaceHandled() {
        let color = Color(hex: "  #218A8D  ")
        XCTAssertNotNil(color)
    }

    func testHexInit_Black() {
        let color = Color(hex: "#000000")
        XCTAssertNotNil(color)
    }

    func testHexInit_White() {
        let color = Color(hex: "#FFFFFF")
        XCTAssertNotNil(color)
    }

    // MARK: - Hex Roundtrip

    func testToHex_Roundtrip() {
        let original = Color(hex: "#218A8D")!
        let hex = original.toHex()
        XCTAssertNotNil(hex)
        XCTAssertTrue(hex!.hasPrefix("#"))
        XCTAssertEqual(hex!.count, 7)

        // Verify the roundtrip produces a similar color by re-parsing
        let roundtripped = Color(hex: hex!)
        XCTAssertNotNil(roundtripped, "Roundtripped hex should be a valid color")
    }

    func testToHex_KnownColors() {
        // Black should produce #000000
        let blackHex = Color(hex: "#000000")!.toHex()
        XCTAssertEqual(blackHex, "#000000")

        // White should produce #FFFFFF
        let whiteHex = Color(hex: "#FFFFFF")!.toHex()
        XCTAssertEqual(whiteHex, "#FFFFFF")
    }

    // MARK: - App Colors

    func testLazyflowColors_NotNil() {
        // These are all force-unwrapped in the source — verify they don't crash
        _ = Color.Lazyflow.accent
        _ = Color.Lazyflow.accentLight
        _ = Color.Lazyflow.accentDark
        _ = Color.Lazyflow.backgroundLight
        _ = Color.Lazyflow.backgroundDark
        _ = Color.Lazyflow.surfaceLight
        _ = Color.Lazyflow.surfaceDark
        _ = Color.Lazyflow.textPrimary
        _ = Color.Lazyflow.textSecondary
        _ = Color.Lazyflow.textTertiary
        _ = Color.Lazyflow.success
        _ = Color.Lazyflow.error
        _ = Color.Lazyflow.warning
        _ = Color.Lazyflow.info
        _ = Color.Lazyflow.priorityUrgent
        _ = Color.Lazyflow.priorityHigh
        _ = Color.Lazyflow.priorityMedium
        _ = Color.Lazyflow.priorityLow
        _ = Color.Lazyflow.priorityNone
    }

    // MARK: - Adaptive Colors

    func testAdaptiveBackground_DoesNotCrash() {
        _ = Color.adaptiveBackground
    }

    func testAdaptiveSurface_DoesNotCrash() {
        _ = Color.adaptiveSurface
    }
}
