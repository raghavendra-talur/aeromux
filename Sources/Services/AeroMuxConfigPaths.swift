import Foundation

enum AeroMuxConfigPaths {
    static func configDirectoryURL(fileManager: FileManager = .default) -> URL {
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty {
            return URL(fileURLWithPath: xdgConfigHome).appendingPathComponent("aeromux", isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("aeromux", isDirectory: true)
    }

    static func ensureConfigDirectoryExists(fileManager: FileManager = .default) throws -> URL {
        let directoryURL = configDirectoryURL(fileManager: fileManager)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }

    static func settingsFileURL(fileManager: FileManager = .default) -> URL {
        configDirectoryURL(fileManager: fileManager).appendingPathComponent("settings.json")
    }

    static func workspaceMemoryFileURL(fileManager: FileManager = .default) -> URL {
        configDirectoryURL(fileManager: fileManager).appendingPathComponent("workspaces.json")
    }
}
