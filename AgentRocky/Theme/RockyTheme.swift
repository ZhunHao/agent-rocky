import SwiftUI
import AppKit

/// Eridian palette: stone grays + ammonia-blue accent.
/// v1 ships one theme; the protocol is in place so v2 can add more.
enum RockyTheme {
    static let theme = Theme(
        name: "Eridian",
        background: .dynamic(
            light: NSColor(white: 0.96, alpha: 1.0),
            dark:  NSColor(white: 0.12, alpha: 1.0)
        ),
        foreground: .dynamic(
            light: NSColor(white: 0.10, alpha: 1.0),
            dark:  NSColor(white: 0.95, alpha: 1.0)
        ),
        accent: .dynamic(
            light: NSColor(red: 0.22, green: 0.42, blue: 0.65, alpha: 1.0),
            dark:  NSColor(red: 0.45, green: 0.65, blue: 0.85, alpha: 1.0)
        ),
        userBubble: .dynamic(
            light: NSColor(white: 0.90, alpha: 1.0),
            dark:  NSColor(white: 0.20, alpha: 1.0)
        ),
        assistantBubble: .dynamic(
            light: NSColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1.0),
            dark:  NSColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1.0)
        ),
        errorColor: .dynamic(
            light: NSColor.systemRed,
            dark:  NSColor.systemRed.withAlphaComponent(0.9)
        ),
        monoFont: .system(.body, design: .monospaced)
    )
}
