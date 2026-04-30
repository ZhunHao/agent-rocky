import AppKit
import QuartzCore

/// Top-level coordinator. Wires together overlay, popover, and (in M3+) agent layers.
@MainActor
final class AppController {

    private static let displayHeight: CGFloat = 96

    // Overlay layer
    private var overlayWindow: CharacterOverlayWindow?
    private let walker = WalkerCharacter()
    private let tickDriver = TickDriver()
    private let screenObserver = ScreenObserver()

    // Popover layer
    private let popover = CharacterPopover()

    // Click-through hit-testing
    private var hitMaskImage: NSImage?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    // State for tick-loop change detection
    private var lastShouldShow: Bool = false
    private var lastGoingRight: Bool = true

    func start() {
        installOverlay()
        screenObserver.onChange = { [weak self] in self?.installOverlay() }
        screenObserver.start()

        installPopoverWiring()
        installMouseMonitor()
        installMockSession()

        tickDriver.start { [weak self] now in self?.tick(now: now) }
    }

    func shutdown() {
        tickDriver.stop()
        screenObserver.stop()
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
        if let m = localMouseMonitor  { NSEvent.removeMonitor(m); localMouseMonitor = nil }
        popover.hide()
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    // MARK: - Overlay setup

    private func installOverlay() {
        guard let screen = NSScreen.main else { return }
        guard let videoURL = Bundle.main.url(forResource: "character", withExtension: "mov") else {
            assertionFailure("character.mov missing from bundle")
            return
        }
        if hitMaskImage == nil {
            hitMaskImage = HitTesting.extractFirstFrame(from: videoURL)
        }

        let geometry = DockGeometry.iconArea(for: screen)
        let bottomPadding = Self.displayHeight * 0.15
        let frame = NSRect(
            x: geometry.x,
            y: geometry.topY - bottomPadding,
            width: Self.displayHeight,
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

    // MARK: - Popover wiring

    private func installPopoverWiring() {
        popover.onShow = { [weak self] in
            self?.walker.isFrozen = true
            self?.overlayWindow?.pauseAtFirstFrame()
        }
        popover.onHide = { [weak self] in
            self?.walker.isFrozen = false
            self?.overlayWindow?.play()
        }
        popover.onCopyLast = { [weak self] in
            guard let last = self?.popover.viewModel.transcript.last(where: { $0.role == .assistant }) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(last.text, forType: .string)
        }
    }

    private func installMockSession() {
        let session = MockAgentSession()
        popover.viewModel.attach(session)
        Task { try? await session.start() }
    }

    // MARK: - Click-through

    private func installMouseMonitor() {
        // Track mouse movement globally to toggle ignoresMouseEvents per-pixel
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in self?.updateClickThrough() }
        }
        // Also handle clicks on the overlay window (when ignoresMouseEvents == false)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalClick(event) ? nil : event
        }
    }

    private func updateClickThrough() {
        guard let win = overlayWindow, let mask = hitMaskImage, win.isVisible else { return }
        let mouseScreen = NSEvent.mouseLocation
        // Convert to window-local coords
        let local = NSPoint(
            x: mouseScreen.x - win.frame.origin.x,
            y: mouseScreen.y - win.frame.origin.y
        )
        let inBounds = local.x >= 0 && local.y >= 0
            && local.x < win.frame.width && local.y < win.frame.height

        // Map window-local to image-local. The hit mask image is the entire
        // first frame; AVPlayerLayer scales it via .resizeAspect to the window.
        // Approximate: scale linearly window→image space.
        let imgSize = mask.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        let imgX = local.x * imgSize.width / win.frame.width
        let imgY = local.y * imgSize.height / win.frame.height

        let isOverRocky = inBounds && HitTesting.isOpaque(
            at: NSPoint(x: imgX, y: imgY),
            in: mask,
            threshold: 0.1
        )
        win.ignoresMouseEvents = !isOverRocky
    }

    private func handleLocalClick(_ event: NSEvent) -> Bool {
        guard let win = overlayWindow, !win.ignoresMouseEvents else { return false }
        let rockyCenterX = win.frame.midX
        let rockyTopY = win.frame.maxY
        if popover.isVisible {
            popover.hide()
        } else {
            popover.show(anchoredAt: rockyCenterX, rockyTopY: rockyTopY)
        }
        return true
    }

    // MARK: - Tick

    private func tick(now: CFTimeInterval) {
        guard let win = overlayWindow, let screen = NSScreen.main else { return }

        let shouldShow = (screen.visibleFrame != screen.frame)
        if shouldShow != lastShouldShow {
            if shouldShow {
                win.orderFrontRegardless()
                win.play()
            } else {
                win.orderOut(nil)
                win.pauseAtFirstFrame()
                popover.hide()
            }
            lastShouldShow = shouldShow
        }
        guard shouldShow else { return }

        let geometry = DockGeometry.iconArea(for: screen)
        let dockBounds = (x: geometry.x, width: geometry.width)
        let originX = walker.tick(now: now, dockBounds: dockBounds, displayWidth: Self.displayHeight)

        let elapsed = walker.isWalking ? (now - walker.walkStartTime) : 0
        win.syncVideoTime(toWalkElapsed: elapsed, isWalking: walker.isWalking)

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
