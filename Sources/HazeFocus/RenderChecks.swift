import AppKit
import FocusCore

/// Exercises the real AppKit renderer without inspecting the user's screen.
func runRenderChecks() -> Bool {
    let view = ShadeView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    view.color = .black; view.intensity = 0.65
    let left = FocusWindow(id: 1, pid: 1, frame: CGRect(x: 30, y: 30, width: 200, height: 200))
    let right = FocusWindow(id: 2, pid: 1, frame: CGRect(x: 130, y: 60, width: 200, height: 200))
    let occluder = FocusWindow(id: 3, pid: 2, frame: CGRect(x: 170, y: 120, width: 70, height: 70))
    view.holes = [left.frame, right.frame]
    view.windows = [occluder, right, left]
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 300,
                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { return false }
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
    // Bitmap storage has the opposite vertical orientation to the drawing CTM.
    func alpha(_ x: Int, _ y: Int) -> CGFloat { rep.colorAt(x: x, y: 299-y)?.alphaComponent ?? -1 }
    let samples: [(String, CGFloat, CGFloat)] = [
        ("background dimmed", alpha(380, 280), 0.65),
        ("first highlighted window transparent", alpha(70, 100), 0),
        ("second highlighted window transparent", alpha(290, 200), 0),
        ("overlapping highlights stay transparent", alpha(150, 100), 0),
        ("unfocused foreground window stays dim", alpha(200, 150), 0.65)
    ]
    var passed = true
    for (name, actual, expected) in samples {
        let good = abs(actual-expected) < 0.02
        print("\(good ? "PASS" : "FAIL") \(name): alpha=\(actual)")
        passed = passed && good
    }
    let panel = ShadePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.ignoresMouseEvents = true
    let passive = !panel.canBecomeKey && !panel.canBecomeMain && panel.ignoresMouseEvents
    print("\(passive ? "PASS" : "FAIL") overlay cannot steal focus or intercept clicks")
    panel.close()
    return passed && passive
}
