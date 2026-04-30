import AppKit
import QuartzCore

/// Top-level coordinator. Wires together overlay, popover, and agent layers.
/// M1: walking-sprite overlay + WalkerCharacter + tick loop with video-time-synced motion.
@MainActor
final class AppController {

    private static let displayHeight: CGFloat = 96

    private var overlayWindow: CharacterOverlayWindow?
    private let walker = WalkerCharacter()
    private let tickDriver = TickDriver()
    private let screenObserver = ScreenObserver()
    private var lastShouldShow: Bool = false
    private var lastGoingRight: Bool = true

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
        let bottomPadding = Self.displayHeight * 0.15
        let frame = NSRect(
            x: geometry.x,
            y: geometry.topY - bottomPadding,
            width: Self.displayHeight,                  // window is sprite-sized, not dock-sized
            height: Self.displayHeight
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

        // Fullscreen-hide
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
        let originX = walker.tick(
            now: now,
            dockBounds: dockBounds,
            displayWidth: Self.displayHeight
        )

        // Sync video time: when walking, ensure player is playing in step with
        // walker.walkStartTime. When pausing, freeze video at frame 1.
        let elapsed = walker.isWalking ? (now - walker.walkStartTime) : 0
        win.syncVideoTime(toWalkElapsed: elapsed, isWalking: walker.isWalking)

        // Mirror sprite when direction changes
        if walker.goingRight != lastGoingRight {
            win.setFacingRight(walker.goingRight)
            lastGoingRight = walker.goingRight
        }

        let bottomPadding = Self.displayHeight * 0.15
        var frame = win.frame
        frame.origin.x = originX
        frame.origin.y = geometry.topY - bottomPadding
        win.setFrame(frame, display: false)
    }
}
