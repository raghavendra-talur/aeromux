import AppKit

enum AppIconProvider {
    static func applicationIconImage() -> NSImage? {
        loadImage(resourceName: "AeroMux.icns")
            ?? loadDevelopmentImage(at: "../../../Packaging/AeroMux.icns")
    }

    static func statusItemImage() -> NSImage? {
        let image = loadImage(resourceName: "AeroMuxStatusTemplate.png")
            ?? loadDevelopmentImage(at: "../../../Sources/Resources/AeroMuxStatusTemplate.png")
            ?? NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "AeroMux")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }

    private static func loadImage(resourceName: String) -> NSImage? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let url = resourceURL.appendingPathComponent(resourceName)
        return NSImage(contentsOf: url)
    }

    private static func loadDevelopmentImage(at relativePath: String) -> NSImage? {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let url = sourceFileURL
            .deletingLastPathComponent()
            .appending(path: relativePath)
            .standardizedFileURL
        return NSImage(contentsOf: url)
    }
}
