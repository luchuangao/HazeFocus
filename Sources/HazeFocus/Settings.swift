import AppKit
import Combine
import FocusCore
import ServiceManagement

struct Preferences: Codable {
    var light = AppearanceProfile()
    var dark = AppearanceProfile(intensity: 0.76, colorHex: "08090E")
    var separateAppearance = false
    var allAppWindows = false
    var displayMode = DisplayMode.activeDisplay
    var disabledDisplays: Set<String> = []
    var excludedApps: [String: String] = [:]
    var animationDuration = 0.2
    var holdFnToReveal = true
    var shortcutKey: UInt32 = 4 // H
    var shortcutModifiers: UInt32 = 0x1000 | 0x0800 | 0x0100 // control + option + command
    var shortcutLabel = "⌃⌥⌘H"
}

final class Settings: ObservableObject {
    static let shared = Settings()
    @Published var values: Preferences { didSet { save() } }
    @Published var isDark = false
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var activeAppName = L("桌面")
    @Published var activeBundleID: String?
    @Published var temporarilyRevealed = false
    @Published var loginError: String?
    var changed: (() -> Void)?
    private let storage: UserDefaults
    private let persistenceKey = "HazeFocus.preferences.v1"

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        if let data = storage.data(forKey: persistenceKey),
           var decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            decoded.light.intensity = min(1, max(0, decoded.light.intensity.isFinite ? decoded.light.intensity : 0.65))
            decoded.dark.intensity = min(1, max(0, decoded.dark.intensity.isFinite ? decoded.dark.intensity : 0.76))
            decoded.animationDuration = min(1, max(0, decoded.animationDuration.isFinite ? decoded.animationDuration : 0.2))
            values = decoded
        } else { values = Preferences() }
        updateAppearance()
    }

    var profile: AppearanceProfile {
        get { values.separateAppearance && isDark ? values.dark : values.light }
        set {
            var copy = values
            if copy.separateAppearance && isDark { copy.dark = newValue } else { copy.light = newValue }
            values = copy
        }
    }
    var enabled: Bool { get { profile.enabled } set { var p = profile; p.enabled = newValue; profile = p } }
    var intensity: Double { get { profile.intensity } set { var p = profile; p.intensity = min(1, max(0, newValue)); profile = p } }
    var color: NSColor {
        get { NSColor(hex: profile.colorHex) }
        set { var p = profile; p.colorHex = newValue.hex; profile = p }
    }
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = nil; objectWillChange.send()
        } catch { loginError = LF("无法更改登录项：%@。请先将 HazeFocus 移入“应用程序”。", error.localizedDescription) }
    }
    func updateAppearance() {
        isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    private func save() {
        if let data = try? JSONEncoder().encode(values) { storage.set(data, forKey: persistenceKey) }
        changed?()
    }
    func excludeCurrentApp() {
        guard let bundle = activeBundleID, bundle != Bundle.main.bundleIdentifier else { return }
        values.excludedApps[bundle] = activeAppName
    }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let value = UInt32(hex, radix: 16) ?? 0x11121A
        self.init(srgbRed: CGFloat((value >> 16) & 255)/255, green: CGFloat((value >> 8) & 255)/255,
                  blue: CGFloat(value & 255)/255, alpha: 1)
    }
    var hex: String {
        let c = usingColorSpace(.sRGB) ?? .black
        return String(format: "%02X%02X%02X", Int(c.redComponent*255), Int(c.greenComponent*255), Int(c.blueComponent*255))
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
    var stableID: String {
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() { return CFUUIDCreateString(nil, uuid) as String }
        return String(displayID)
    }
}
