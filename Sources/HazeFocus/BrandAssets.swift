import AppKit

enum BrandAssets {
    static let appIcon: NSImage = load("AppIcon")
    static let logoMark: NSImage = load("LogoMark")
    static let menuBar: NSImage = {
        let image = load("MenuBarTemplate")
        image.size = NSSize(width: 18, height: 14)
        image.isTemplate = true
        return image
    }()

    private static func load(_ name: String) -> NSImage {
        // The source-tree fallback also supports `swift run` during development.
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/Brand/\(name).png")
        guard let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing HazeFocus brand asset: \(name)")
        }
        return image
    }
}
