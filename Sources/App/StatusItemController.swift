import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let settings: SettingsStore
    private let refreshCoordinator: RefreshCoordinator
    private let windowController: SidebarWindowController

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let toggleSidebarItem = NSMenuItem()
    private let reorderWorkspacesItem = NSMenuItem()
    private let refreshItem = NSMenuItem()
    private let quitItem = NSMenuItem()

    init(settings: SettingsStore, refreshCoordinator: RefreshCoordinator, windowController: SidebarWindowController) {
        self.settings = settings
        self.refreshCoordinator = refreshCoordinator
        self.windowController = windowController
        super.init()
        configureStatusItem()
        configureMenu()
    }

    func start() {
        updateMenuState()
    }

    func stop() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuState()
    }

    private func configureStatusItem() {
        statusItem.button?.image = AppIconProvider.statusItemImage()
        statusItem.button?.toolTip = "AeroMux"
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self

        toggleSidebarItem.target = self
        toggleSidebarItem.action = #selector(toggleSidebar)

        reorderWorkspacesItem.title = "Pin Active Workspace First"
        reorderWorkspacesItem.target = self
        reorderWorkspacesItem.action = #selector(toggleWorkspaceReordering)

        refreshItem.title = "Refresh Now"
        refreshItem.target = self
        refreshItem.action = #selector(refreshNow)

        quitItem.title = "Quit AeroMux"
        quitItem.target = self
        quitItem.action = #selector(quitApp)

        menu.items = [
            toggleSidebarItem,
            reorderWorkspacesItem,
            .separator(),
            refreshItem,
            .separator(),
            quitItem,
        ]
    }

    private func updateMenuState() {
        toggleSidebarItem.title = windowController.isVisible ? "Hide Sidebar" : "Show Sidebar"
        reorderWorkspacesItem.state = settings.reordersFocusedWorkspaceToTop ? .on : .off
    }

    @objc
    private func toggleSidebar() {
        if windowController.isVisible {
            windowController.hideWindow()
        } else {
            windowController.showWindow()
        }
        updateMenuState()
    }

    @objc
    private func toggleWorkspaceReordering() {
        settings.reordersFocusedWorkspaceToTop.toggle()
        settings.persist()
        refreshCoordinator.requestRefresh(reason: .manual)
        updateMenuState()
    }

    @objc
    private func refreshNow() {
        refreshCoordinator.requestRefresh(reason: .manual)
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
