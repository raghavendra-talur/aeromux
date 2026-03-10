import Foundation

struct AeroSpaceSnapshot {
    let workspaceName: String
    let monitorName: String?
    let workspaces: [WorkspaceGroup]
    let focusedWindowId: String?
}

enum AeroSpaceClientError: Error, LocalizedError {
    case binaryMissing
    case noFocusedWorkspace
    case malformedOutput(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            return "AeroSpace CLI not found. Install AeroSpace or set PATH so `aerospace` is available."
        case .noFocusedWorkspace:
            return "No focused AeroSpace workspace is currently available."
        case let .malformedOutput(message), let .commandFailed(message):
            return message
        }
    }
}

actor AeroSpaceClient {
    private let commandRunner: CommandRunning
    private let aerospaceExecutablePath: String?
    private let logger: AppLogger

    init(commandRunner: CommandRunning, aerospaceExecutablePath: String?, logger: AppLogger) {
        self.commandRunner = commandRunner
        self.aerospaceExecutablePath = aerospaceExecutablePath
        self.logger = logger
    }

    func readSnapshot(prioritizeFocusedWorkspace: Bool) async throws -> AeroSpaceSnapshot {
        async let workspaceNameTask = focusedWorkspaceName()
        async let focusedWindowIdTask = focusedWindowId()
        async let monitorNameTask = focusedMonitorName()

        let workspaceName = try await workspaceNameTask
        let focusedWindowId = try await focusedWindowIdTask
        let monitorName = try await monitorNameTask
        let workspaces = try await workspaces(
            focusedWorkspaceName: workspaceName,
            focusedWindowId: focusedWindowId,
            prioritizeFocusedWorkspace: prioritizeFocusedWorkspace
        )

        return AeroSpaceSnapshot(
            workspaceName: workspaceName,
            monitorName: monitorName,
            workspaces: workspaces,
            focusedWindowId: focusedWindowId
        )
    }

    private func focusedWorkspaceName() async throws -> String {
        if let json = try await runAeroSpace(arguments: ["list-workspaces", "--focused", "--json"], allowFailure: true),
           let name = Self.parseFocusedWorkspaceJSON(json) {
            return name
        }

        guard let formatted = try await runAeroSpace(arguments: ["list-workspaces", "--focused", "--format", "%{workspace}"], allowFailure: false) else {
            throw AeroSpaceClientError.noFocusedWorkspace
        }
        let value = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw AeroSpaceClientError.noFocusedWorkspace
        }
        return value
    }

    private func focusedWindowId() async throws -> String? {
        guard let json = try await runAeroSpace(arguments: ["list-windows", "--focused", "--json"], allowFailure: true) else {
            return nil
        }
        return Self.parseFocusedWindowIDJSON(json)
    }

    private func focusedMonitorName() async throws -> String? {
        guard let json = try await runAeroSpace(arguments: ["list-monitors", "--focused", "--json"], allowFailure: true) else {
            return nil
        }
        return Self.parseFocusedMonitorNameJSON(json)
    }

    private func workspaces(
        focusedWorkspaceName: String,
        focusedWindowId: String?,
        prioritizeFocusedWorkspace: Bool
    ) async throws -> [WorkspaceGroup] {
        let format = "%{window-id}\t%{app-name}\t%{window-title}\t%{workspace}\t%{app-bundle-id}"
        guard let output = try await runAeroSpace(arguments: ["list-windows", "--all", "--format", format], allowFailure: false) else {
            throw AeroSpaceClientError.commandFailed("AeroSpace returned no window data.")
        }
        return Self.groupWorkspaces(
            from: try Self.parseWindowsTSV(output, focusedWindowId: focusedWindowId),
            focusedWorkspaceName: focusedWorkspaceName,
            prioritizeFocusedWorkspace: prioritizeFocusedWorkspace
        )
    }

    private func runAeroSpace(arguments: [String], allowFailure: Bool) async throws -> String? {
        guard let aerospaceExecutablePath else {
            throw AeroSpaceClientError.binaryMissing
        }

        let result: CommandResult
        do {
            result = try await commandRunner.run(aerospaceExecutablePath, arguments: arguments)
        } catch {
            throw AeroSpaceClientError.binaryMissing
        }

        guard result.exitCode == 0 else {
            logger.error("aerospace.failure args=\(arguments.joined(separator: " ")) stderr=\(result.stderr)")
            if allowFailure {
                return nil
            }
            throw AeroSpaceClientError.commandFailed(result.stderr.isEmpty ? "AeroSpace command failed." : result.stderr)
        }

        return result.stdout
    }
}

