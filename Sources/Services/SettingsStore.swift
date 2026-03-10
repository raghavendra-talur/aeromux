import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    enum MonitorMode: String {
        case main
        case focused
    }

    static let defaultSidebarWidth: CGFloat = 260
    static let sidebarWidthRange: ClosedRange<CGFloat> = 100 ... 600

    @Published var sidebarWidth: CGFloat
    @Published var monitorMode: MonitorMode
    @Published var pollInterval: TimeInterval
    @Published var usesDarkAppearance: Bool
    @Published var enableDebugLogging: Bool
    @Published var reordersFocusedWorkspaceToTop: Bool
    @Published var launchesAtLogin: Bool
    @Published var compactMode: Bool

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let logger: AppLogger
    private let configFileURL: URL?

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default, logger: AppLogger) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.logger = logger

        var resolvedConfigFileURL: URL?
        let persistedConfig: PersistedConfig?
        let shouldBootstrapConfig: Bool

        do {
            let fileURL = AeroMuxConfigPaths.settingsFileURL(fileManager: fileManager)
            resolvedConfigFileURL = fileURL
            if fileManager.fileExists(atPath: fileURL.path) {
                persistedConfig = try Self.loadConfig(from: fileURL)
                shouldBootstrapConfig = false
            } else {
                persistedConfig = nil
                shouldBootstrapConfig = true
            }
        } catch {
            logger.error("settings.config.read.error \(error.localizedDescription)")
            resolvedConfigFileURL = nil
            persistedConfig = nil
            shouldBootstrapConfig = false
        }
        configFileURL = resolvedConfigFileURL

        sidebarWidth = Self.normalizedSidebarWidth(
            persistedConfig?.sidebarWidth.map { CGFloat($0) }
                ?? Self.legacySidebarWidth(from: defaults)
                ?? Self.defaultSidebarWidth
        )
        monitorMode = MonitorMode(rawValue: defaults.string(forKey: Keys.monitorMode) ?? "") ?? .main
        pollInterval = defaults.object(forKey: Keys.pollInterval) as? TimeInterval ?? 1.0
        usesDarkAppearance = defaults.object(forKey: Keys.usesDarkAppearance) as? Bool ?? true
        enableDebugLogging = defaults.object(forKey: Keys.enableDebugLogging) as? Bool ?? false
        reordersFocusedWorkspaceToTop = persistedConfig?.pinActiveWorkspaceFirst
            ?? defaults.object(forKey: Keys.reordersFocusedWorkspaceToTop) as? Bool
            ?? false
        launchesAtLogin = persistedConfig?.launchAtLogin ?? false
        compactMode = persistedConfig?.compactMode ?? false

        if shouldBootstrapConfig {
            persistConfig()
            removeLegacyConfigDefaults()
        }
    }

    func persist() {
        sidebarWidth = Self.normalizedSidebarWidth(sidebarWidth)
        persistConfig()
        removeLegacyConfigDefaults()
        defaults.set(monitorMode.rawValue, forKey: Keys.monitorMode)
        defaults.set(pollInterval, forKey: Keys.pollInterval)
        defaults.set(usesDarkAppearance, forKey: Keys.usesDarkAppearance)
        defaults.set(enableDebugLogging, forKey: Keys.enableDebugLogging)
        defaults.removeObject(forKey: Keys.showsAppIcons)
    }

    func setSidebarWidth(_ width: CGFloat) {
        sidebarWidth = Self.normalizedSidebarWidth(width)
        persist()
    }

    private func persistConfig() {
        guard let configFileURL else { return }

        do {
            _ = try AeroMuxConfigPaths.ensureConfigDirectoryExists(fileManager: fileManager)

            let payload = PersistedConfig(
                sidebarWidth: Double(sidebarWidth),
                pinActiveWorkspaceFirst: reordersFocusedWorkspaceToTop,
                launchAtLogin: launchesAtLogin,
                compactMode: compactMode
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            try data.write(to: configFileURL, options: .atomic)
        } catch {
            logger.error("settings.config.write.error \(error.localizedDescription)")
        }
    }

    private func removeLegacyConfigDefaults() {
        defaults.removeObject(forKey: Keys.sidebarWidth)
        defaults.removeObject(forKey: Keys.reordersFocusedWorkspaceToTop)
    }

    private static func normalizedSidebarWidth(_ width: CGFloat) -> CGFloat {
        min(max(width.rounded(), sidebarWidthRange.lowerBound), sidebarWidthRange.upperBound)
    }

    private static func legacySidebarWidth(from defaults: UserDefaults) -> CGFloat? {
        guard let number = defaults.object(forKey: Keys.sidebarWidth) as? NSNumber else {
            return nil
        }

        return CGFloat(truncating: number)
    }

    private static func loadConfig(from fileURL: URL) throws -> PersistedConfig {
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return PersistedConfig()
        }

        return try JSONDecoder().decode(PersistedConfig.self, from: data)
    }

    private struct PersistedConfig: Codable {
        var sidebarWidth: Double?
        var pinActiveWorkspaceFirst: Bool?
        var launchAtLogin: Bool?
        var compactMode: Bool?
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
