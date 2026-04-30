import AppKit
import QuartzCore
import SwiftUI

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
    private var localMouseMoveMonitor: Any?
    private var localMouseDownMonitor: Any?

    // State for tick-loop change detection
    private var lastShouldShow: Bool = false
    private var lastGoingRight: Bool = true
    private var isHovering: Bool = false

    func start() {
        installOverlay()
        screenObserver.onChange = { [weak self] in self?.installOverlay() }
        screenObserver.start()

        installPopoverWiring()
        installMouseMonitor()
        installRealSession()
        installOnboardingIfNeeded()

        tickDriver.start { [weak self] now in self?.tick(now: now) }
    }

    func shutdown() {
        tickDriver.stop()
        screenObserver.stop()
        if let m = globalMouseMonitor      { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
        if let m = localMouseMoveMonitor   { NSEvent.removeMonitor(m); localMouseMoveMonitor = nil }
        if let m = localMouseDownMonitor   { NSEvent.removeMonitor(m); localMouseDownMonitor = nil }
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
            guard let self else { return }
            self.walker.addFreeze(.popover, now: CACurrentMediaTime())
        }
        popover.onHide = { [weak self] in
            guard let self else { return }
            self.walker.removeFreeze(.popover, now: CACurrentMediaTime())
        }
        popover.onCopyLast = { [weak self] in
            guard let last = self?.popover.viewModel.transcript.last(where: { $0.role == .assistant }) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(last.text, forType: .string)
        }
    }

    private func installRealSession() {
        Task { @MainActor in
            do {
                let persona = try PersonaPromptBuilder.load()
                let adapter = ClaudeCLIAdapter(personaPrompt: persona)
                self.popover.viewModel.attach(adapter)
                try await adapter.start()
            } catch {
                self.popover.viewModel.appendSystem("Setup failed: \(error)")
            }
        }
    }

    // MARK: - Onboarding bubble

    private static let onboardingKey = "hasCompletedOnboarding"
    private var onboardingBubble: NSPanel?

    private func installOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.onboardingKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showOnboardingBubble()
        }
    }

    private func showOnboardingBubble() {
        guard let win = overlayWindow, onboardingBubble == nil else { return }
        let bubble = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.level = win.level
        bubble.collectionBehavior = [.moveToActiveSpace, .stationary]
        bubble.ignoresMouseEvents = true

        let host = NSHostingController(rootView: OnboardingBubbleView())
        bubble.contentViewController = host

        let centerX = win.frame.midX
        let topY = win.frame.maxY + 8
        bubble.setFrameOrigin(NSPoint(x: centerX - 70, y: topY))
        bubble.orderFrontRegardless()
        onboardingBubble = bubble
    }

    private func dismissOnboardingBubbleIfShowing() {
        guard onboardingBubble != nil else { return }
        onboardingBubble?.orderOut(nil)
        onboardingBubble = nil
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    // MARK: - Click-through

    private func installMouseMonitor() {
        // mouseMoved fires both globally (when cursor is outside our app's windows)
        // AND locally (when cursor is over our overlay window). Need both to handle
        // hover-leave when cursor moves off Rocky onto another app's window.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.updateHover()
            return event
        }

        // Click on Rocky → toggle popover. Only fire when the click landed in the
        // overlay window (event.window === overlayWindow). Clicks on the popover
        // itself or other app windows should pass through unhandled.
        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            guard let overlay = self.overlayWindow, event.window === overlay else { return event }
            return self.handleOverlayClick() ? nil : event
        }
    }

    private func updateHover() {
        guard let win = overlayWindow, let mask = hitMaskImage, win.isVisible else { return }
        let mouseScreen = NSEvent.mouseLocation
        let local = NSPoint(
            x: mouseScreen.x - win.frame.origin.x,
            y: mouseScreen.y - win.frame.origin.y
        )
        let inBounds = local.x >= 0 && local.y >= 0
            && local.x < win.frame.width && local.y < win.frame.height

        let imgSize = mask.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        let imgX = local.x * imgSize.width / win.frame.width
        let imgY = local.y * imgSize.height / win.frame.height

        let isOverRocky = inBounds && HitTesting.isOpaque(
            at: NSPoint(x: imgX, y: imgY),
            in: mask,
            threshold: 0.1
        )

        // Click-through: cursor over Rocky → catch clicks; otherwise pass through
        win.ignoresMouseEvents = !isOverRocky

        // Hover-freeze
        if isOverRocky != isHovering {
            isHovering = isOverRocky
            let now = CACurrentMediaTime()
            if isOverRocky {
                walker.addFreeze(.hover, now: now)
            } else {
                walker.removeFreeze(.hover, now: now)
            }
        }
    }

    private func handleOverlayClick() -> Bool {
        guard let win = overlayWindow else { return false }
        dismissOnboardingBubbleIfShowing()
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

        // Sync video to walking state. When frozen (hover/popover), pause the video too —
        // not just the position update. Otherwise legs keep moving while body is still.
        let videoIsWalking = walker.isWalking && !walker.isFrozen
        let elapsed = videoIsWalking ? (now - walker.walkStartTime) : 0
        win.syncVideoTime(toWalkElapsed: elapsed, isWalking: videoIsWalking)

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
