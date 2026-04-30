import AppKit
import SwiftUI

/// Borderless NSWindow that can become key + main. Required for SwiftUI TextField
/// to render its focus ring and blinking caret reliably. Trade-off vs. NSPanel
/// `.nonactivatingPanel`: clicking the popover activates AgentRocky as the
/// frontmost app. Reference (lil-agents) uses the same pattern.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Borderless rounded window anchored above the character's current X.
@MainActor
final class CharacterPopover {
    var onShow: (() -> Void)?
    var onHide: (() -> Void)?
    var onCopyLast: (() -> Void)?

    let viewModel: ChatViewModel = ChatViewModel()

    private(set) var isVisible: Bool = false
    private var window: NSWindow?

    func show(anchoredAt rockyCenterX: CGFloat, rockyTopY: CGFloat) {
        if window == nil { buildWindow() }
        guard let window else { return }

        let popoverWidth: CGFloat = 360
        let popoverHeight: CGFloat = 480
        let gap: CGFloat = 12

        let originXRaw = rockyCenterX - popoverWidth / 2
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = min(
            max(originXRaw, screenFrame.minX + 8),
            screenFrame.maxX - popoverWidth - 8
        )
        let originY = rockyTopY + gap

        window.setContentSize(NSSize(width: popoverWidth, height: popoverHeight))
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true

        // SwiftUI's @FocusState fires before the window is fully key, so the
        // focus ring + caret don't paint reliably. Mirror the reference: walk
        // the view hierarchy and explicitly makeFirstResponder on the input
        // field once layout settles. Done on the next runloop tick so the
        // NSHostingController has finished laying out the SwiftUI tree.
        DispatchQueue.main.async { [weak window] in
            guard let window, let cv = window.contentView else { return }
            if let field = Self.findEditableTextField(in: cv) {
                window.makeFirstResponder(field)
            }
        }
        onShow?()
    }

    /// Walk the view hierarchy looking for an editable NSTextField (the underlying
    /// Cocoa view for SwiftUI's TextField). NSTextView is also matched because
    /// `axis: .vertical` TextFields back into NSTextView on macOS.
    private static func findEditableTextField(in view: NSView) -> NSResponder? {
        if let tf = view as? NSTextField, tf.isEditable { return tf }
        if let tv = view as? NSTextView, tv.isEditable { return tv }
        for sub in view.subviews {
            if let found = findEditableTextField(in: sub) { return found }
        }
        return nil
    }

    func hide() {
        window?.orderOut(nil)
        isVisible = false
        onHide?()
    }

    private func buildWindow() {
        let view = TerminalView(
            viewModel: viewModel,
            onCopyLast: { [weak self] in self?.onCopyLast?() },
            onClose: { [weak self] in self?.hide() }
        )
        let host = NSHostingController(rootView: view)

        let win = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        win.contentViewController = host
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        win.collectionBehavior = [.moveToActiveSpace, .stationary]
        win.isMovableByWindowBackground = true
        win.hasShadow = true
        win.isOpaque = false
        win.backgroundColor = .clear

        window = win
    }
}
