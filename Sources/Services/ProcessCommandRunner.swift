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

            // No need to cancel `timeoutItem`: if termination wins the race it
            // claims the guard first, so a late-firing timeout no-ops.
            process.terminationHandler = { process in
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
