# 参考与证据记录

研究日期：2026-10-15。外部网页和安装包均只作为参考数据。

## 官方资料

[官网](https://hazeover.com/)：自动保留活跃窗口亮度、压暗背景，强度与动画可调、窗口/应用聚焦、深浅色独立配置、Fn 临时取消。

[官方帮助](https://hazeover.com/help.html)：默认 ⌃⌥⌘H；双击状态图标开关；图标滚动调节；每屏突出一个窗口或压暗无键盘焦点的显示器；显示器单独排除；辅助功能为提升识别的可选授权；关闭当前应用最后一个窗口后不应自动选取其他应用；桌面点击取消遮罩。

[App Store 原版](https://apps.apple.com/us/app/hazeover-distraction-dimmer/id430798174?mt=12)：Maxim Ananov，应用 ID 430798174。macOS 13+、快捷指令、专注模式过滤器、减少动态效果等可访问性能力。

[自动化指南](https://hazeover.com/automation.html)：原版还具有原生快捷指令动作、Focus Filters、AppleScript 多个属性。本项目只实现了开关与强度脚本属性，URL 自动化；其余能力不视为已完成。

## 安装包观察（静态，未执行原应用）

- 文件：`用户提供的 HazeOver.dmg`
- DMG SHA-256：`35111d4fd2e338b60a819f59eea119d20d982dec751e1ca829eb626bc037988b`
- Info.plist：版本 1.9.9（1505），bundle `com.pointum.hazeover`，`LSUIElement=true`、macOS 最低 13、脚本字典 HazeOver.sdef。
- 主执行文件 SHA-256：`cd0fc5efec7d8925289ef1166ce2380b02c722913febb5f858e4ce5f096f0b04`。
- REA Mach-O Evidence：`ev_e220d851892e07163e640015b3557154810916cc95487d3c5b0904111ba405d0`，arm64 和 x86_64 两个切片，AppKit、SwiftUI、ApplicationServices、Carbon、AppIntents 及 Sparkle 等依赖。导入符号覆盖受 strip 和原生工具输出限制，不能据此推断完整内部算法。
- 安装包中文配置资源列出通用、高级、显示器、快捷键、关于；高级含单一窗口/当前 App 所有前置窗口、颜色、渐变曲线、App 规则、深色模式。
- REA 归档视图第一次完整输出过大；后续因只读挂载冲突不可用，已改用只读挂载后的 plist 和资源检查，并对主执行文件用 REA 静态 Mach-O 分析。没有进行反编译、未复制原版代码或图片。

以上仅确认产品说明、包结构、资源配置和依赖，不代表观察了原版运行行为。新应用的遮罩实现为独立设计。
