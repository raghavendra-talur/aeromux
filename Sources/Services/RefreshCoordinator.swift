import Foundation

@MainActor
final class RefreshCoordinator {
    enum TriggerReason: String {
        case startup
        case polling
        case bridge
        case manual
    }

    private let settings: SettingsStore
    private let client: AeroSpaceClient
    private let configService: AeroSpaceConfigService
    private let workspaceMemoryStore: WorkspaceMemoryStore
    private let stateStore: SidebarStateStore
    private let logger: AppLogger
    private var scheduledRefresh: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    init(
        settings: SettingsStore,
        client: AeroSpaceClient,
        configService: AeroSpaceConfigService,
        workspaceMemoryStore: WorkspaceMemoryStore,
        stateStore: SidebarStateStore,
        logger: AppLogger
    ) {
        self.settings = settings
        self.client = client
        self.configService = configService
        self.workspaceMemoryStore = workspaceMemoryStore
        self.stateStore = stateStore
        self.logger = logger
    }

    func start() {
        requestRefresh(reason: .startup)
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let interval = max(settings.pollInterval, 0.25)
                try? await Task.sleep(for: .seconds(interval))
                requestRefresh(reason: .polling)
            }
        }
    }

    func stop() {
        scheduledRefresh?.cancel()
        pollingTask?.cancel()
    }

    func requestRefresh(reason: TriggerReason) {
        logger.debug("refresh.request \(reason.rawValue)")
        scheduledRefresh?.cancel()
        scheduledRefresh = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(75))
            await self?.performRefresh(reason: reason)
        }
    }

    private func performRefresh(reason: TriggerReason) async {
        logger.info("refresh.begin \(reason.rawValue)")
        stateStore.beginRefresh()

        do {
            async let snapshotTask = client.readSnapshot(
                prioritizeFocusedWorkspace: settings.reordersFocusedWorkspaceToTop
            )
            async let integrationTask = configService.integrationStatus(sidebarWidth: settings.sidebarWidth)
            let snapshot = try await snapshotTask
            let integrationStatus = await integrationTask
            async let workspaceMemoryTask = workspaceMemoryStore.metadataByWorkspace(
                for: snapshot.workspaces.map(\.workspaceName)
            )
            let workspaceMemory = await workspaceMemoryTask
            let annotatedWorkspaces = snapshot.workspaces.map { workspace in
                let metadata = workspaceMemory[workspace.workspaceName]
                return WorkspaceGroup(
                    workspaceName: workspace.workspaceName,
                    windows: workspace.windows,
                    isFocused: workspace.isFocused,
                    titleOverride: metadata?.title,
                    descriptionOverride: metadata?.description
                )
            }
            let totalWindowCount = annotatedWorkspaces.reduce(0) { $0 + $1.windows.count }
            let status: SidebarStatus = totalWindowCount == 0 ? .empty : .ready
            let workspaceState = WorkspaceState(
                workspaceName: snapshot.workspaceName,
                monitorName: snapshot.monitorName,
                workspaces: annotatedWorkspaces,
                focusedWindowId: snapshot.focusedWindowId,
                integrationStatus: integrationStatus,
                lastUpdatedAt: .now,
                status: status
            )
            stateStore.apply(workspaceState)
            logger.info("refresh.complete workspace=\(snapshot.workspaceName)")
        } catch {
            stateStore.applyError(error.localizedDescription)
        }
    }
}
