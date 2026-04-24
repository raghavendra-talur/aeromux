import AppKit
import Foundation
import KeyboardShortcuts

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let settings: SettingsStore
    private let launchAtLoginService: LaunchAtLoginService
    private let refreshCoordinator: RefreshCoordinator
    private let windowController: SidebarWindowController

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let toggleSidebarItem = NSMenuItem()
    private let sidebarWidthItem = NSMenuItem()
    private let reorderWorkspacesItem = NSMenuItem()
    private let compactModeItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private let shortcutEditorItem = NSMenuItem()
    private let refreshItem = NSMenuItem()
    private let quitItem = NSMenuItem()

    init(
        settings: SettingsStore,
        launchAtLoginService: LaunchAtLoginService,
        refreshCoordinator: RefreshCoordinator,
        windowController: SidebarWindowController
    ) {
        self.settings = settings
        self.launchAtLoginService = launchAtLoginService
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

        sidebarWidthItem.target = self
        sidebarWidthItem.action = #selector(editSidebarWidth)

        reorderWorkspacesItem.title = "Pin Active Workspace First"
        reorderWorkspacesItem.target = self
        reorderWorkspacesItem.action = #selector(toggleWorkspaceReordering)

        compactModeItem.title = "Compact Mode"
        compactModeItem.target = self
        compactModeItem.action = #selector(toggleCompactMode)

        launchAtLoginItem.title = "Launch at Login"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)

        shortcutEditorItem.title = "Keyboard Shortcuts…"
        shortcutEditorItem.target = self
        shortcutEditorItem.action = #selector(openShortcutEditor)

        refreshItem.title = "Refresh Now"
        refreshItem.target = self
        refreshItem.action = #selector(refreshNow)

        quitItem.title = "Quit AeroMux"
        quitItem.target = self
        quitItem.action = #selector(quitApp)

        menu.items = [
            toggleSidebarItem,
            sidebarWidthItem,
            reorderWorkspacesItem,
            compactModeItem,
            launchAtLoginItem,
            shortcutEditorItem,
            .separator(),
            refreshItem,
            .separator(),
            quitItem,
        ]
    }

    private func updateMenuState() {
        let baseTitle = windowController.isVisible ? "Hide Sidebar" : "Show Sidebar"
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleSidebar) {
            toggleSidebarItem.title = "\(baseTitle)  \(shortcut)"
        } else {
            toggleSidebarItem.title = baseTitle
        }
        sidebarWidthItem.title = "Sidebar Width: \(Int(settings.sidebarWidth)) px"
        reorderWorkspacesItem.state = settings.reordersFocusedWorkspaceToTop ? .on : .off
        compactModeItem.state = settings.compactMode ? .on : .off
        launchAtLoginItem.state = settings.launchesAtLogin ? .on : .off
    }

    @objc
    private func toggleSidebar() {
        windowController.toggle()
        updateMenuState()
    }

    @objc
    private func openShortcutEditor() {
        ShortcutEditorWindow.shared.show()
    }

    @objc
    private func toggleWorkspaceReordering() {
        settings.reordersFocusedWorkspaceToTop.toggle()
        settings.persist()
        refreshCoordinator.requestRefresh(reason: .manual)
        updateMenuState()
    }

    @objc
    private func toggleCompactMode() {
        settings.compactMode.toggle()
        settings.persist()
        updateMenuState()
    }

    @objc
    private func toggleLaunchAtLogin() {
        let desiredState = !settings.launchesAtLogin

        do {
            let resolvedStatus = try launchAtLoginService.apply(enabled: desiredState)
            settings.launchesAtLogin = desiredState
            settings.persist()
            updateMenuState()

            if desiredState, resolvedStatus == .requiresApproval {
                presentLaunchAtLoginApprovalAlert()
            }
        } catch {
            presentLaunchAtLoginErrorAlert(error)
        }
    }

    @objc
    private func editSidebarWidth() {
        DispatchQueue.main.async { [weak self] in
            self?.presentSidebarWidthEditor()
        }
    }

    private func presentSidebarWidthEditor() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Sidebar Width"
        alert.informativeText = "Enter the sidebar width in pixels. Keep AeroSpace `outer.left` at least this wide."

        let inputField = NSTextField(string: "\(Int(settings.sidebarWidth))")
        inputField.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = inputField
        alert.window.level = .modalPanel
        alert.window.center()

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let rawValue = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let width = Double(rawValue) else {
            presentInvalidSidebarWidthAlert()
            return
        }

        let minWidth = Double(SettingsStore.sidebarWidthRange.lowerBound)
        let maxWidth = Double(SettingsStore.sidebarWidthRange.upperBound)
        guard width.rounded() == width, width >= minWidth, width <= maxWidth else {
            presentInvalidSidebarWidthAlert()
            return
        }

        applySidebarWidthChange(CGFloat(width))
    }

    private func presentInvalidSidebarWidthAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        let minWidth = Int(SettingsStore.sidebarWidthRange.lowerBound)
        let maxWidth = Int(SettingsStore.sidebarWidthRange.upperBound)
        alert.messageText = "Invalid Sidebar Width"
        alert.informativeText = "Enter a whole number between \(minWidth) and \(maxWidth) pixels."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentLaunchAtLoginApprovalAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Launch at Login Requires Approval"
        alert.informativeText = "macOS requires approval before AeroMux can launch at login. Review Login Items in System Settings if AeroMux does not start automatically."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentLaunchAtLoginErrorAlert(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Unable to Update Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func applySidebarWidthChange(_ width: CGFloat) {
        settings.setSidebarWidth(width)
        windowController.showWindow()
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
