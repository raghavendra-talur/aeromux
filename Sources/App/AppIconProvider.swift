import AppKit

enum AppIconProvider {
    static func applicationIconImage() -> NSImage? {
        loadImage(named: "AeroMuxAppIcon", extension: "png")
    }

    static func statusItemImage() -> NSImage? {
        let image = loadImage(named: "AeroMuxStatusTemplate", extension: "png")
            ?? NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "AeroMux")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }

    private static func loadImage(named name: String, extension ext: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
