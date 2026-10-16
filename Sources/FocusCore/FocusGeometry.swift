import Foundation
import CoreGraphics

public struct FocusWindow: Equatable {
    public let id: Int
    public let pid: Int32
    public let frame: CGRect
    public let layer: Int
    public init(id: Int, pid: Int32, frame: CGRect, layer: Int = 0) {
        self.id = id; self.pid = pid; self.frame = frame; self.layer = layer
    }
}

public enum DisplayMode: String, Codable, CaseIterable {
    case activeDisplay, eachDisplay
}

public enum FocusGeometry {
    /// Core Graphics uses a top-left origin; AppKit uses a bottom-left origin.
    /// Both coordinate systems are anchored to the primary display, never the
    /// combined desktop bounds (which can extend above or left of that display).
    public static func appKitRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func localRect(_ rect: CGRect, screen: CGRect) -> CGRect {
        rect.offsetBy(dx: -screen.minX, dy: -screen.minY)
    }

    public static func focused(windows: [FocusWindow], pid: Int32, axFrame: CGRect?) -> FocusWindow? {
        let owned = windows.filter { $0.pid == pid && $0.layer == 0 }
        guard let frame = axFrame else { return owned.first }
        // An AX frame can be a sheet or a not-yet-published new window. Do not
        // accidentally select a different application's window in either case.
        return owned.min { distance($0.frame, frame) < distance($1.frame, frame) }
            .flatMap { distance($0.frame, frame) < 24 ? $0 : nil }
    }

    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX-b.minX) + abs(a.minY-b.minY) + abs(a.width-b.width) + abs(a.height-b.height)
    }

    /// Input windows are front-to-back, all in AppKit coordinates.
    public static func holes(windows: [FocusWindow], focused: FocusWindow?, pid: Int32,
                             screen: CGRect, mode: DisplayMode, allAppWindows: Bool) -> [CGRect] {
        let visible = windows.filter { $0.frame.intersects(screen) && $0.layer == 0 }
        if allAppWindows {
            return visible.filter { $0.pid == pid }.map(\.frame)
        }
        if mode == .eachDisplay {
            if let focused, screen.contains(CGPoint(x: focused.frame.midX, y: focused.frame.midY)) {
                return [focused.frame]
            }
            // A window spanning displays keeps its entire visible area clear.
            if let focused, focused.frame.intersects(screen) { return [focused.frame] }
            return visible.first.map { [$0.frame] } ?? []
        }
        return focused.map { $0.frame.intersects(screen) ? [$0.frame] : [] } ?? []
    }
}

public struct AppearanceProfile: Codable, Equatable {
    public var enabled: Bool
    public var intensity: Double
    public var colorHex: String
    public init(enabled: Bool = true, intensity: Double = 0.65, colorHex: String = "11121A") {
        self.enabled = enabled
        self.intensity = min(1, max(0, intensity.isFinite ? intensity : 0.65))
        self.colorHex = colorHex
    }
}

public enum ControlCommand: Equatable {
    case enable(Bool), toggle, intensity(Double), settings

    public static func parse(_ url: URL) -> ControlCommand? {
        guard url.scheme?.lowercased() == "hazefocus", let host = url.host?.lowercased() else { return nil }
        switch host {
        case "on": return .enable(true)
        case "off": return .enable(false)
        case "toggle": return .toggle
        case "settings": return .settings
        case "intensity":
            guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "value" })?.value,
                  let value = Double(raw), value.isFinite, (0...100).contains(value) else { return nil }
            return .intensity(value / 100)
        default: return nil
        }
    }
}
