import Foundation
import Observation
import QuartzCore

/// Animation state machine for the walking character.
/// Modelled after lil-agents' Bruce/Jazz tunables (spec §7) with a video-time-synced
/// position curve so the body translation lines up with the leg animation.
///
/// Drive from MainActor (we run from a CADisplayLink callback).
@Observable
final class WalkerCharacter {

    // MARK: - State (read/write from main actor)

    /// 0..1 progress across the dock-icon area (left → right).
    var positionProgress: Double = 0.5
    var goingRight: Bool = true
    var isPaused: Bool = true
    var isWalking: Bool = false
    var isFrozen: Bool = false                  // popover open

    /// Wall-time when the current walk started; 0 while paused.
    private(set) var walkStartTime: CFTimeInterval = 0
    /// Wall-time after which the next walk should begin.
    private(set) var pauseEndTime: CFTimeInterval = 1.0

    private var walkStartProgress: Double = 0.5
    private var walkEndProgress: Double = 0.5
    private var walkStartPixel: Double = 0
    private var walkEndPixel: Double = 0
    private(set) var cachedX: CGFloat = 0

    // MARK: - Tunables (in seconds along the walk video timeline; see movementPosition)

    /// Duration during which the character has stood still at the start of the video clip
    /// (legs settle into walk pose). Position contribution = 0 until this time.
    var accelStart: CFTimeInterval = 3.0
    /// End of ease-in (legs at full walking cadence).
    var fullSpeedStart: CFTimeInterval = 3.75
    /// Beginning of ease-out.
    var decelStart: CFTimeInterval = 7.5
    /// End of walk; legs idle for the remainder of the video clip.
    var walkStop: CFTimeInterval = 8.25
    /// Total length of the bundled walk video. character.mov from lil-agents is ≈ 8.55s.
    var videoDuration: CFTimeInterval = 8.55

    /// Random walk distance per cycle, in *pixels* (constant across screen sizes).
    /// 200–325 px feels right at reference scale (display = 96pt height).
    var walkPixelRange: ClosedRange<Double> = 200...325

    var pauseRange: ClosedRange<TimeInterval> = 5.0...12.0

    /// Per-cycle reference width — used to decouple walk amount from current screen width.
    var referencePixelWidth: Double = 500.0

    // MARK: - Tick

    /// Advance state and return the absolute X origin of the character window.
    /// `dockBounds` = (x, width) of dock icon area; `displayWidth` = sprite/window width.
    @discardableResult
    func tick(now: CFTimeInterval, dockBounds: (x: CGFloat, width: CGFloat), displayWidth: CGFloat) -> CGFloat {
        guard !isFrozen else { return cachedX }

        // travel = how far the character can move horizontally without leaving the dock
        let travel = max(Double(dockBounds.width) - Double(displayWidth), 0)

        if isPaused {
            if now >= pauseEndTime {
                startWalk(now: now, travel: travel)
            } else {
                cachedX = computeX(progress: positionProgress, dockX: Double(dockBounds.x), travel: travel)
                return cachedX
            }
        }

        if isWalking {
            let elapsed = now - walkStartTime
            let videoTime = min(elapsed, videoDuration)
            let walkNorm = elapsed >= videoDuration ? 1.0 : movementPosition(at: videoTime)
            let currentPixel = walkStartPixel + (walkEndPixel - walkStartPixel) * walkNorm

            // Convert pixel position back to progress for the current screen
            if travel > 0 {
                positionProgress = min(max(currentPixel / travel, 0), 1)
            }

            if elapsed >= videoDuration {
                walkEndProgress = positionProgress
                enterPause(now: now)
            }
        }

        cachedX = computeX(progress: positionProgress, dockX: Double(dockBounds.x), travel: travel)
        return cachedX
    }

    // MARK: - Position curve (video-time-synced, ported from lil-agents)

    /// Maps a moment in video time to normalized walk progress in [0, 1].
    /// Velocity profile: ease-in (parabolic accel) → linear cruise → ease-out (parabolic decel).
    /// Velocity `v` is calibrated so the total distance over one full clip = 1.0.
    func movementPosition(at videoTime: CFTimeInterval) -> Double {
        let dIn = fullSpeedStart - accelStart
        let dLin = decelStart - fullSpeedStart
        let dOut = walkStop - decelStart
        let v = 1.0 / (dIn / 2.0 + dLin + dOut / 2.0)

        if videoTime <= accelStart {
            return 0
        } else if videoTime <= fullSpeedStart {
            let t = videoTime - accelStart
            return v * t * t / (2.0 * dIn)
        } else if videoTime <= decelStart {
            let easeInDist = v * dIn / 2.0
            let t = videoTime - fullSpeedStart
            return easeInDist + v * t
        } else if videoTime <= walkStop {
            let easeInDist = v * dIn / 2.0
            let linearDist = v * dLin
            let t = videoTime - decelStart
            return easeInDist + linearDist + v * (t - t * t / (2.0 * dOut))
        } else {
            return 1.0
        }
    }

    // MARK: - Lifecycle transitions

    private func startWalk(now: CFTimeInterval, travel: Double) {
        isPaused = false
        isWalking = true
        walkStartTime = now

        // Edge-aware direction biasing
        if positionProgress > 0.85 {
            goingRight = false
        } else if positionProgress < 0.15 {
            goingRight = true
        } else {
            goingRight = Bool.random()
        }

        walkStartProgress = positionProgress
        let walkPixels = Double.random(in: walkPixelRange)
        let walkAmount = travel > 0 ? walkPixels / travel : 0.3
        walkEndProgress = goingRight
            ? min(walkStartProgress + walkAmount, 1.0)
            : max(walkStartProgress - walkAmount, 0.0)

        walkStartPixel = walkStartProgress * travel
        walkEndPixel = walkEndProgress * travel
    }

    private func enterPause(now: CFTimeInterval) {
        isWalking = false
        isPaused = true
        pauseEndTime = now + Double.random(in: pauseRange)
    }

    private func computeX(progress: Double, dockX: Double, travel: Double) -> CGFloat {
        CGFloat(dockX + travel * progress)
    }
}
