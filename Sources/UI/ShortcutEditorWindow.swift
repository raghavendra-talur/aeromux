import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class ShortcutEditorWindow {
    static let shared = ShortcutEditorWindow()

    private var window: NSWindow?

    private init() {}

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: ShortcutEditorView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "AeroMux Shortcuts"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 340, height: 120))
        window.center()
        window.level = .normal
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct ShortcutEditorView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle Sidebar:", name: .toggleSidebar)
        }
        .padding(20)
        .frame(minWidth: 300)
    }
}