extension AeroSpaceClient {
    static func parseFocusedWorkspaceJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let text = json as? String, !text.isEmpty {
            return text
        }

        if let array = json as? [[String: Any]] {
            for item in array {
                if let value = item["workspace"] as? String, !value.isEmpty {
                    return value
                }
                if let value = item["name"] as? String, !value.isEmpty {
                    return value
                }
            }
        }

        if let dict = json as? [String: Any] {
            return (dict["workspace"] as? String) ?? (dict["name"] as? String)
        }

        return nil
    }

    static func parseFocusedWindowIDJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let array = json as? [[String: Any]] {
            for item in array {
                if let value = stringify(item["window-id"] ?? item["id"]), !value.isEmpty {
                    return value
                }
            }
        }

        if let dict = json as? [String: Any] {
            return stringify(dict["window-id"] ?? dict["id"])
        }

        return nil
    }

    static func parseFocusedMonitorNameJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let array = json as? [[String: Any]] {
            for item in array {
                if let value = stringify(item["monitor-name"] ?? item["name"]), !value.isEmpty {
                    return value
                }
            }
        }

        if let dict = json as? [String: Any] {
            return stringify(dict["monitor-name"] ?? dict["name"])
        }

        return nil
    }

    static func parseWindowsTSV(_ input: String, focusedWindowId: String?) throws -> [WindowItem] {
        let rows = input
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return try rows.map { row in
            let columns = row.components(separatedBy: "\t")
            guard columns.count >= 4 else {
                throw AeroSpaceClientError.malformedOutput("Unexpected AeroSpace window row: \(row)")
            }

            return WindowItem(
                windowId: columns[0],
                appName: columns[1],
                windowTitle: columns[2],
                workspaceName: columns[3],
                isFocused: columns[0] == focusedWindowId,
                bundleIdentifier: columns.count > 4 ? emptyToNil(columns[4]) : nil
            )
        }
    }

    static func groupWorkspaces(
        from windows: [WindowItem],
        focusedWorkspaceName: String,
        prioritizeFocusedWorkspace: Bool
    ) -> [WorkspaceGroup] {
        let grouped = Dictionary(grouping: windows, by: \.workspaceName)

        var workspaces = grouped.map { workspaceName, windows in
            WorkspaceGroup(
                workspaceName: workspaceName,
                windows: sortWindows(windows),
                isFocused: workspaceName == focusedWorkspaceName
            )
        }

        if grouped[focusedWorkspaceName] == nil {
            workspaces.append(
                WorkspaceGroup(
                    workspaceName: focusedWorkspaceName,
                    windows: [],
                    isFocused: true
                )
            )
        }

        return workspaces.sorted { lhs, rhs in
            if prioritizeFocusedWorkspace, lhs.isFocused != rhs.isFocused {
                return lhs.isFocused && !rhs.isFocused
            }
            return lhs.workspaceName.localizedStandardCompare(rhs.workspaceName) == .orderedAscending
        }
    }

    private static func stringify(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private static func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sortWindows(_ windows: [WindowItem]) -> [WindowItem] {
        windows.sorted { lhs, rhs in
            if lhs.isFocused != rhs.isFocused {
                return lhs.isFocused && !rhs.isFocused
            }

            let appOrder = lhs.appName.localizedStandardCompare(rhs.appName)
            if appOrder != .orderedSame {
                return appOrder == .orderedAscending
            }

            return lhs.windowTitle.localizedStandardCompare(rhs.windowTitle) == .orderedAscending
        }
    }
}
