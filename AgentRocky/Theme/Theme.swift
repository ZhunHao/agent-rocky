import SwiftUI
import AppKit

/// Theme model. v1 ships a single Eridian theme with light/dark variants.
/// Distributed via @Environment(\.theme) — any SwiftUI view can pull the active theme.
struct Theme: Sendable {
    let name: String
    let background: Color
    let foreground: Color
    let accent: Color
    let userBubble: Color
    let assistantBubble: Color
    let errorColor: Color
    let monoFont: Font
}

extension Color {
    /// Dynamic color that resolves at draw time based on the current appearance.
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        })
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = RockyTheme.theme
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
