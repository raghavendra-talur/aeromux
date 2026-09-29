import AppKit
import SwiftUI
import XCTest
@testable import AeroMux

final class WorkspaceColorTests: XCTestCase {
    func test_hex_roundTrips() {
        XCTAssertEqual(Color(aeroMuxHex: "#89b4fa")?.aeroMuxHex, "#89b4fa")
        XCTAssertEqual(Color(aeroMuxHex: "a6e3a1")?.aeroMuxHex, "#a6e3a1")
        XCTAssertEqual(Color(aeroMuxHex: "  #FFFFFF\n")?.aeroMuxHex, "#ffffff")
        XCTAssertEqual(Color(aeroMuxHex: "#000000")?.aeroMuxHex, "#000000")
    }

    func test_hex_rejectsMalformedInput() {
        for input in ["", "#", "#fff", "#1234567", "#gggggg", "+12345", "-12345", "#12 345"] {
            XCTAssertNil(Color(aeroMuxHex: input), "expected nil for \(input.debugDescription)")
        }
    }

    func test_hex_clampsOutOfGamutComponents() {
        let wideGamut = Color(NSColor(srgbRed: 1.2, green: -0.1, blue: 0.5, alpha: 1))
        XCTAssertEqual(wideGamut.aeroMuxHex, "#ff0080")
    }

    func test_resolvedColor_fallsBackToDefaultForInvalidOverride() {
        let valid = makeGroup(name: "1", colorOverride: "#123456")
        XCTAssertEqual(valid.resolvedColor.aeroMuxHex, "#123456")

        let invalid = makeGroup(name: "1", colorOverride: "not-a-color")
        XCTAssertEqual(invalid.resolvedColor.aeroMuxHex, "#89b4fa")

        let unset = makeGroup(name: "2", colorOverride: nil)
        XCTAssertEqual(unset.resolvedColor.aeroMuxHex, "#a6e3a1")
    }

    private func makeGroup(name: String, colorOverride: String?) -> WorkspaceGroup {
        WorkspaceGroup(
            workspaceName: name,
            windows: [],
            isFocused: false,
            titleOverride: nil,
            descriptionOverride: nil,
            colorOverride: colorOverride
        )
    }
}
