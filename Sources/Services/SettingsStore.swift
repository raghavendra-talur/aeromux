import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    enum MonitorMode: String {
        case main
        case focused
    }

    @Published var sidebarWidth: CGFloat
    @Published var monitorMode: MonitorMode
    @Published var pollInterval: TimeInterval
    @Published var showsAppIcons: Bool
    @Published var usesDarkAppearance: Bool
    @Published var enableDebugLogging: Bool
    @Published var reordersFocusedWorkspaceToTop: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sidebarWidth = defaults.object(forKey: Keys.sidebarWidth) as? CGFloat ?? 260
        monitorMode = MonitorMode(rawValue: defaults.string(forKey: Keys.monitorMode) ?? "") ?? .main
        pollInterval = defaults.object(forKey: Keys.pollInterval) as? TimeInterval ?? 1.0
        showsAppIcons = defaults.object(forKey: Keys.showsAppIcons) as? Bool ?? true
        usesDarkAppearance = defaults.object(forKey: Keys.usesDarkAppearance) as? Bool ?? true
        enableDebugLogging = defaults.object(forKey: Keys.enableDebugLogging) as? Bool ?? false
        reordersFocusedWorkspaceToTop = defaults.object(forKey: Keys.reordersFocusedWorkspaceToTop) as? Bool ?? false
    }

    func persist() {
        defaults.set(sidebarWidth, forKey: Keys.sidebarWidth)
        defaults.set(monitorMode.rawValue, forKey: Keys.monitorMode)
        defaults.set(pollInterval, forKey: Keys.pollInterval)
        defaults.set(showsAppIcons, forKey: Keys.showsAppIcons)
        defaults.set(usesDarkAppearance, forKey: Keys.usesDarkAppearance)
        defaults.set(enableDebugLogging, forKey: Keys.enableDebugLogging)
        defaults.set(reordersFocusedWorkspaceToTop, forKey: Keys.reordersFocusedWorkspaceToTop)
    }

    private enum Keys {
        static let sidebarWidth = "sidebarWidth"
        static let monitorMode = "monitorMode"
        static let pollInterval = "pollInterval"
        static let showsAppIcons = "showsAppIcons"
        static let usesDarkAppearance = "usesDarkAppearance"
        static let enableDebugLogging = "enableDebugLogging"
        static let reordersFocusedWorkspaceToTop = "reordersFocusedWorkspaceToTop"
    }
}
