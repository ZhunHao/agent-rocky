import AppKit
import SwiftUI

/// Borderless non-activating panel anchored above the character's current X.
@MainActor
final class CharacterPopover {
    var onShow: (() -> Void)?
    var onHide: (() -> Void)?
    var onCopyLast: (() -> Void)?

    let viewModel: ChatViewModel = ChatViewModel()

    private(set) var isVisible: Bool = false
    private var panel: NSPanel?

    func show(anchoredAt rockyCenterX: CGFloat, rockyTopY: CGFloat) {
        if panel == nil { buildPanel() }
        guard let panel else { return }

        let popoverWidth: CGFloat = 360
        let popoverHeight: CGFloat = 480
        let gap: CGFloat = 12

        // Clamp X so the popover stays on-screen
        let originXRaw = rockyCenterX - popoverWidth / 2
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = min(
            max(originXRaw, screenFrame.minX + 8),
            screenFrame.maxX - popoverWidth - 8
        )
        let originY = rockyTopY + gap

        panel.setContentSize(NSSize(width: popoverWidth, height: popoverHeight))
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        panel.orderFrontRegardless()
        isVisible = true
        onShow?()
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        onHide?()
    }

    private func buildPanel() {
        let view = TerminalView(
            viewModel: viewModel,
            onCopyLast: { [weak self] in self?.onCopyLast?() },
            onClose: { [weak self] in self?.hide() }
        )
        let host = NSHostingController(rootView: view)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .nonactivatingPanel, .resizable, .closable],
            backing: .buffered,
            defer: false
        )
        p.contentViewController = host
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = false
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        p.collectionBehavior = [.moveToActiveSpace, .stationary]
        p.title = "Rocky"

        // Hook the close button to call hide() so onHide fires
        p.standardWindowButton(.closeButton)?.target = self
        p.standardWindowButton(.closeButton)?.action = #selector(closeFromButton)

        panel = p
    }

    @objc private func closeFromButton() { hide() }
}
