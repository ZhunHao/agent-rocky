import AppKit

/// Top-level coordinator. Wires together overlay, popover, and agent layers.
/// M1: walking-sprite overlay window + WalkerCharacter + tick loop.
@MainActor
final class AppController {

    private var overlayWindow: CharacterOverlayWindow?
    private let walker = WalkerCharacter()
    private let tickDriver = TickDriver()
    private let screenObserver = ScreenObserver()
    private var lastShouldShow: Bool = false

    func start() {
        installOverlay()
        screenObserver.onChange = { [weak self] in
            self?.installOverlay()
        }
        screenObserver.start()

        tickDriver.start { [weak self] now in
            self?.tick(now: now)
        }
    }

    func shutdown() {
        tickDriver.stop()
        screenObserver.stop()
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    // MARK: - Setup

    private func installOverlay() {
        guard let screen = NSScreen.main else { return }
        guard let videoURL = Bundle.main.url(forResource: "character", withExtension: "mov") else {
            assertionFailure("character.mov missing from bundle")
            return
        }

        let geometry = DockGeometry.iconArea(for: screen)
        let frame = NSRect(
            x: geometry.x,
            y: geometry.topY,
            width: geometry.width,
            height: 96
        )

        if overlayWindow == nil {
            let win = CharacterOverlayWindow(initialFrame: frame, videoURL: videoURL)
            win.orderFrontRegardless()
            win.play()
            overlayWindow = win
        } else {
            overlayWindow?.setFrame(frame, display: true)
            overlayWindow?.updateLayerFrame()
        }
    }

    // MARK: - Tick

    private func tick(now: CFTimeInterval) {
        guard let win = overlayWindow, let screen = NSScreen.main else { return }

        // Fullscreen-hide: when an app is fullscreen, the dock isn't reserving space.
        let shouldShow = (screen.visibleFrame != screen.frame)
        if shouldShow != lastShouldShow {
            if shouldShow {
                win.orderFrontRegardless()
                win.play()
            } else {
                win.orderOut(nil)
                win.pauseAtFirstFrame()
            }
            lastShouldShow = shouldShow
        }
        guard shouldShow else { return }

        let geometry = DockGeometry.iconArea(for: screen)
        let dockBounds = (x: geometry.x, width: geometry.width)
        let centerX = walker.tick(now: now, dockBounds: dockBounds)

        var frame = win.frame
        frame.origin.x = centerX - frame.width / 2
        frame.origin.y = geometry.topY
        win.setFrame(frame, display: false)
    }
}
