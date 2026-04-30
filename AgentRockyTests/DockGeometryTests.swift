import Testing
@testable import AgentRocky

struct DockGeometryTests {

    @Test("Centers dock and computes width from default tilesize and icon counts")
    func iconArea_with_default_tilesize_centers_dock() {
        let mockPrefs: [String: Any] = [
            "tilesize": 48.0,
            "persistent-apps": [Any](repeating: 0, count: 5),
            "persistent-others": [Any](repeating: 0, count: 3),
            "show-recents": true,
            "recent-apps": [Any](repeating: 0, count: 2),
        ]

        let result = DockGeometry.iconArea(
            screenWidth: 1920,
            prefsAccessor: { key in mockPrefs[key] }
        )

        // tileSize=48, slotWidth=48*1.25=60, totalIcons=5+3+2=10, dockWidth=600
        #expect(abs(result.width - 600) < 0.001)
        // dockX = (1920 - 600) / 2 = 660
        #expect(abs(result.x - 660) < 0.001)
        // dockTopY = tileSize + 16 = 64
        #expect(abs(result.topY - 64) < 0.001)
    }

    @Test("Recents excluded when show-recents is false")
    func iconArea_falls_back_when_recents_disabled() {
        let mockPrefs: [String: Any] = [
            "tilesize": 48.0,
            "persistent-apps": [Any](repeating: 0, count: 5),
            "persistent-others": [Any](repeating: 0, count: 3),
            "show-recents": false,
            "recent-apps": [Any](repeating: 0, count: 2),  // ignored
        ]

        let result = DockGeometry.iconArea(
            screenWidth: 1920,
            prefsAccessor: { key in mockPrefs[key] }
        )
        // totalIcons=5+3=8, dockWidth=480
        #expect(abs(result.width - 480) < 0.001)
    }

    @Test("Clamps to minimum one icon when no apps")
    func iconArea_clamps_to_minimum_one_icon_when_no_apps() {
        let mockPrefs: [String: Any] = ["tilesize": 48.0]
        let result = DockGeometry.iconArea(
            screenWidth: 1920,
            prefsAccessor: { key in mockPrefs[key] }
        )
        // totalIcons clamped to 1, dockWidth=60
        #expect(abs(result.width - 60) < 0.001)
    }
}
