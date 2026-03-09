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

    var errorDescription: String? {
        switch self {
        case let .launchFailure(message), let .nonZeroExit(message):
            return message
        }
    }
}

final class ProcessCommandRunner: CommandRunning, @unchecked Sendable {
    private let logger: AppLogger

    init(logger: AppLogger) {
        self.logger = logger
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

            process.terminationHandler = { process in
                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: CommandResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
            }

            do {
                self.logger.debug("command.run \(launchPath) \(arguments.joined(separator: " "))")
                try process.run()
            } catch {
                continuation.resume(throwing: CommandError.launchFailure("Failed to run \(launchPath): \(error.localizedDescription)"))
            }
        }
    }
}
