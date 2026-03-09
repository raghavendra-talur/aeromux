import Foundation
import Network

final class RefreshBridgeServer: @unchecked Sendable {
    private let logger: AppLogger
    private let onRefresh: @Sendable () async -> Void
    private var listener: NWListener?

    init(logger: AppLogger, onRefresh: @escaping @Sendable () async -> Void) {
        self.logger = logger
        self.onRefresh = onRefresh
    }

    func start(port: UInt16 = 39173) {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = false
            let localPort = NWEndpoint.Port(rawValue: port)!
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: localPort)

            let listener = try NWListener(using: parameters)
            let logger = self.logger
            let refreshHandler = self.onRefresh

            listener.newConnectionHandler = { connection in
                Self.handle(connection: connection, logger: logger, onRefresh: refreshHandler)
            }
            listener.stateUpdateHandler = { state in
                logger.debug("bridge.state \(String(describing: state))")
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
        } catch {
            logger.error("bridge.start.failed \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private static func handle(connection: NWConnection, logger: AppLogger, onRefresh: @escaping @Sendable () async -> Void) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
            let request = String(data: data ?? Data(), encoding: .utf8) ?? ""
            logger.info("bridge.request \(request.split(separator: "\n").first ?? "")")
            if request.hasPrefix("POST /refresh") || request.hasPrefix("GET /refresh") {
                Task {
                    await onRefresh()
                }
            }
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/plain\r
            Content-Length: 2\r
            \r
            OK
            """
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
