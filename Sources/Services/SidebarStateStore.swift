import Foundation

@MainActor
final class SidebarStateStore: ObservableObject {
    @Published private(set) var state: WorkspaceState
    @Published private(set) var isRefreshing = false

    private let settings: SettingsStore
    private let logger: AppLogger

    init(settings: SettingsStore, logger: AppLogger) {
        self.settings = settings
        self.logger = logger
        self.state = .placeholder
    }

    func beginRefresh() {
        isRefreshing = true
    }

    func apply(_ snapshot: WorkspaceState) {
        logger.debug("state.apply workspace=\(snapshot.workspaceName) tasks=\(snapshot.workspaces.count) windows=\(snapshot.totalWindowCount)")
        isRefreshing = false
        state = snapshot
    }

    func applyError(_ message: String) {
        logger.error("state.error \(message)")
        isRefreshing = false
        state.status = .error(message)
        state.lastUpdatedAt = .now
    }
}
