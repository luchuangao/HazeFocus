# HazeFocus brand assets

2026-10-16：用户指定暂用本目录的 `Selected-Logo-Reference.png`。不继续探索或更换设计。

- `Selected-Logo-Reference.png`：用户确认的原始展示图。
- `AppIcon-Source.png`：从右上黑底白标图标整理的透明素材。
- `LogoMark-Source.png`：从左上四条黑色线条标志整理的透明素材。
- `AppIcon.png`：1024×1024 macOS 应用图标，含透明外边距。
- `LogoMark.png`：透明单色标志，设置侧栏使用。
- `MenuBarTemplate.png`、`MenuBarTemplate@2x.png`：18×14 pt 的单色菜单栏模板，系统负责适配明暗外观；暂停时降低图标明度。
- `../AppIcon.icns`：16–1024 px 的原生图标集合。

两个源素材由内置 imagegen 编辑模式整理，输入为同一份用户确认的展示图；其余文件由 `scripts/make-icon.swift` 去除透明外边距后等比重采样生成。脚本只负责资源打包，不以代码重画标志。运行 `xcrun swift scripts/make-icon.swift` 可重新生成。

## 素材整理提示词

App icon: Precise asset extraction, NOT a redesign. Extract ONLY the large black rounded-square application icon in the upper-right of the approved HazeFocus reference sheet. Remove other elements, presentation background and all text. Deliver a single high-resolution square PNG with actual transparent exterior corners and margins. Preserve the exact four white horizontal strokes, relative lengths, rounded left ends, tapered/curved right ends, spacing and positioning. Do not reinterpret or stylize. Flat black tile, crisp white mark, no paper texture, wordmark, numbers or board.

Logo mark: Precise asset extraction, NOT a redesign. Extract ONLY the large standalone BLACK four-stroke logo mark from the upper-left of the approved reference. Remove wordmark, icon, small reproduction and off-white backdrop to genuine transparency. Preserve the original four strokes: vertically aligned rounded left ends, lengths about 58%, 100%, 67%, 37%; slanted top-right ending, upturned second ending, curved third ending and capsule bottom. Preserve the undistorted silhouette; no added strokes, textures, shading, text or tiles.
