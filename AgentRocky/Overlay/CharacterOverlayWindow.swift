import AppKit
import AVFoundation

/// Borderless transparent NSWindow that hosts the character's AVPlayerLayer.
/// Spec §7.
@MainActor
final class CharacterOverlayWindow: NSWindow {

    private(set) var queuePlayer: AVQueuePlayer!
    private var playerLooper: AVPlayerLooper!
    private var playerLayer: AVPlayerLayer!

    init(initialFrame: NSRect, videoURL: URL) {
        super.init(
            contentRect: initialFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        collectionBehavior = [.moveToActiveSpace, .stationary]

        let asset = AVURLAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer()
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.volume = 0
        queuePlayer = player

        let hostView = NSView(frame: NSRect(origin: .zero, size: initialFrame.size))
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor

        let layer = AVPlayerLayer(player: player)
        layer.frame = hostView.bounds
        layer.videoGravity = .resizeAspect
        hostView.layer?.addSublayer(layer)
        playerLayer = layer

        contentView = hostView
    }

    func play() {
        queuePlayer.play()
    }

    func pauseAtFirstFrame() {
        queuePlayer.pause()
        queuePlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Sync video time with the WalkerCharacter walk state.
    /// Called each tick — ensures the legs animation lines up with the body translation.
    func syncVideoTime(toWalkElapsed elapsed: CFTimeInterval, isWalking: Bool) {
        if isWalking {
            if queuePlayer.timeControlStatus != .playing {
                let cm = CMTime(seconds: max(0, elapsed), preferredTimescale: 600)
                queuePlayer.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
                queuePlayer.play()
            }
        } else {
            if queuePlayer.timeControlStatus == .playing {
                queuePlayer.pause()
                queuePlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    /// Mirror the sprite horizontally when going left (the bundled video shows the
    /// character facing right; we flip the layer to face left).
    func setFacingRight(_ rightFacing: Bool) {
        playerLayer.transform = rightFacing
            ? CATransform3DIdentity
            : CATransform3DMakeScale(-1, 1, 1)
    }

    /// Resize layer when window changes size (called on dock-pref changes).
    func updateLayerFrame() {
        playerLayer.frame = (contentView?.bounds) ?? .zero
    }
}
