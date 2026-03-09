import OSLog

struct AppLogger: Sendable {
    private let logger = Logger(subsystem: "com.rtalur.aeromux", category: "app")

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
