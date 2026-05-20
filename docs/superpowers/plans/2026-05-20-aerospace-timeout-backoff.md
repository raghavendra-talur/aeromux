# AeroSpace Command Timeout & Backoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop hung `aerospace` CLI commands from blocking the app forever, and back off polling when AeroSpace is repeatedly unresponsive.

**Architecture:** Add a per-command timeout (3s) to `ProcessCommandRunner` that kills the spawned process and throws `CommandError.timedOut`. Make `RefreshCoordinator` single-flight (skip overlapping polling refreshes) and add an exponential-backoff circuit breaker keyed on consecutive failures. Add a SwiftPM test target for focused unit tests.

**Tech Stack:** Swift 6, SwiftPM, Foundation `Process`, XCTest.

---

## File Structure

- `Package.swift` — add `AeroMuxTests` test target.
- `Sources/Services/ProcessCommandRunner.swift` — timeout + process kill + `CommandError.timedOut`.
- `Sources/Services/AeroSpaceClient.swift` — refine `runAeroSpace` catch so timeouts aren't reported as `binaryMissing`.
- `Sources/Services/RefreshCoordinator.swift` — single-flight guard, `consecutiveFailures` tracking, backoff in polling loop, testable `pollingInterval` helper.
- `Tests/AeroMuxTests/ProcessCommandRunnerTests.swift` — timeout + fast-command tests.
- `Tests/AeroMuxTests/RefreshCoordinatorBackoffTests.swift` — backoff math tests.

---

## Task 1: Add the test target

**Files:**
- Modify: `Package.swift:15-26`
- Create: `Tests/AeroMuxTests/SmokeTests.swift`

- [ ] **Step 1: Add the test target to `Package.swift`**

Replace the `targets:` array so it includes the test target after the executable target:

```swift
    targets: [
        .executableTarget(
            name: "AeroMux",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources",
            exclude: [
                "Resources",
            ]
        ),
        .testTarget(
            name: "AeroMuxTests",
            dependencies: ["AeroMux"],
            path: "Tests/AeroMuxTests"
        ),
    ]
```

- [ ] **Step 2: Create a smoke test that imports the executable target**

Create `Tests/AeroMuxTests/SmokeTests.swift`:

```swift
import XCTest
@testable import AeroMux

final class SmokeTests: XCTestCase {
    func test_appLogger_constructs() {
        _ = AppLogger()
    }
}
```

- [ ] **Step 3: Run the test to confirm the target wires up**

Run: `swift test --filter SmokeTests`
Expected: PASS (1 test). This confirms `@testable import AeroMux` resolves against the executable target.

- [ ] **Step 4: Commit**

```bash
git add Package.swift Tests/AeroMuxTests/SmokeTests.swift
git commit -s -m "Add AeroMuxTests test target

Assisted-by: Claude Code/claude-opus-4-7"
```

---

## Task 2: Per-command timeout in ProcessCommandRunner

**Files:**
- Modify: `Sources/Services/ProcessCommandRunner.swift`
- Create: `Tests/AeroMuxTests/ProcessCommandRunnerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AeroMuxTests/ProcessCommandRunnerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter ProcessCommandRunnerTests`
Expected: Compile failure — `ProcessCommandRunner` has no `timeoutSeconds:` initializer parameter, and `CommandError` has no `.timedOut` case.

- [ ] **Step 3: Rewrite `ProcessCommandRunner.swift`**

Replace the entire contents of `Sources/Services/ProcessCommandRunner.swift` with:

```swift
import Foundation

struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol CommandRunning: Sendable {
    func run(_ launchPath: String, arguments: [String]) async throws -> CommandResult
}

enum CommandError: Error, LocalizedError {
    case launchFailure(String)
    case nonZeroExit(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case let .launchFailure(message), let .nonZeroExit(message), let .timedOut(message):
            return message
        }
    }
}

/// Ensures a continuation is resumed exactly once across the termination and
/// timeout paths.
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if resumed { return false }
        resumed = true
        return true
    }
}

final class ProcessCommandRunner: CommandRunning, @unchecked Sendable {
    private let logger: AppLogger
    private let timeoutSeconds: TimeInterval

    init(logger: AppLogger, timeoutSeconds: TimeInterval = 3) {
        self.logger = logger
        self.timeoutSeconds = timeoutSeconds
    }

    func run(_ launchPath: String, arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let guardState = ResumeGuard()
            let timeoutSeconds = self.timeoutSeconds

            let timeoutItem = DispatchWorkItem {
                guard guardState.claim() else { return }
                Self.kill(process)
                continuation.resume(
                    throwing: CommandError.timedOut(
                        "aerospace \(arguments.joined(separator: " ")) timed out after \(timeoutSeconds)s"
                    )
                )
            }

            process.terminationHandler = { process in
                timeoutItem.cancel()
                guard guardState.claim() else { return }
                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(
                    returning: CommandResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
                )
            }

            do {
                self.logger.debug("command.run \(launchPath) \(arguments.joined(separator: " "))")
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutItem)
            } catch {
                timeoutItem.cancel()
                guard guardState.claim() else { return }
                continuation.resume(
                    throwing: CommandError.launchFailure("Failed to run \(launchPath): \(error.localizedDescription)")
                )
            }
        }
    }

    /// Sends SIGTERM, then SIGKILL after a short grace period if still alive.
    private static func kill(_ process: Process) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            if process.isRunning {
                Foundation.kill(pid, SIGKILL)
            }
        }
    }
}
```

