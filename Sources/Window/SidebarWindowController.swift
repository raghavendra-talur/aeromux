import AppKit
import Combine
import SwiftUI

@MainActor
final class SidebarWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStore
    private let stateStore: SidebarStateStore
    private let focusService: FocusService
    private var stateObserver: AnyCancellable?

    init(settings: SettingsStore, stateStore: SidebarStateStore, focusService: FocusService) {
        self.settings = settings
        self.stateStore = stateStore
        self.focusService = focusService

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.delegate = nil
        panel.contentView = NSHostingView(
            rootView: SidebarRootView(
                stateStore: stateStore,
                settings: settings,
                focusService: focusService
            )
        )

        super.init(window: panel)
        panel.delegate = self
        stateObserver = stateStore.$state.sink { [weak self] state in
            self?.applyPresentation(state.integrationStatus.presentation)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        guard let window else { return }
        applyPresentation(stateStore.state.integrationStatus.presentation)
        updateFrame()
        window.orderFrontRegardless()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        updateFrame()
    }

    @objc
    private func handleScreenChange() {
        updateFrame()
    }

    private func updateFrame() {
        guard let window else { return }
        guard let screen = targetScreen() else { return }
        let frame = screen.visibleFrame
        let width = settings.sidebarWidth
        window.setFrame(
            NSRect(x: frame.minX, y: frame.minY, width: width, height: frame.height),
            display: true
        )
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    private func applyPresentation(_ presentation: AeroSpaceIntegrationStatus.WindowPresentation) {
        guard let panel = window as? NSPanel else { return }

        switch presentation {
        case .reservedColumn:
            panel.isFloatingPanel = false
            panel.level = .normal
        case .floatingOverlay:
            panel.isFloatingPanel = true
            panel.level = .floating
        }
    }
}
