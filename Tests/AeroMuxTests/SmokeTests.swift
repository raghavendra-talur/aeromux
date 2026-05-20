import XCTest
@testable import AeroMux

final class SmokeTests: XCTestCase {
    func test_appLogger_constructs() {
        _ = AppLogger()
    }
}
