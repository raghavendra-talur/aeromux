import Foundation

enum FocusServiceError: Error, LocalizedError {
    case unsupported
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Focusing a window by id is not supported by the configured AeroSpace CLI."
        case let .failed(message):
            return message
        }
    }
}

actor FocusService {
    private let commandRunner: CommandRunning
    private let aerospaceExecutablePath: String?
    private let logger: AppLogger

    init(commandRunner: CommandRunning, aerospaceExecutablePath: String?, logger: AppLogger) {
        self.commandRunner = commandRunner
        self.aerospaceExecutablePath = aerospaceExecutablePath
        self.logger = logger
    }

    func focus(windowId: String) async {
        logger.info("focus.request \(windowId)")
        do {
            guard let aerospaceExecutablePath else {
                throw FocusServiceError.failed("AeroSpace CLI not found.")
            }

            let result = try await commandRunner.run(aerospaceExecutablePath, arguments: ["focus", "--window-id", windowId])
            guard result.exitCode == 0 else {
                if result.stderr.contains("unknown") || result.stderr.contains("Usage") {
                    throw FocusServiceError.unsupported
                }
                throw FocusServiceError.failed(result.stderr.isEmpty ? "Failed to focus window \(windowId)." : result.stderr)
            }
        } catch {
            logger.error("focus.error \(error.localizedDescription)")
        }
    }
}
