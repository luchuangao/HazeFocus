import AppKit
import SwiftUI
import FocusCore
import Carbon

@objc(HazeFocusApplication)
final class HazeFocusApplication: NSApplication {
    @objc dynamic var hazeEnabled: Bool {
        get { Settings.shared.enabled }
        set { Settings.shared.enabled = newValue }
    }
    @objc dynamic var hazeIntensity: Double {
        get { Settings.shared.intensity * 100 }
        set { if newValue.isFinite { Settings.shared.intensity = newValue / 100 } }
    }
}

final class StatusButton: NSView {
    var clicked: ((NSEvent) -> Void)?
    var pressed: (() -> Void)?
    var scrolled: ((CGFloat) -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { clicked?(event) }
    override func rightMouseDown(with event: NSEvent) { clicked?(event) }
    override func accessibilityPerformPress() -> Bool { pressed?(); return true }
    override func scrollWheel(with event: NSEvent) {
        guard event.phase != .mayBegin, event.momentumPhase.isEmpty else { return }
        let delta = event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.002 : 0.025)
        if abs(delta) > 0.0001 { scrolled?(delta) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let settings = Settings.shared
    lazy var engine = DimmerEngine(settings: settings)
    let shortcut = GlobalShortcut()
    private var status: NSStatusItem!
    private var statusButton: StatusButton!
    private var window: NSWindow?
    private var lastShortcut = ""
    private var pendingClick: DispatchWorkItem?
    private let preview = CommandLine.arguments.contains("--preview")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let appMenu = NSMenu()
        let root = NSMenuItem(); root.submenu = NSMenu(); appMenu.addItem(root)
        root.submenu?.addItem(withTitle: L("关于 HazeFocus"), action: #selector(showSettings), keyEquivalent: "")
        root.submenu?.addItem(.separator())
        root.submenu?.addItem(withTitle: L("退出 HazeFocus"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenuItem(); let editMenu = NSMenu(title: L("编辑")); edit.submenu = editMenu; appMenu.addItem(edit)
        for (title, action, key) in [(L("撤销"), "undo:", "z"), (L("剪切"), "cut:", "x"), (L("复制"), "copy:", "c"), (L("粘贴"), "paste:", "v"), (L("全选"), "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        NSApp.mainMenu = appMenu
        status = NSStatusBar.system.statusItem(withLength: 30)
        if let button = status.button {
            let custom = StatusButton(frame: button.bounds); custom.autoresizingMask = [.width, .height]
            custom.clicked = { [weak self] event in self?.statusClicked(event) }
            custom.pressed = { [weak self] in self?.showMenu() }
            custom.scrolled = { [weak self] delta in
                guard let self else { return }
                self.settings.intensity += delta
                self.settings.enabled = self.settings.intensity > 0
            }
            custom.setAccessibilityElement(true); custom.setAccessibilityRole(.button)
            custom.setAccessibilityLabel(L("HazeFocus，点按打开菜单，双击开关遮罩"))
            button.addSubview(custom); statusButton = custom
        }
        shortcut.action = { [weak self] in self?.toggle() }
        settings.changed = { [weak self] in self?.settingsChanged() }
        engine.statusChanged = { [weak self] in self?.updateStatus() }
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        settingsChanged()
        if !preview { engine.start() }
        if !UserDefaults.standard.bool(forKey: "hasLaunched") || preview || CommandLine.arguments.contains("--settings") {
            showSettings(); UserDefaults.standard.set(true, forKey: "hasLaunched")
        }
    }
    private func settingsChanged() {
        let id = "\(settings.values.shortcutKey)-\(settings.values.shortcutModifiers)"
        if id != lastShortcut {
            if !shortcut.register(key: settings.values.shortcutKey, modifiers: settings.values.shortcutModifiers) {
                let alert = NSAlert(); alert.messageText = L("这个快捷键暂时不可用")
                alert.informativeText = L("可能已被其他应用占用，请在“快捷键”中换一个组合。"); alert.runModal()
            }
            lastShortcut = id
        }
        updateStatus()
        if !preview { engine.refresh() }
    }
    private func updateStatus() {
        let enabled = settings.enabled && !settings.temporarilyRevealed
        status.button?.image = BrandAssets.menuBar
        status.button?.appearsDisabled = !enabled
        status.button?.toolTip = LF("HazeFocus · %@ · %d%%\n滚动调节强度 · 双击开关", L(settings.enabled ? "开启" : "暂停"), Int(settings.intensity*100))
    }
    private func statusClicked(_ event: NSEvent) {
        if event.clickCount > 1 || event.modifierFlags.contains(.option) {
            pendingClick?.cancel(); toggle(); return
        }
        let work = DispatchWorkItem { [weak self] in self?.showMenu() }
        pendingClick = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
    }
    private func showMenu() {
        let menu = NSMenu(); menu.delegate = self
        let title = NSMenuItem(title: "HazeFocus", action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        let toggle = NSMenuItem(title: settings.enabled ? L("暂停遮罩") : L("开启遮罩"), action: #selector(self.toggle), keyEquivalent: "")
        toggle.target = self; toggle.state = settings.enabled ? .on : .off; menu.addItem(toggle)
        let sliderItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 255, height: 54))
        let label = NSTextField(labelWithString: LF("遮罩强度                  %d%%", Int(settings.intensity*100)))
        label.frame = NSRect(x: 20, y: 33, width: 220, height: 16); label.font = .systemFont(ofSize: 11)
        let slider = NSSlider(value: settings.intensity, minValue: 0, maxValue: 1, target: self, action: #selector(menuSlider(_:)))
        slider.frame = NSRect(x: 18, y: 7, width: 220, height: 22); slider.isContinuous = true
        slider.setAccessibilityLabel(L("遮罩强度"))
        container.addSubview(label); container.addSubview(slider); sliderItem.view = container; menu.addItem(sliderItem)
        menu.addItem(.separator())
        if let id = settings.activeBundleID, id != Bundle.main.bundleIdentifier {
            let excluded = settings.values.excludedApps[id] != nil
            let item = NSMenuItem(title: excluded ? LF("移除“%@”的例外", settings.activeAppName) : LF("使用“%@”时暂停", settings.activeAppName), action: #selector(toggleCurrentException), keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        let displayItem = NSMenuItem(title: L("显示器"), action: nil, keyEquivalent: "")
        let displays = NSMenu()
        for screen in NSScreen.screens {
            let item = NSMenuItem(title: screen.localizedName, action: #selector(toggleDisplay(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = screen.stableID
            item.state = settings.values.disabledDisplays.contains(screen.stableID) ? .off : .on; displays.addItem(item)
        }
        displayItem.submenu = displays; menu.addItem(displayItem)
        let settingsItem = NSMenuItem(title: L("设置…"), action: #selector(showSettings), keyEquivalent: ","); settingsItem.target = self; menu.addItem(settingsItem)
        if !settings.accessibilityGranted {
            let item = NSMenuItem(title: L("提高窗口识别准确度…"), action: #selector(requestPermission), keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: L("退出 HazeFocus"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu; status.button?.performClick(nil)
    }
    func menuDidClose(_ menu: NSMenu) { status.menu = nil }
    @objc func toggle() { settings.enabled.toggle() }
    @objc private func menuSlider(_ sender: NSSlider) {
        settings.intensity = sender.doubleValue; settings.enabled = sender.doubleValue > 0
        if let label = sender.superview?.subviews.first as? NSTextField { label.stringValue = LF("遮罩强度                  %d%%", Int(settings.intensity*100)) }
    }
    @objc private func toggleDisplay(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String else { return }
        if settings.values.disabledDisplays.contains(id) { settings.values.disabledDisplays.remove(id) }
        else { settings.values.disabledDisplays.insert(id) }
    }
    @objc private func toggleCurrentException() {
        guard let id = settings.activeBundleID else { return }
        if settings.values.excludedApps[id] != nil { settings.values.excludedApps.removeValue(forKey: id) }
        else { settings.excludeCurrentApp() }
    }
    @objc private func requestPermission() { settings.requestAccessibility() }
    @objc func showSettings() {
        if window == nil {
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 650),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            win.title = "HazeFocus"; win.titleVisibility = .hidden; win.titlebarAppearsTransparent = true
            win.isReleasedWhenClosed = false; win.minSize = NSSize(width: 840, height: 640)
            win.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            win.center(); window = win
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: raw), let command = ControlCommand.parse(url) else { return }
        switch command {
        case .enable(let enabled): settings.enabled = enabled
        case .toggle: settings.enabled.toggle()
        case .intensity(let value): settings.intensity = value; settings.enabled = value > 0
        case .settings: showSettings()
        }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let descriptor = NSAppleEventDescriptor(eventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL), targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
            descriptor.setParam(NSAppleEventDescriptor(string: url.absoluteString), forKeyword: keyDirectObject)
            handleURL(descriptor, reply: NSAppleEventDescriptor.null())
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return false }
    func applicationWillTerminate(_ notification: Notification) { pendingClick?.cancel(); engine.stop() }
}
