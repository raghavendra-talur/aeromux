# Design: AeroSpace command timeout, single-flight, and circuit breaker

**Date:** 2026-05-20
**Status:** Approved (pending spec review)

## Problem

All AeroSpace integration runs `aerospace` CLI subprocesses through
`ProcessCommandRunner.run`. That method bridges `Process` into async via
`withCheckedThrowingContinuation`, resuming **only** from the process's
`terminationHandler`. If an `aerospace` command hangs and never exits, the
continuation never resumes — the call hangs forever.

Because `RefreshCoordinator` polls every ~1s and calls `requestRefresh`
unconditionally, a single hung command leads to:

- An in-flight `performRefresh` that never completes.
- New polling-triggered refreshes piling on top of it.
- Continued spawning of new `aerospace` processes against an already-stuck
  window manager.

The user has observed `aerospace` commands hanging in practice.

## Goals

1. A single hung `aerospace` command must fail within a bounded time, and its
   OS process must be killed (no zombie/stuck processes accumulating).
2. Refreshes must not overlap — a new polling tick is skipped while a refresh
   is still running.
3. When `aerospace` is repeatedly unresponsive, polling backs off
   exponentially instead of hammering it, and recovers automatically once a
   command succeeds.

## Non-goals

- Making the timeout or backoff parameters user-configurable. They are
  hardcoded constants for now.
- Changing the parsing logic in `AeroSpaceClient` or the CLI commands used.

## Design

### 1. Per-command timeout (`Sources/Services/ProcessCommandRunner.swift`)

Add a hardcoded timeout constant of **3 seconds** to `ProcessCommandRunner`.

Restructure `run(_:arguments:)` so the launched `Process` races a timeout:

- The process is launched as today, with `terminationHandler` capturing
  stdout/stderr/exit code.
- A timeout path waits 3s. On expiry it terminates the process: send `SIGTERM`
  via `process.terminate()`; if the process is still running a short grace
  period later (e.g. 200ms), send `SIGKILL` (`kill(process.processIdentifier,
  SIGKILL)`).
- Whichever path completes first wins. A resume guard (an `NSLock`-protected
  `hasResumed` flag, or equivalent) ensures the underlying continuation
  resumes **exactly once** — never both from `terminationHandler` and the
  timeout.
- On timeout, throw the new error case (below) rather than returning a
  `CommandResult`.

Add a new case to `CommandError`:

```swift
case timedOut(String)
```

with `errorDescription` returning the message. The thrown message is of the
form `"aerospace <args> timed out after 3s"`.

**Implementation approach:** A clean structured-concurrency formulation is to
keep a private continuation-based launch that returns the `CommandResult`, and
wrap it so that a timeout cancels/kills the process. The exact mechanism
(task group with a sleeping timeout task + `withTaskCancellationHandler` to
terminate the process, vs. a manual `DispatchSource`/timer alongside the
continuation) is left to the implementation plan, provided the
exactly-once-resume and kill-the-process guarantees hold.

### Interaction with `AeroSpaceClient.runAeroSpace`

No structural change needed. `runAeroSpace` already wraps `commandRunner.run`
in `do/catch`:

- For `allowFailure: true` calls (`list-workspaces --json`, `list-windows
  --focused --json`, `list-monitors --json`), a thrown timeout currently maps
  to `binaryMissing` in the existing `catch`. This is misleading. Update the
  `catch` to distinguish a genuine launch failure from other command errors
  (including timeout): on `allowFailure`, return `nil`; otherwise rethrow a
  `commandFailed` carrying the underlying message. This keeps timeouts
  surfacing as transient failures rather than a permanent "binary missing"
  state.

### 2. Single-flight guard (`Sources/Services/RefreshCoordinator.swift`)

Add an `isRefreshing` boolean to the `@MainActor`-isolated coordinator.

- `performRefresh` sets `isRefreshing = true` on entry and clears it in a
  `defer` on exit.
- `requestRefresh(reason:)` for `reason == .polling` returns early (debug log
  `refresh.skip.inflight`) when `isRefreshing` is already true.
- Non-polling triggers (`startup`, `bridge`, `manual`) keep their current
  behavior (cancel + 75ms debounce), so user-initiated refreshes still feel
  responsive. They will naturally serialize because `performRefresh` is
  `@MainActor` and awaits.

### 3. Circuit breaker / backoff (`Sources/Services/RefreshCoordinator.swift`)

Track `consecutiveFailures: Int`.

- In `performRefresh`: on the success path set `consecutiveFailures = 0`; in
  the `catch` increment it.
- The polling loop computes its sleep interval as:

  ```
  let base = max(settings.pollInterval, 0.25)
  let interval = base * backoffMultiplier(consecutiveFailures)
  ```

  where `backoffMultiplier` returns `1.0` until a threshold of **3**
  consecutive failures, then grows exponentially (`2, 4, 8, …`) with the
  resulting interval capped at **30 seconds**.

Constants (failure threshold = 3, max interval = 30s) are defined in
`RefreshCoordinator`.

This stops new commands from piling onto a stuck `aerospace`, while a single
success immediately restores the normal cadence.

## Testing

Add a `.testTarget` named `AeroMuxTests` to `Package.swift` (path `Tests`),
depending on the `AeroMux` executable target via `@testable import AeroMux`.
Use XCTest (Swift 6 toolchain; swift-testing is also available but XCTest keeps
the addition minimal).

Focused tests:

1. **Timeout kills and throws** — a fake/slow launch path (e.g. point
   `ProcessCommandRunner` at `/bin/sleep 10` or a stub) verifies that `run`
   throws `CommandError.timedOut` within roughly the timeout window and the
   process is no longer running afterward.
2. **Fast command succeeds** — `run` against a quick command (e.g. `/bin/echo`)
   returns the expected `CommandResult` and does not time out.
3. **Backoff math** — extract `backoffMultiplier` (or an interval-computing
   function) so it can be unit-tested directly: returns 1.0 below threshold,
   grows exponentially above it, and respects the 30s cap.
4. **Single-flight** — verify (via an injected `CommandRunning` stub that
   blocks) that a `.polling` `requestRefresh` is skipped while a refresh is in
   flight. Feasible only if the coordinator's collaborators are injectable;
   if wiring this cleanly is disproportionate, this case may be covered by the
   timeout + backoff tests instead.

The repo otherwise has no test suite; `swift build` plus manual observation
remain the primary verification, with `swift test` now available.

## Files touched

- `Sources/Services/ProcessCommandRunner.swift` — timeout, process kill,
  `CommandError.timedOut`.
- `Sources/Services/AeroSpaceClient.swift` — refine the `runAeroSpace` catch so
  timeouts don't masquerade as `binaryMissing`.
- `Sources/Services/RefreshCoordinator.swift` — `isRefreshing` single-flight
  guard, `consecutiveFailures` tracking, backoff in the polling loop.
- `Package.swift` — add `AeroMuxTests` test target.
- `Tests/AeroMuxTests/…` — new focused tests.

## Constants summary

| Constant | Value | Location |
|---|---|---|
| Command timeout | 3s | `ProcessCommandRunner` |
| SIGKILL grace after SIGTERM | ~200ms | `ProcessCommandRunner` |
| Backoff failure threshold | 3 consecutive failures | `RefreshCoordinator` |
| Backoff growth | exponential (2×, 4×, 8×…) | `RefreshCoordinator` |
| Max polling interval | 30s | `RefreshCoordinator` |
