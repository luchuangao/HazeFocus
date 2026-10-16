import AppKit

if CommandLine.arguments.contains("--render-check") {
    _ = NSApplication.shared
    exit(runRenderChecks() ? 0 : 1)
}

if CommandLine.arguments.contains("--diagnostics") {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    let windows = DimmerEngine.visibleWindows(primaryHeight: primaryHeight)
    print("HazeFocus diagnostics")
    print("Accessibility: \(AXIsProcessTrusted())")
    print("Displays: \(NSScreen.screens.count)")
    print("Visible windows: \(windows.count)")
    print("Frontmost app: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown")")
    exit(0)
}

let application = HazeFocusApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
