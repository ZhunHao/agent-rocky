import AppKit
import QuartzCore

/// CADisplayLink-based animation tick driver. macOS 14+.
/// On macOS, CADisplayLink is constructed via `NSScreen.displayLink(target:selector:)`
/// (macOS 14+) — the iOS-style `init(target:selector:)` is unavailable.
@MainActor
final class TickDriver {
    private var displayLink: CADisplayLink?
    private var tick: ((CFTimeInterval) -> Void)?

    func start(_ tick: @escaping @MainActor (CFTimeInterval) -> Void) {
        stop()
        self.tick = tick
        guard let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(handleTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        tick = nil
    }

    @objc private func handleTick(_ link: CADisplayLink) {
        tick?(CACurrentMediaTime())
    }

    deinit {
        // Display link is automatically invalidated when our `target = self` deallocates,
        // so this empty deinit is fine.
    }
}
