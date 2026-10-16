import AppKit
import Carbon

final class GlobalShortcut {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var localMonitor: Any?
    private var keyCode: UInt32 = 4
    private var modifierMask: UInt32 = 0
    private var lastFire: TimeInterval = 0
    var action: (() -> Void)?
    func register(key: UInt32, modifiers: UInt32) -> Bool {
        keyCode = key; modifierMask = modifiers
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().fire()
                return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        // App-directed key events (including accessibility keyboard tools) may
        // bypass Carbon's global dispatcher. Handle those while our app is key.
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, !ShortcutRecorder.isRecording, !event.isARepeat,
                      UInt32(event.keyCode) == self.keyCode else { return event }
                var mask: UInt32 = 0
                if event.modifierFlags.contains(.control) { mask |= UInt32(controlKey) }
                if event.modifierFlags.contains(.option) { mask |= UInt32(optionKey) }
                if event.modifierFlags.contains(.command) { mask |= UInt32(cmdKey) }
                if event.modifierFlags.contains(.shift) { mask |= UInt32(shiftKey) }
                guard mask == self.modifierMask else { return event }
                self.fire(); return nil
            }
        }
        let id = EventHotKeyID(signature: 0x485A4643, id: 1)
        return RegisterEventHotKey(key, modifiers, id, GetApplicationEventTarget(), 0, &reference) == noErr
    }
    private func fire() {
        let now = ProcessInfo.processInfo.systemUptime
        guard !ShortcutRecorder.isRecording, now-lastFire > 0.12 else { return }
        lastFire = now; action?()
    }
    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}

final class ShortcutRecorder: NSButton {
    static var isRecording = false
    var recorded: ((UInt32, UInt32, String) -> Void)?
    private var monitor: Any?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self; action = #selector(beginRecording)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        target = self; action = #selector(beginRecording)
    }
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        beginRecording()
    }
    @objc private func beginRecording() {
        guard monitor == nil else { return }
        Self.isRecording = true
        window?.makeFirstResponder(self)
        title = L("请按快捷键，Esc 取消")
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { self.endRecording(); return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.intersection([.command, .control, .option]).isEmpty,
                  let key = event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else { NSSound.beep(); return nil }
            var carbon: UInt32 = 0; var label = ""
            if flags.contains(.control) { carbon |= UInt32(controlKey); label += "⌃" }
            if flags.contains(.option) { carbon |= UInt32(optionKey); label += "⌥" }
            if flags.contains(.shift) { carbon |= UInt32(shiftKey); label += "⇧" }
            if flags.contains(.command) { carbon |= UInt32(cmdKey); label += "⌘" }
            label += event.keyCode == 49 ? "Space" : key
            self.recorded?(UInt32(event.keyCode), carbon, label); self.endRecording(); return nil
        }
    }
    override func resignFirstResponder() -> Bool { endRecording(); return super.resignFirstResponder() }
    private func endRecording() {
        Self.isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        title = Settings.shared.values.shortcutLabel
    }
    deinit { if let monitor { NSEvent.removeMonitor(monitor); Self.isRecording = false } }
}
