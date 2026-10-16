import SwiftUI
import AppKit
import FocusCore

private let accent = Color(red: 0.48, green: 0.43, blue: 0.88)

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "聚焦", advanced = "遮罩", displays = "显示器", shortcuts = "快捷键", rules = "应用例外", about = "关于"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "viewfinder"
        case .advanced: return "circle.lefthalf.filled"
        case .displays: return "display.2"
        case .shortcuts: return "command"
        case .rules: return "square.stack.3d.up.slash"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @State private var page: SettingsPage = .general
    @State private var screenRefresh = false
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(nsImage: BrandAssets.logoMark).renderingMode(.template)
                        .resizable().scaledToFit().frame(width: 30, height: 26)
                        .foregroundStyle(.primary).accessibilityHidden(true)
                    Text("HazeFocus").font(.system(size: 17, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.85)
                }.padding(.top, 25).padding(.bottom, 25).padding(.leading, 10)
                ForEach(SettingsPage.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon).font(.system(size: 15)).frame(width: 20)
                            Text(L(item.rawValue)).font(.system(size: 13, weight: page == item ? .semibold : .regular))
                                .lineLimit(1).minimumScaleFactor(0.85)
                            Spacer()
                        }.padding(.horizontal, 13).padding(.vertical, 10)
                            .foregroundStyle(page == item ? accent : Color.primary.opacity(0.7))
                            .background(page == item ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(page == item ? .isSelected : [])
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(settings.enabled ? Color.green : Color.secondary).frame(width: 6, height: 6)
                    Text(settings.enabled ? L("专注已开启") : L("遮罩已暂停")).font(.system(size: 11)).foregroundStyle(.secondary)
                }.padding(12)
                Text(L("留一点安静，给眼前的事。")).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.leading, 12).padding(.bottom, 16)
            }.padding(.horizontal, 14).frame(width: 172).background(.ultraThinMaterial)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).font(.system(size: 25, weight: .semibold, design: .rounded))
                            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if page == .general {
                            Toggle(L("启用遮罩"), isOn: Binding(get: { settings.enabled }, set: { settings.enabled = $0 }))
                                .labelsHidden().toggleStyle(.switch).tint(accent).accessibilityLabel(L("启用遮罩"))
                        }
                    }
                    content
                }.padding(30)
            }.background(Color(nsColor: .windowBackgroundColor))
        }.frame(minWidth: 820, minHeight: 590).tint(accent)
    }
    var title: String {
        switch page {
        case .general: return L("把注意力，留在当前窗口")
        case .advanced: return L("刚刚好的明暗")
        case .displays: return L("每一块屏幕，各得其所")
        case .shortcuts: return L("专注，触手可及")
        case .rules: return L("为这些应用留个例外")
        case .about: return "HazeFocus"
        }
    }
    var subtitle: String {
        switch page {
        case .general: return L("背景轻轻淡去，眼前的工作依然清晰。")
        case .advanced: return L("让背景的颜色与浓度，适应你的工作习惯。")
        case .displays: return L("窗口跨屏时，遮罩会自动跟随。")
        case .shortcuts: return L("不打断手上的事，也能随时调整。")
        case .rules: return L("切换到例外应用时自动暂停，离开后恢复。")
        case .about: return L("一个轻巧、安静的原生 macOS 专注工具。")
        }
    }
    @ViewBuilder var content: some View {
        switch page {
        case .general: general
        case .advanced: advanced
        case .displays: displays
        case .shortcuts: shortcuts
        case .rules: rules
        case .about: about
        }
    }
    var general: some View {
        VStack(spacing: 18) {
            DesktopPreview(intensity: settings.enabled ? settings.intensity : 0, color: Color(nsColor: settings.color))
                .frame(height: 215).accessibilityLabel(LF("遮罩预览，背景浓度 %d 百分比", Int(settings.intensity*100)))
            card {
                HStack {
                    Label(L("遮罩强度"), systemImage: "sun.max")
                    Spacer()
                    Text("\(Int(settings.intensity*100))% ").font(.system(size: 20, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(accent)
                }
                Slider(value: Binding(get: { settings.intensity }, set: { settings.intensity = $0 }), in: 0...1)
                    .accessibilityLabel(L("遮罩强度"))
                HStack { Text(L("轻柔")); Spacer(); Text(L("沉浸")) }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
            card {
                Toggle(L("登录时自动打开"), isOn: Binding(get: { settings.loginEnabled }, set: { settings.setLogin($0) }))
                if let error = settings.loginError { Text(error).font(.caption).foregroundStyle(.orange) }
                Divider().padding(.vertical, 5)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: settings.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised").foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.accessibilityGranted ? L("精确窗口识别已开启") : L("让切换更及时、识别更准确")).font(.system(size: 12, weight: .medium))
                        Text(settings.accessibilityGranted ? L("已获辅助功能权限，自动跟随当前窗口。") : L("基础模式已可使用。授权辅助功能可提高窗口识别准确度。"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !settings.accessibilityGranted { Button(L("去授权…")) { settings.requestAccessibility() }.controlSize(.small) }
                }
            }
        }
    }
    var advanced: some View {
        VStack(spacing: 16) {
            card {
                Text(L("突出显示")).font(.headline)
                Picker(L("聚焦范围"), selection: $settings.values.allAppWindows) {
                    Text(L("当前一个窗口")).tag(false)
                    Text(L("当前应用的所有窗口")).tag(true)
                }.pickerStyle(.segmented).labelsHidden()
                Text(L("背景窗口保持可点按，直接点击即可切换聚焦。 ")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                ColorPicker(L("遮罩颜色"), selection: Binding(get: { Color(nsColor: settings.color) }, set: { settings.color = NSColor($0) }), supportsOpacity: false)
                Divider().padding(.vertical, 5)
                HStack {
                    Text(L("渐变时间"))
                    Spacer()
                    Text(String(format: L("%.2f 秒"), settings.values.animationDuration)).monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $settings.values.animationDuration, in: 0...1, step: 0.05).accessibilityLabel(L("渐变时间"))
                Text(L("开启与窗口切换时柔和过渡；遵循系统“减少动态效果”设置。")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                Toggle(L("为深色与浅色外观分别保存设置"), isOn: $settings.values.separateAppearance)
                Text(LF("分别记住开关、强度与颜色。当前正在编辑：%@。", L(settings.values.separateAppearance && settings.isDark ? "深色外观" : "浅色 / 共用外观")))
                    .font(.caption).foregroundStyle(.secondary)
                Divider().padding(.vertical, 5)
                Toggle(L("按住 Fn 键，临时显示所有窗口"), isOn: $settings.values.holdFnToReveal)
                Text(L("松开后立即恢复，方便拖拽文件或对照内容。")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    var displays: some View {
        VStack(spacing: 16) {
            card {
                Picker(L("多显示器策略"), selection: $settings.values.displayMode) {
                    Text(L("只突出当前聚焦窗口")).tag(DisplayMode.activeDisplay)
                    Text(L("每块屏幕保留一个前置窗口")).tag(DisplayMode.eachDisplay)
                }.pickerStyle(.radioGroup)
                Text(L("选择第一项时，其他显示器会整体变暗。 ")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                HStack { Text(L("参与遮罩的显示器")).font(.headline); Spacer(); Button { screenRefresh.toggle() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless).accessibilityLabel(L("刷新显示器")) }
                ForEach(Array(NSScreen.screens.enumerated()), id: \.element.stableID) { index, screen in
                    if index > 0 { Divider() }
                    HStack(spacing: 12) {
                        Image(systemName: "display").font(.system(size: 29)).foregroundStyle(accent).frame(width: 42)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(screen.localizedName))
                            Text("\(Int(screen.frame.width)) × \(Int(screen.frame.height)) pt\(index == 0 ? L(" · 主显示器") : "")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle(LF("在 %@ 上启用遮罩", L(screen.localizedName)), isOn: Binding(get: {
                            !settings.values.disabledDisplays.contains(screen.stableID)
                        }, set: { enabled in
                            if enabled { settings.values.disabledDisplays.remove(screen.stableID) }
                            else { settings.values.disabledDisplays.insert(screen.stableID) }
                        })).labelsHidden().toggleStyle(.switch)
                    }.padding(.vertical, 6)
                }
            }.id(screenRefresh)
        }
    }
    var shortcuts: some View {
        VStack(spacing: 16) {
            card {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L("开启 / 暂停遮罩")).font(.headline)
                        Text(L("点按右侧，然后按下新的组合键。")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShortcutRecorderView(settings: settings).frame(width: 172, height: 30)
                }
                Button(L("恢复默认 ⌃⌥⌘H")) {
                    var p = settings.values; p.shortcutKey = 4; p.shortcutModifiers = 0x1900; p.shortcutLabel = "⌃⌥⌘H"; settings.values = p
                }.buttonStyle(.link).font(.caption)
            }
            card {
                shortcutRow("computermouse", L("双击菜单栏图标"), L("开启或暂停遮罩"))
                Divider().padding(.vertical, 6)
                shortcutRow("hand.draw", L("在菜单栏图标上滚动"), L("调整强度；滚动到 0 时暂停"))
                Divider().padding(.vertical, 6)
                shortcutRow("option", L("Option + 点按图标"), L("快速开关遮罩"))
                Divider().padding(.vertical, 6)
                shortcutRow("fn", L("按住 Fn"), L("临时取消遮罩，松开恢复"))
            }
            card {
                Text(L("自动化")).font(.headline)
                Text(L("在快捷指令中使用“打开 URL”，或用 AppleScript 控制开关与强度。")).font(.caption).foregroundStyle(.secondary)
                Text("hazefocus://toggle\nhazefocus://intensity?value=70").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            }
        }
    }
    var rules: some View {
        VStack(spacing: 16) {
            card {
                HStack { Text(L("自动暂停列表")).font(.headline); Spacer(); Button(L("添加应用…")) { chooseApplication() } }
                if settings.values.excludedApps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.slash").font(.system(size: 34, weight: .light)).foregroundStyle(accent.opacity(0.7))
                        Text(L("还没有例外应用")).font(.headline)
                        Text(L("例如演示、视频或设计应用，使用时自动恢复屏幕亮度。")).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 35)
                }
                ForEach(settings.values.excludedApps.keys.sorted(), id: \.self) { bundleID in
                    Divider()
                    HStack {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 28, height: 28)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(settings.values.excludedApps[bundleID] ?? bundleID)
                            Text(bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { settings.values.excludedApps.removeValue(forKey: bundleID) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel(LF("移除 %@", settings.values.excludedApps[bundleID] ?? bundleID))
                    }.padding(.vertical, 5)
                }
            }
            Text(L("也可以在菜单栏菜单中，把正在使用的应用直接加入例外。")).font(.caption).foregroundStyle(.secondary)
        }
    }
    var about: some View {
        VStack(spacing: 20) {
            card {
                VStack(spacing: 15) {
                    Image(nsImage: BrandAssets.appIcon).resizable().frame(width: 96, height: 96)
                    Text("HazeFocus").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text(LF("%@ · 原生 macOS 应用", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.2")).font(.caption).foregroundStyle(.secondary)
                    Text(L("聚焦眼前，淡去纷扰。")).font(.system(size: 15)).foregroundStyle(accent)
                    Text(L("参考 HazeOver 的公开功能独立实现。\n所有设置保存在本机，无账号、无联网依赖。"))
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 15)
            }
            card {
                Label(L("轻巧常驻菜单栏"), systemImage: "menubar.rectangle")
                Label(L("保留当前窗口的原始亮度"), systemImage: "sun.max")
                Label(L("无需录屏权限"), systemImage: "lock.shield")
                Link(L("了解参考应用 HazeOver ↗"), destination: URL(string: "https://hazeover.com/")!).font(.caption)
            }
        }
    }
    func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content).font(.system(size: 13))
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.065)))
    }
    func shortcutRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(accent).frame(width: 30)
            Text(title)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
    func chooseApplication() {
        let panel = NSOpenPanel(); panel.title = L("选择自动暂停遮罩的应用")
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
                settings.values.excludedApps[id] = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? url.deletingPathExtension().lastPathComponent
            }
        }
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @ObservedObject var settings: Settings
    func makeNSView(context: Context) -> ShortcutRecorder {
        let button = ShortcutRecorder(); button.bezelStyle = .rounded
        button.recorded = { key, modifiers, label in
            var p = settings.values; p.shortcutKey = key; p.shortcutModifiers = modifiers; p.shortcutLabel = label; settings.values = p
        }
        button.setAccessibilityLabel(L("录制全局快捷键"))
        return button
    }
    func updateNSView(_ button: ShortcutRecorder, context: Context) { button.title = settings.values.shortcutLabel }
}

struct DesktopPreview: View {
    let intensity: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                LinearGradient(colors: [Color(red: 0.35, green: 0.39, blue: 0.60), Color(red: 0.68, green: 0.56, blue: 0.69), Color(red: 0.88, green: 0.75, blue: 0.67)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.09)).frame(width: 340).offset(x: -150, y: 150)
                mockWindow(title: L("资料"), width: 170, height: 122, active: false).offset(x: -w*0.26, y: -16)
                mockWindow(title: L("灵感"), width: 155, height: 115, active: false).offset(x: w*0.27, y: 22)
                color.opacity(intensity)
                mockWindow(title: L("正在专注"), width: 245, height: 148, active: true).shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                VStack { Spacer(); Text(L("实时效果预览")).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.7)).padding(.bottom, 9) }
            }.clipShape(RoundedRectangle(cornerRadius: 15))
        }
    }
    func mockWindow(title: String, width: CGFloat, height: CGFloat, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ForEach([Color(red: 1, green: 0.38, blue: 0.35), Color(red: 1, green: 0.75, blue: 0.28), Color(red: 0.25, green: 0.78, blue: 0.38)], id: \.self) { c in Circle().fill(c).frame(width: 6, height: 6) }
                Spacer(); Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.black.opacity(0.45)); Spacer()
            }.padding(10).background(Color.black.opacity(0.03))
            VStack(alignment: .leading, spacing: 10) {
                if active {
                    Text(L("一次，只做一件事。")).font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(Color(red: 0.20, green: 0.21, blue: 0.29)).padding(.bottom, 4)
                }
                ForEach(0..<3) { i in Capsule().fill(Color.black.opacity(active ? 0.075 : 0.11)).frame(width: (width-40) * (i == 2 ? 0.55 : 1), height: 5) }
            }.padding(18)
            Spacer(minLength: 0)
        }.frame(width: width, height: height).background(Color(red: 0.98, green: 0.97, blue: 0.96)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
