import Foundation
import Observation
import QuartzCore

/// Pure animation state machine. No AppKit / NSWindow dependencies — driven by `tick(now:dockBounds:)`.
/// Modelled after lil-agents' Bruce/Jazz tunables (spec §7).
///
/// Drive this from the main actor (we run it from a CADisplayLink callback).
@Observable
final class WalkerCharacter {

    enum Direction: Sendable, Equatable {
        case left, right
    }

    enum Phase: Sendable, Equatable {
        case pausing, accelerating, cruising, decelerating
    }

    // MARK: - State (read/write from main actor)

    var positionProgress: Double = 0.5         // 0..1 across dock width
    var direction: Direction = .right
    var phase: Phase = .pausing
    var pauseEndTime: CFTimeInterval = 1.0
    var phaseStartTime: CFTimeInterval = 0
    var isFrozen: Bool = false
    private(set) var cachedX: CGFloat = 0
    private var walkStartProgress: Double = 0.5
    private var currentWalkAmount: Double = 0.5

    // MARK: - Tunables

    var accelDuration: TimeInterval = 0.75
    var cruiseSpeed: Double = 0.06             // dock-fractions per second at full speed
    var decelDuration: TimeInterval = 0.5
    var pauseRange: ClosedRange<TimeInterval> = 0.5...3.0
    var walkAmountRange: ClosedRange<Double> = 0.4...0.65

    // MARK: - Tick

    /// Advance state by current time and return the absolute X origin in screen coords.
    /// `dockBounds` = (x, width) of the dock icon area.
    @discardableResult
    func tick(now: CFTimeInterval, dockBounds: (x: CGFloat, width: CGFloat)) -> CGFloat {
        guard !isFrozen else { return cachedX }

        let frameDelta = 1.0 / 60.0   // assume 60Hz; close enough for v1

        switch phase {
        case .pausing:
            if now >= pauseEndTime {
                beginAccelerating(now: now)
            }
        case .accelerating:
            let elapsed = now - phaseStartTime
            if elapsed >= accelDuration {
                phase = .cruising
                phaseStartTime = now
            } else {
                let fraction = elapsed / accelDuration
                advance(by: cruiseSpeed * fraction * frameDelta)
            }
        case .cruising:
            advance(by: cruiseSpeed * frameDelta)
            let traveled = abs(positionProgress - walkStartProgress)
            if traveled >= currentWalkAmount {
                phase = .decelerating
                phaseStartTime = now
            }
        case .decelerating:
            let elapsed = now - phaseStartTime
            if elapsed >= decelDuration {
                beginPausing(now: now)
            } else {
                let remaining = 1.0 - (elapsed / decelDuration)
                advance(by: cruiseSpeed * remaining * frameDelta)
            }
        }

        if positionProgress >= 1.0 {
            positionProgress = 1.0
            direction = .left
            beginPausing(now: now)
        } else if positionProgress <= 0.0 {
            positionProgress = 0.0
            direction = .right
            beginPausing(now: now)
        }

        cachedX = dockBounds.x + CGFloat(positionProgress) * dockBounds.width
        return cachedX
    }

    // MARK: - State transitions

    private func beginAccelerating(now: CFTimeInterval) {
        phase = .accelerating
        phaseStartTime = now
        walkStartProgress = positionProgress
        currentWalkAmount = Double.random(in: walkAmountRange)
    }

    private func beginPausing(now: CFTimeInterval) {
        phase = .pausing
        phaseStartTime = now
        pauseEndTime = now + Double.random(in: pauseRange)
    }

    private func advance(by amount: Double) {
        switch direction {
        case .right: positionProgress += amount
        case .left:  positionProgress -= amount
        }
    }
}
