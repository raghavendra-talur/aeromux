import XCTest
@testable import AeroMux

final class AeroSpaceConfigServiceTests: XCTestCase {
    func test_parseReservedLeftGap_ignoresCommentedPerMonitorExampleBeforeActiveZero() {
        let config = """
        [gaps]
            #outer.left = [{ monitor.main = 180 }, 0]
            outer.left = 0
        """

        XCTAssertEqual(AeroSpaceConfigService.parseReservedLeftGap(from: config), 0)
    }

    func test_parseReservedLeftGap_parsesPerMonitorMainGap() {
        let config = """
        [gaps]
            outer.left = [{ monitor.main = 260 }, 0]
        """

        XCTAssertEqual(AeroSpaceConfigService.parseReservedLeftGap(from: config), 260)
    }

    func test_parseReservedLeftGap_ignoresInlineCommentAfterActiveValue() {
        let config = """
        [gaps]
            outer.left = 0 # keep AeroMux floating until gap is configured
        """

        XCTAssertEqual(AeroSpaceConfigService.parseReservedLeftGap(from: config), 0)
    }
}
