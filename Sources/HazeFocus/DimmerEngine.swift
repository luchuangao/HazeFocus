import AppKit
import ApplicationServices
import FocusCore
import QuartzCore

final class ShadePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ShadeView: NSView {
    var color = NSColor.black
    var intensity: Double = 0.65
    var holes: [CGRect] = []
    var windows: [FocusWindow] = []
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        c.clear(bounds)
        c.setFillColor(color.withAlphaComponent(intensity).cgColor)
        c.fill(bounds)
        // Draw the actual front-to-back order: overlapping highlighted windows
        // must never toggle one another back to opaque as an even-odd path would.
        // Non-highlighted windows in front of a hole retain their shading.
        for window in windows.reversed() {
            let highlighted = holes.contains(window.frame)
            guard highlighted || holes.contains(where: { $0.intersects(window.frame) }) else { continue }
            c.saveGState()
            c.setBlendMode(highlighted ? .clear : .copy)
            c.setFillColor(color.withAlphaComponent(intensity).cgColor)
            let path = CGPath(roundedRect: window.frame, cornerWidth: 10, cornerHeight: 10, transform: nil)
            c.addPath(path); c.fillPath(); c.restoreGState()
        }
    }
}

final class ShadeSurface: NSView {
    private var current: ShadeView?
    func update(color: NSColor, intensity: Double, holes: [CGRect], windows: [FocusWindow], duration: Double) {
        let oldIDs = current.map { view in Set(view.windows.filter { view.holes.contains($0.frame) }.map(\.id)) } ?? []
        let newIDs = Set(windows.filter { holes.contains($0.frame) }.map(\.id))
        let shouldFade = current != nil && oldIDs != newIDs && duration > 0
        if !shouldFade, let current {
            current.color = color; current.intensity = intensity; current.holes = holes; current.windows = windows
            current.needsDisplay = true
            return
        }
        let previous = current
        // A quick sequence of switches may interrupt an earlier transition.
        subviews.filter { $0 !== previous }.forEach { $0.removeFromSuperview() }
        let next = ShadeView(frame: bounds); next.autoresizingMask = [.width, .height]; next.wantsLayer = true
        next.color = color; next.intensity = intensity; next.holes = holes; next.windows = windows
        next.alphaValue = shouldFade ? 0 : 1
        addSubview(next); current = next
        if shouldFade {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration; context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                previous?.animator().alphaValue = 0; next.animator().alphaValue = 1
            } completionHandler: { previous?.removeFromSuperview() }
        } else { previous?.removeFromSuperview() }
    }
}

final class DimmerEngine {
    private let settings: Settings
    private var panels: [String: ShadePanel] = [:]
    private var timer: Timer?
    private var tokens: [NSObjectProtocol] = []
    private var axObserver: AXObserver?
    private var observedPID: pid_t = -1
    private var previousSignature = ""
    private var suspended = false
    private var dirty = true
    private var lastPoll: TimeInterval = 0
    private var lastPermissionCheck: TimeInterval = 0
    private var appearanceToken: NSKeyValueObservation?
    private var mouseMonitor: Any?
    private var desktopRevealed = false
    var statusChanged: (() -> Void)?

