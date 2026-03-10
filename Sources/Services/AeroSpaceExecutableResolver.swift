import Foundation

enum AeroSpaceExecutableResolver {
    static func resolve() -> String? {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let fallbackDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/local/bin",
            "/usr/bin",
            "/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/bin",
        ]

        var seen = Set<String>()
        let candidates = (pathEntries + fallbackDirectories).compactMap { directory -> String? in
            guard !directory.isEmpty else { return nil }
            let candidate = URL(fileURLWithPath: directory)
                .appendingPathComponent("aerospace")
                .path
            guard seen.insert(candidate).inserted else { return nil }
            return candidate
        }

        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0) })
    }
}
