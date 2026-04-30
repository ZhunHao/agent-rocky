import Foundation
import AppKit

/// Reads `com.apple.dock` user defaults to compute the icon-area rectangle.
/// Pure logic; the testable variant takes any prefs accessor so unit tests
/// don't have to mutate real system preferences.
nonisolated enum DockGeometry {
    /// Horizontal extent occupied by app icons + the screen-Y at which the dock's top sits.
    /// Coordinates are in screen-bottom-origin space (AppKit convention).
    struct IconArea: Equatable, Sendable {
        let x: CGFloat
        let width: CGFloat
        let topY: CGFloat
    }

    /// Production accessor: reads from `UserDefaults(suiteName: "com.apple.dock")`.
    static func iconArea(for screen: NSScreen) -> IconArea {
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        return iconArea(
            screenWidth: screen.frame.width,
            prefsAccessor: { key in prefs?.object(forKey: key) }
        )
    }

    /// Testable variant — accepts any prefs accessor. Pure function.
    static func iconArea(
        screenWidth: CGFloat,
        prefsAccessor: (String) -> Any?
    ) -> IconArea {
        let tileSize: CGFloat = (prefsAccessor("tilesize") as? Double).map { CGFloat($0) } ?? 48
        let slotWidth = tileSize * 1.25

        let persistentApps = (prefsAccessor("persistent-apps") as? [Any])?.count ?? 0
        let persistentOthers = (prefsAccessor("persistent-others") as? [Any])?.count ?? 0
        let showRecents = (prefsAccessor("show-recents") as? Bool) ?? true
        let recents = showRecents
            ? ((prefsAccessor("recent-apps") as? [Any])?.count ?? 0)
            : 0

        let totalIcons = max(persistentApps + persistentOthers + recents, 1)
        let dockWidth = slotWidth * CGFloat(totalIcons)
        let dockX = (screenWidth - dockWidth) / 2
        let dockTopY = tileSize + 16

        return IconArea(x: dockX, width: dockWidth, topY: dockTopY)
    }
}
