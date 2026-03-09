import AppKit
import Foundation

struct WorkspaceState: Equatable {
    var workspaceName: String
    var monitorName: String?
    var workspaces: [WorkspaceGroup]
    var focusedWindowId: String?
    var integrationStatus: AeroSpaceIntegrationStatus
    var lastUpdatedAt: Date
    var status: SidebarStatus

    static let placeholder = WorkspaceState(
        workspaceName: "Loading",
        monitorName: nil,
        workspaces: [],
        focusedWindowId: nil,
        integrationStatus: .unknown,
        lastUpdatedAt: .now,
        status: .loading
    )
}

struct AeroSpaceIntegrationStatus: Equatable {
    enum WindowPresentation: Equatable {
        case reservedColumn
        case floatingOverlay
    }

    let reservedLeftGap: CGFloat?
    let presentation: WindowPresentation
    let message: String?

    static let unknown = AeroSpaceIntegrationStatus(
        reservedLeftGap: nil,
        presentation: .floatingOverlay,
        message: "Unable to confirm AeroSpace left-gap reservation. The sidebar will float until the config can be verified."
    )
}

struct WorkspaceGroup: Identifiable, Equatable {
    var id: String { workspaceName }
    let workspaceName: String
    let windows: [WindowItem]
    let isFocused: Bool
}

struct WindowItem: Identifiable, Equatable {
    var id: String { windowId }
    let windowId: String
    let appName: String
    let windowTitle: String
    let workspaceName: String
    let isFocused: Bool
    let bundleIdentifier: String?
}

enum SidebarStatus: Equatable {
    case loading
    case ready
    case empty
    case error(String)
}

extension WorkspaceState {
    var totalWindowCount: Int {
        workspaces.reduce(0) { $0 + $1.windows.count }
    }

    var visibleWorkspaceCount: Int {
        workspaces.count
    }
}

extension WindowItem {
    var resolvedIcon: NSImage? {
        if let bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let icon = app.icon {
            return icon
        }

        return NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName })?.icon
    }
}
