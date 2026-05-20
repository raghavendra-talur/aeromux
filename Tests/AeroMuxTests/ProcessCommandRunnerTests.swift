import Foundation
import XCTest
@testable import AeroMux

final class ProcessCommandRunnerTests: XCTestCase {
    func test_run_timesOut_whenCommandHangs() async {
        let runner = ProcessCommandRunner(logger: AppLogger(), timeoutSeconds: 0.5)
        do {
            _ = try await runner.run("/bin/sleep", arguments: ["10"])
            XCTFail("expected a timeout error")
        } catch let error as CommandError {
            guard case .timedOut = error else {
                return XCTFail("expected .timedOut, got \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_run_fastCommand_succeeds() async throws {
        let runner = ProcessCommandRunner(logger: AppLogger(), timeoutSeconds: 3)
        let result = try await runner.run("/bin/echo", arguments: ["hello"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }
}
