import XCTest
@testable import AeroMux

final class RefreshCoordinatorBackoffTests: XCTestCase {
    func test_belowThreshold_returnsBase() {
        XCTAssertEqual(RefreshCoordinator.pollingInterval(base: 1, consecutiveFailures: 0), 1)
        XCTAssertEqual(RefreshCoordinator.pollingInterval(base: 1, consecutiveFailures: 2), 1)
    }

    func test_atAndAboveThreshold_growsExponentially() {
        XCTAssertEqual(RefreshCoordinator.pollingInterval(base: 1, consecutiveFailures: 3), 2)
        XCTAssertEqual(RefreshCoordinator.pollingInterval(base: 1, consecutiveFailures: 4), 4)
        XCTAssertEqual(RefreshCoordinator.pollingInterval(base: 1, consecutiveFailures: 5), 8)
    }

    func test_cappedAtMaxInterval() {
        XCTAssertEqual(RefreshCoordinator.pollingInterval(base: 1, consecutiveFailures: 20), 30)
    }
}