Note: this preserves the existing capture pattern (pipes/process captured in the `@Sendable` `terminationHandler`), which already compiles in this package. If Swift 6 strict-concurrency raises a new error on the `DispatchWorkItem` capture, resolve it minimally (e.g. keep the closure as-is; `ResumeGuard` and `Process` are reference types) without changing behavior.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter ProcessCommandRunnerTests`
Expected: PASS (2 tests). The hang test should complete in well under 2s (timeout 0.5s + 0.2s grace).

- [ ] **Step 5: Build the whole package**

Run: `swift build`
Expected: Builds cleanly (FocusService, AeroSpaceClient, AeroSpaceConfigService all call the same `run` and inherit the timeout automatically).

- [ ] **Step 6: Commit**

```bash
git add Sources/Services/ProcessCommandRunner.swift Tests/AeroMuxTests/ProcessCommandRunnerTests.swift
git commit -s -m "Add 3s timeout that kills hung aerospace processes

Assisted-by: Claude Code/claude-opus-4-7"
```

---

## Task 3: Stop timeouts masquerading as binaryMissing

**Files:**
- Modify: `Sources/Services/AeroSpaceClient.swift:107-128`

- [ ] **Step 1: Replace the `runAeroSpace` method body**

In `Sources/Services/AeroSpaceClient.swift`, replace the `runAeroSpace(arguments:allowFailure:)` method (currently lines 107-128) with:

```swift
    private func runAeroSpace(arguments: [String], allowFailure: Bool) async throws -> String? {
        guard let aerospaceExecutablePath else {
            throw AeroSpaceClientError.binaryMissing
        }

        let result: CommandResult
        do {
            result = try await commandRunner.run(aerospaceExecutablePath, arguments: arguments)
        } catch let error as CommandError {
            switch error {
            case .launchFailure:
                throw AeroSpaceClientError.binaryMissing
            case .timedOut, .nonZeroExit:
                logger.error("aerospace.error args=\(arguments.joined(separator: " ")) \(error.localizedDescription)")
                if allowFailure {
                    return nil
                }
                throw AeroSpaceClientError.commandFailed(error.localizedDescription)
            }
        } catch {
            if allowFailure {
                return nil
            }
            throw AeroSpaceClientError.commandFailed(error.localizedDescription)
        }

        guard result.exitCode == 0 else {
            logger.error("aerospace.failure args=\(arguments.joined(separator: " ")) stderr=\(result.stderr)")
            if allowFailure {
                return nil
            }
            throw AeroSpaceClientError.commandFailed(result.stderr.isEmpty ? "AeroSpace command failed." : result.stderr)
        }

        return result.stdout
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Builds cleanly. Now a true launch failure (`/missing/binary`) still maps to `binaryMissing`, while a timeout maps to a transient `commandFailed` (or `nil` for `allowFailure` calls).

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/AeroSpaceClient.swift
git commit -s -m "Surface aerospace timeouts as transient failures, not binaryMissing

Assisted-by: Claude Code/claude-opus-4-7"
```

---

## Task 4: Backoff math in RefreshCoordinator

**Files:**
- Modify: `Sources/Services/RefreshCoordinator.swift`
- Create: `Tests/AeroMuxTests/RefreshCoordinatorBackoffTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AeroMuxTests/RefreshCoordinatorBackoffTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter RefreshCoordinatorBackoffTests`
Expected: Compile failure — `RefreshCoordinator` has no `pollingInterval` method.

- [ ] **Step 3: Add the `pollingInterval` helper**

In `Sources/Services/RefreshCoordinator.swift`, add this `nonisolated static` method inside the `RefreshCoordinator` class (e.g. just after the `stop()` method). `nonisolated` lets the tests call it without `@MainActor` hops:

```swift
    static let failureThreshold = 3
    static let maxPollInterval: TimeInterval = 30

    /// Polling interval after `consecutiveFailures` failures: `base` until the
    /// failure threshold, then doubling each further failure, capped at
    /// `maxPollInterval`.
    nonisolated static func pollingInterval(
        base: TimeInterval,
        consecutiveFailures: Int,
        failureThreshold: Int = RefreshCoordinator.failureThreshold,
        maxInterval: TimeInterval = RefreshCoordinator.maxPollInterval
    ) -> TimeInterval {
        guard consecutiveFailures >= failureThreshold else { return base }
        let exponent = consecutiveFailures - failureThreshold + 1
        let multiplier = pow(2.0, Double(exponent))
        return min(base * multiplier, maxInterval)
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter RefreshCoordinatorBackoffTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/RefreshCoordinator.swift Tests/AeroMuxTests/RefreshCoordinatorBackoffTests.swift
git commit -s -m "Add exponential backoff helper for refresh polling

Assisted-by: Claude Code/claude-opus-4-7"
```

---

## Task 5: Wire single-flight + backoff into the polling loop

**Files:**
- Modify: `Sources/Services/RefreshCoordinator.swift`

- [ ] **Step 1: Add the tracking properties**

In `RefreshCoordinator`, after the existing `private var pollingTask: Task<Void, Never>?` (line 19), add:

```swift
    private var isRefreshing = false
    private var consecutiveFailures = 0
```

- [ ] **Step 2: Apply backoff in the polling loop**

Replace the `start()` method body's polling task (lines 39-46) with:

```swift
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let base = max(settings.pollInterval, 0.25)
                let interval = Self.pollingInterval(base: base, consecutiveFailures: consecutiveFailures)
                try? await Task.sleep(for: .seconds(interval))
                requestRefresh(reason: .polling)
            }
        }
