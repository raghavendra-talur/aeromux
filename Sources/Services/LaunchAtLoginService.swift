import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    private let logger: AppLogger

    init(logger: AppLogger) {
        self.logger = logger
    }

    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    func apply(enabled: Bool) throws -> SMAppService.Status {
        let service = SMAppService.mainApp

        if enabled {
            switch service.status {
            case .enabled, .requiresApproval:
                break
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
        } else {
            switch service.status {
            case .notRegistered, .notFound:
                break
            case .enabled, .requiresApproval:
                try service.unregister()
            @unknown default:
                try service.unregister()
            }
        }

        return service.status
    }

    func sync(enabled: Bool) {
        do {
            let resolvedStatus = try apply(enabled: enabled)
            logger.info("launchAtLogin.sync desired=\(enabled) status=\(resolvedStatus.rawValue)")
        } catch {
            logger.error("launchAtLogin.sync.error \(error.localizedDescription)")
        }
    }
}
