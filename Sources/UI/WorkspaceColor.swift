import AppKit
import SwiftUI

extension WorkspaceGroup {
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
        guard string.count == 6,
              string.allSatisfy(\.isHexDigit),
              let value = UInt64(string, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self = Color(red: red, green: green, blue: blue)
    }

    /// Serializes the color to a "#RRGGBB" hex string in sRGB.
    var aeroMuxHex: String? {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "#%02x%02x%02x",
            Self.hexByte(srgb.redComponent),
            Self.hexByte(srgb.greenComponent),
            Self.hexByte(srgb.blueComponent)
        )
    }

    /// Converts a color component to 0...255, clamping values outside the
    /// sRGB gamut so the result always fits in two hex digits.
    private static func hexByte(_ component: CGFloat) -> Int {
        Int((min(max(component, 0), 1) * 255).rounded())
    }
}