```

- [ ] **Step 3: Skip overlapping polling refreshes**

Replace the `requestRefresh(reason:)` method (lines 54-61) with:

```swift
    func requestRefresh(reason: TriggerReason) {
        if reason == .polling, isRefreshing {
            logger.debug("refresh.skip.inflight")
            return
        }
        logger.debug("refresh.request \(reason.rawValue)")
        scheduledRefresh?.cancel()
        scheduledRefresh = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(75))
            await self?.performRefresh(reason: reason)
        }
    }
```

- [ ] **Step 4: Track in-flight state and failure count in `performRefresh`**

In `performRefresh(reason:)`, add the in-flight guard at the very top of the method (immediately after the opening brace, before `logger.info("refresh.begin ...")`):

```swift
        isRefreshing = true
        defer { isRefreshing = false }
```

Then, in the same method, on the success path add `consecutiveFailures = 0` immediately before the existing `logger.info("refresh.complete workspace=\(snapshot.workspaceName)")` line:

```swift
            consecutiveFailures = 0
            logger.info("refresh.complete workspace=\(snapshot.workspaceName)")
```

And in the `catch` block, add `consecutiveFailures += 1` before `stateStore.applyError(...)`:

```swift
        } catch {
            consecutiveFailures += 1
            stateStore.applyError(error.localizedDescription)
        }
```

- [ ] **Step 5: Build and run the full test suite**

Run: `swift build && swift test`
Expected: Builds cleanly; all tests pass (SmokeTests, ProcessCommandRunnerTests, RefreshCoordinatorBackoffTests).

- [ ] **Step 6: Commit**

```bash
git add Sources/Services/RefreshCoordinator.swift
git commit -s -m "Make refresh single-flight and back off when aerospace is unresponsive

Assisted-by: Claude Code/claude-opus-4-7"
```

---

## Task 6: Manual verification

**Files:** none (verification only)

- [ ] **Step 1: Verify a hung command recovers using a fake slow binary**

Build the app and run it normally to confirm baseline behavior is unchanged:

Run: `swift build && swift run`
Expected: Sidebar populates from real AeroSpace as before.

- [ ] **Step 2: Confirm the timeout fires for a genuinely slow binary (optional, ad hoc)**

In a scratch test or REPL-style check, point `ProcessCommandRunner` at `/bin/sleep 10` with the default 3s timeout and confirm it throws `.timedOut` after ~3s rather than hanging. (This is the same behavior covered by `test_run_timesOut_whenCommandHangs`; this step is just a sanity check against the default timeout value.)

- [ ] **Step 3: Final full verification**

Run: `swift build && swift test`
Expected: clean build, all tests green.
