import Foundation

/// Follow the system's per-app language preference (English / Simplified Chinese).
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, value: key, comment: "")
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: arguments)
}