    init(settings: Settings) { self.settings = settings }
    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        }
        tokens.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.suspended = true; self?.hide()
        })
        tokens.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.suspended = false; self?.refresh()
        })
        tokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.panels.values.forEach { $0.close() }; self.panels.removeAll(); self.refresh()
        })
        appearanceToken = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.settings.updateAppearance(); self?.refresh() }
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            let point = NSEvent.mouseLocation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder",
                      let primary = NSScreen.screens.first,
                      NSScreen.screens.contains(where: { $0.visibleFrame.contains(point) }) else { return }
                let windows = Self.visibleWindows(primaryHeight: primary.frame.height)
                self.desktopRevealed = !windows.contains { $0.layer == 0 && $0.frame.contains(point) }
                self.refresh()
            }
        }
        let t = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.02; RunLoop.main.add(t, forMode: .common); timer = t
        refresh()
    }
    func stop() {
        timer?.invalidate(); timer = nil
        for token in tokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            NotificationCenter.default.removeObserver(token)
        }
        tokens.removeAll(); removeAXObserver()
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor); self.mouseMonitor = nil }
        panels.values.forEach { $0.close() }; panels.removeAll()
    }
    func refresh() { dirty = true; tick(force: true) }
    private func hide() {
        panels.values.forEach { $0.orderOut(nil) }; previousSignature = ""
    }
    private func tick(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPermissionCheck > 1 {
            lastPermissionCheck = now
            let granted = AXIsProcessTrusted()
            if granted != settings.accessibilityGranted {
                settings.accessibilityGranted = granted
                removeAXObserver(); dirty = true; statusChanged?()
            }
        }
        let reveal = settings.values.holdFnToReveal && NSEvent.modifierFlags.contains(.function)
        if reveal != settings.temporarilyRevealed { settings.temporarilyRevealed = reveal; dirty = true; statusChanged?() }
        if let front = NSWorkspace.shared.frontmostApplication {
            if settings.activeAppName != front.localizedName { settings.activeAppName = front.localizedName ?? L("当前应用") }
            if settings.activeBundleID != front.bundleIdentifier { settings.activeBundleID = front.bundleIdentifier }
            if front.bundleIdentifier != "com.apple.finder" { desktopRevealed = false }
        }
        guard !suspended, settings.enabled, settings.intensity > 0, !reveal else { hide(); return }
        // AX events provide immediate updates; this bounded fallback covers apps
        // that omit notifications as well as permission-free operation.
        guard force || dirty || now - lastPoll > 0.22 else { return }
        lastPoll = now; dirty = false
        guard let front = NSWorkspace.shared.frontmostApplication,
              let primary = NSScreen.screens.first else { hide(); return }
        guard settings.values.excludedApps[front.bundleIdentifier ?? ""] == nil else { hide(); return }
        if observedPID != front.processIdentifier { attachAXObserver(pid: front.processIdentifier) }
        let windows = Self.visibleWindows(primaryHeight: primary.frame.height)
        let axFrame = settings.accessibilityGranted ? focusedFrame(pid: front.processIdentifier, primaryHeight: primary.frame.height) : nil
        let focus = FocusGeometry.focused(windows: windows, pid: front.processIdentifier, axFrame: axFrame)
        // Clicking the desktop yields Finder without an actual focused window.
        if front.bundleIdentifier == "com.apple.finder",
           desktopRevealed || (axFrame == nil && (settings.accessibilityGranted || focus == nil)) { hide(); return }
        var signature = "\(settings.profile)-\(settings.values.allAppWindows)-\(settings.values.displayMode)-\(settings.values.disabledDisplays.sorted())"
        signature += windows.map { "\($0.id):\($0.frame)" }.joined()
        signature += "focus:\(focus?.id ?? -1)"
        guard signature != previousSignature else { return }
        previousSignature = signature
        for screen in NSScreen.screens {
            if settings.values.disabledDisplays.contains(screen.stableID) {
                panels[screen.stableID]?.orderOut(nil); continue
            }
            let panel = panelForScreen(screen)
            guard let view = panel.contentView as? ShadeSurface else { continue }
            var holes = FocusGeometry.holes(windows: windows, focused: focus, pid: front.processIdentifier,
                                           screen: screen.frame, mode: settings.values.displayMode,
                                           allAppWindows: settings.values.allAppWindows)
            // Preserve app-owned floating palettes and modal sheets above the
            // selected window, rather than painting over their controls.
            holes += windows.filter { $0.pid == front.processIdentifier && $0.layer > 0 }.map(\.frame)
            let localHoles = holes.map { FocusGeometry.localRect($0, screen: screen.frame) }
            let localWindows = windows.map { FocusWindow(id: $0.id, pid: $0.pid,
                frame: FocusGeometry.localRect($0.frame, screen: screen.frame), layer: $0.layer) }
            let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : settings.values.animationDuration
            view.update(color: settings.color, intensity: settings.intensity, holes: localHoles, windows: localWindows, duration: duration)
            if !panel.isVisible {
                panel.alphaValue = 0; panel.orderFrontRegardless()
                let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : settings.values.animationDuration
                NSAnimationContext.runAnimationGroup { context in context.duration = duration; panel.animator().alphaValue = 1 }
            }
        }
    }

    static func visibleWindows(primaryHeight: CGFloat) -> [FocusWindow] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { item in
            guard let id = item[kCGWindowNumber as String] as? Int,
                  let pid = item[kCGWindowOwnerPID as String] as? Int32,
                  let layer = item[kCGWindowLayer as String] as? Int, (0...3).contains(layer),
                  let info = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: info as CFDictionary), frame.width > 20, frame.height > 20,
                  (item[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  pid != ProcessInfo.processInfo.processIdentifier || layer == 0 else { return nil }
            return FocusWindow(id: id, pid: pid, frame: FocusGeometry.appKitRect(frame, primaryHeight: primaryHeight), layer: layer)
        }
    }

    private func panelForScreen(_ screen: NSScreen) -> ShadePanel {
        if let panel = panels[screen.stableID] { return panel }
        let panel = ShadePanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.setFrame(screen.frame, display: false)
        panel.level = .floating; panel.backgroundColor = .clear; panel.isOpaque = false
        panel.hasShadow = false; panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false; panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.sharingType = .none
        panel.contentView = ShadeSurface(frame: CGRect(origin: .zero, size: screen.frame.size))
        panels[screen.stableID] = panel
        return panel
    }

    private func focusedFrame(pid: pid_t, primaryHeight: CGFloat) -> CGRect? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var pos: CFTypeRef?; var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let pos, let size, CFGetTypeID(pos) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var dimensions = CGSize.zero
        guard AXValueGetValue(pos as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return FocusGeometry.appKitRect(CGRect(origin: point, size: dimensions), primaryHeight: primaryHeight)
    }
    private func removeAXObserver() {
        if let axObserver { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(axObserver), .commonModes) }
        axObserver = nil; observedPID = -1
    }
    private func attachAXObserver(pid: pid_t) {
        removeAXObserver(); observedPID = pid
        guard settings.accessibilityGranted else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            let engine = Unmanaged<DimmerEngine>.fromOpaque(refcon).takeUnretainedValue()
            if notification as String == kAXFocusedWindowChangedNotification || notification as String == kAXWindowCreatedNotification {
                engine.attachAXObserver(pid: engine.observedPID)
            }
            engine.refresh()
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXFocusedWindowChangedNotification, kAXWindowCreatedNotification,
                     kAXWindowMovedNotification, kAXWindowResizedNotification,
                     kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
                     kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(observer, app, name as CFString, context)
        }
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focused) == .success,
           let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
            for name in [kAXWindowMovedNotification, kAXWindowResizedNotification,
                         kAXWindowMiniaturizedNotification, kAXUIElementDestroyedNotification] {
                AXObserverAddNotification(observer, focused as! AXUIElement, name as CFString, context)
            }
        }
        axObserver = observer
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
}
