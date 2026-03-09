import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let environment = AppEnvironment()
        environment.start()
        self.environment = environment
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.stop()
    }
}
