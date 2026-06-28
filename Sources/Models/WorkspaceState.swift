import AppKit
import Foundation
import SwiftUI

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

    static let floatingWindowMode = AeroSpaceIntegrationStatus(
        reservedLeftGap: nil,
        presentation: .floatingOverlay,
        message: nil
    )
}

struct WorkspaceGroup: Identifiable, Equatable {
    var id: String { workspaceName }
    let workspaceName: String
    let windows: [WindowItem]
    let isFocused: Bool
    let titleOverride: String?
    let descriptionOverride: String?
    let colorOverride: String?
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

    var focusedWorkspaceGroup: WorkspaceGroup? {
        workspaces.first(where: \.isFocused)
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

extension WorkspaceGroup {
    var displayTitle: String {
        titleOverride ?? "Task \(workspaceName)"
    }

    var metadataLine: String? {
        if let titleOverride, titleOverride != workspaceName {
            return "Workspace \(workspaceName)"
        }
        return nil
    }

    var detailLine: String? {
        descriptionOverride
    }

    /// The workspace's accent color: an explicit per-workspace override if set,
    /// otherwise a sensible default from the built-in palette.
    var resolvedColor: Color {
        if let colorOverride, let parsed = Color(aeroMuxHex: colorOverride) {
            return parsed
        }
        return WorkspaceGroup.defaultColor(for: workspaceName)
    }

    /// Default per-workspace palette, keyed by workspace number. Falls back to
    /// the system accent color for non-numeric / unlisted workspaces.
    static func defaultColor(for workspaceName: String) -> Color {
        switch workspaceName {
        case "1": return Color(aeroMuxHex: "#89b4fa") ?? .blue
        case "2": return Color(aeroMuxHex: "#a6e3a1") ?? .green
        case "3": return Color(aeroMuxHex: "#fab387") ?? .orange
        case "4": return Color(aeroMuxHex: "#cba6f7") ?? .purple
        case "5": return Color(aeroMuxHex: "#f9e2af") ?? .yellow
        case "6": return Color(aeroMuxHex: "#94e2d5") ?? .teal
        case "7": return Color(aeroMuxHex: "#f38ba8") ?? .red
        case "8": return Color(aeroMuxHex: "#b4befe") ?? .indigo
        case "9": return Color(aeroMuxHex: "#89dceb") ?? .cyan
        default: return .accentColor
        }
    }
}

extension Color {
    /// Creates a color from a "#RRGGBB" or "RRGGBB" hex string.
    init?(aeroMuxHex hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt64(string, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self = Color(red: red, green: green, blue: blue)
    }

    /// Serializes the color to a "#RRGGBB" hex string in sRGB.
    var aeroMuxHex: String? {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let red = Int((srgb.redComponent * 255).rounded())
        let green = Int((srgb.greenComponent * 255).rounded())
        let blue = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", red, green, blue)
    }
}
