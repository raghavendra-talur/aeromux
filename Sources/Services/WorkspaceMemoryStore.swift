import Foundation

struct WorkspaceMemoryEntry: Codable, Equatable {
    let workspace: String
    let title: String?
    let description: String?
}

struct WorkspaceMemoryFile: Codable {
    let workspaces: [WorkspaceMemoryEntry]
}

actor WorkspaceMemoryStore {
    private let fileManager: FileManager
    private let logger: AppLogger

    init(fileManager: FileManager = .default, logger: AppLogger) {
        self.fileManager = fileManager
        self.logger = logger
    }

    func metadataByWorkspace(for discoveredWorkspaces: [String]) async -> [String: WorkspaceMemoryEntry] {
        do {
            let fileURL = try configFileURL()
            let existingEntries = try loadEntries(from: fileURL)
            let syncedEntries = merge(existingEntries: existingEntries, discoveredWorkspaces: discoveredWorkspaces)
            if syncedEntries != existingEntries || !fileManager.fileExists(atPath: fileURL.path) {
                try write(entries: syncedEntries, to: fileURL)
            }
            return Dictionary(uniqueKeysWithValues: syncedEntries.map { ($0.workspace, $0) })
        } catch {
            logger.error("workspace.memory.error \(error.localizedDescription)")
            return [:]
        }
    }

    func save(workspace: String, title: String, description: String, discoveredWorkspaces: [String]) async {
        do {
            let fileURL = try configFileURL()
            var entries = try loadEntries(from: fileURL)
            entries = merge(existingEntries: entries, discoveredWorkspaces: discoveredWorkspaces)

            let updatedEntry = WorkspaceMemoryEntry(
                workspace: workspace,
                title: normalize(title) ?? workspace,
                description: normalize(description)
            )

            if let index = entries.firstIndex(where: { $0.workspace == workspace }) {
                entries[index] = updatedEntry
            } else {
                entries.append(updatedEntry)
            }

            try write(entries: entries, to: fileURL)
        } catch {
            logger.error("workspace.memory.save.error \(error.localizedDescription)")
        }
    }

    private func configFileURL() throws -> URL {
        _ = try AeroMuxConfigPaths.ensureConfigDirectoryExists(fileManager: fileManager)
        return AeroMuxConfigPaths.workspaceMemoryFileURL(fileManager: fileManager)
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func loadEntries(from fileURL: URL) throws -> [WorkspaceMemoryEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return []
        }

        let decoded = try JSONDecoder().decode(WorkspaceMemoryFile.self, from: data)
        return decoded.workspaces.map { entry in
            WorkspaceMemoryEntry(
                workspace: entry.workspace,
                title: normalize(entry.title) ?? entry.workspace,
                description: normalize(entry.description)
            )
        }
    }

    private func merge(existingEntries: [WorkspaceMemoryEntry], discoveredWorkspaces: [String]) -> [WorkspaceMemoryEntry] {
        let existingByWorkspace = Dictionary(uniqueKeysWithValues: existingEntries.map { ($0.workspace, $0) })
        let discoveredSet = Set(discoveredWorkspaces)

        var merged: [WorkspaceMemoryEntry] = discoveredWorkspaces.map { workspace in
            if let existing = existingByWorkspace[workspace] {
                return WorkspaceMemoryEntry(
                    workspace: existing.workspace,
                    title: normalize(existing.title) ?? workspace,
                    description: normalize(existing.description)
                )
            }

            return WorkspaceMemoryEntry(
                workspace: workspace,
                title: workspace,
                description: nil
            )
        }

        let extras = existingEntries
            .filter { !discoveredSet.contains($0.workspace) }
            .sorted { $0.workspace.localizedStandardCompare($1.workspace) == .orderedAscending }
        merged.append(contentsOf: extras)

        return merged
    }

    private func write(entries: [WorkspaceMemoryEntry], to fileURL: URL) throws {
        let file = WorkspaceMemoryFile(workspaces: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: .atomic)
    }
}
