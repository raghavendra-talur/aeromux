import Foundation
import AppKit

@MainActor
final class AppEnvironment {
    let logger: AppLogger
    let settings: SettingsStore
    let stateStore: SidebarStateStore
    let focusService: FocusService
    let refreshCoordinator: RefreshCoordinator
    let bridgeServer: RefreshBridgeServer
    let windowController: SidebarWindowController
    let statusItemController: StatusItemController
    let workspaceMemoryStore: WorkspaceMemoryStore

    init() {
        logger = AppLogger()
        settings = SettingsStore(logger: logger)
        workspaceMemoryStore = WorkspaceMemoryStore(logger: logger)
        let aerospaceExecutablePath = AeroSpaceExecutableResolver.resolve()
        let commandRunner = ProcessCommandRunner(logger: logger)
        let client = AeroSpaceClient(
            commandRunner: commandRunner,
            aerospaceExecutablePath: aerospaceExecutablePath,
            logger: logger
        )
        let configService = AeroSpaceConfigService(
            commandRunner: commandRunner,
            aerospaceExecutablePath: aerospaceExecutablePath,
            logger: logger
        )
        stateStore = SidebarStateStore(settings: settings, logger: logger)
        focusService = FocusService(
            commandRunner: commandRunner,
            aerospaceExecutablePath: aerospaceExecutablePath,
            logger: logger
        )
        refreshCoordinator = RefreshCoordinator(
            settings: settings,
            client: client,
            configService: configService,
            workspaceMemoryStore: workspaceMemoryStore,
            stateStore: stateStore,
            logger: logger
        )
        bridgeServer = RefreshBridgeServer(logger: logger) { [weak refreshCoordinator] in
            await refreshCoordinator?.requestRefresh(reason: .bridge)
        }
        windowController = SidebarWindowController(
            settings: settings,
            stateStore: stateStore,
            focusService: focusService,
            workspaceMemoryStore: workspaceMemoryStore,
            refreshCoordinator: refreshCoordinator
        )
        statusItemController = StatusItemController(
            settings: settings,
            refreshCoordinator: refreshCoordinator,
            windowController: windowController
        )
    }

    func start() {
        logger.info("app.start")
        if let appIcon = AppIconProvider.applicationIconImage() {
            NSApplication.shared.applicationIconImage = appIcon
        }
        windowController.showWindow()
        statusItemController.start()
        bridgeServer.start()
        refreshCoordinator.start()
    }

    func stop() {
        logger.info("app.stop")
        statusItemController.stop()
        bridgeServer.stop()
        refreshCoordinator.stop()
    }
}
