import Foundation

@MainActor
final class AppEnvironment {
    let logger: AppLogger
    let settings: SettingsStore
    let stateStore: SidebarStateStore
    let focusService: FocusService
    let refreshCoordinator: RefreshCoordinator
    let bridgeServer: RefreshBridgeServer
    let windowController: SidebarWindowController

    init() {
        logger = AppLogger()
        settings = SettingsStore()
        let commandRunner = ProcessCommandRunner(logger: logger)
        let client = AeroSpaceClient(commandRunner: commandRunner, logger: logger)
        let configService = AeroSpaceConfigService(commandRunner: commandRunner, logger: logger)
        stateStore = SidebarStateStore(settings: settings, logger: logger)
        focusService = FocusService(commandRunner: commandRunner, logger: logger)
        refreshCoordinator = RefreshCoordinator(
            settings: settings,
            client: client,
            configService: configService,
            stateStore: stateStore,
            logger: logger
        )
        bridgeServer = RefreshBridgeServer(logger: logger) { [weak refreshCoordinator] in
            await refreshCoordinator?.requestRefresh(reason: .bridge)
        }
        windowController = SidebarWindowController(
            settings: settings,
            stateStore: stateStore,
            focusService: focusService
        )
    }

    func start() {
        logger.info("app.start")
        windowController.showWindow()
        bridgeServer.start()
        refreshCoordinator.start()
    }

    func stop() {
        logger.info("app.stop")
        bridgeServer.stop()
        refreshCoordinator.stop()
    }
}
