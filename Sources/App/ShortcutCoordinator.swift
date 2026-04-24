import Foundation
import KeyboardShortcuts

@MainActor
final class ShortcutCoordinator {
    private let windowController: SidebarWindowController
    private let logger: AppLogger

    init(windowController: SidebarWindowController, logger: AppLogger) {
        self.windowController = windowController
        self.logger = logger
    }

    func start() {
        KeyboardShortcuts.onKeyUp(for: .toggleSidebar) { [weak self] in
            guard let self else { return }
            self.logger.info("shortcut.toggleSidebar")
            self.windowController.toggle()
        }
    }

    func stop() {
        KeyboardShortcuts.removeAllHandlers()
    }
}
