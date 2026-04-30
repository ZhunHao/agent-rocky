import Testing
import QuartzCore
@testable import AgentRocky

@MainActor
struct WalkerCharacterTests {

    @Test("Initial state is paused")
    func initial_state_is_paused() {
        let walker = WalkerCharacter()
        #expect(walker.isPaused)
        #expect(!walker.isWalking)
        #expect(!walker.isFrozen)
    }

    @Test("Freeze halts position updates")
    func freeze_halts_position_updates() {
        let walker = WalkerCharacter()
        walker.positionProgress = 0.5
        let xBefore = walker.tick(now: 0, dockBounds: (x: 100, width: 600), displayWidth: 96)

        walker.addFreeze(.popover, now: 0)
        let xAfter1 = walker.tick(now: 1.0, dockBounds: (x: 100, width: 600), displayWidth: 96)
        let xAfter2 = walker.tick(now: 2.0, dockBounds: (x: 100, width: 600), displayWidth: 96)

        #expect(xBefore == xAfter1)
        #expect(xAfter1 == xAfter2)
    }

    @Test("Multi-source freeze: hover + popover, both required to unfreeze")
    func multi_source_freeze() {
        let walker = WalkerCharacter()
        walker.addFreeze(.hover, now: 0)
        #expect(walker.isFrozen)
        walker.addFreeze(.popover, now: 0)
        #expect(walker.isFrozen)
        walker.removeFreeze(.hover, now: 1)
        #expect(walker.isFrozen)             // popover still freezing
        walker.removeFreeze(.popover, now: 2)
        #expect(!walker.isFrozen)
    }

    @Test("Unfreezing shifts walkStartTime and pauseEndTime by the frozen duration")
    func freeze_shifts_time_state() {
        let walker = WalkerCharacter()
        let initialPauseEnd = walker.pauseEndTime          // = 1.0 from default init
        walker.addFreeze(.hover, now: 1)
        // 10 seconds frozen
        walker.removeFreeze(.hover, now: 11)
        // pauseEndTime should have shifted forward by frozen duration (10s)
        #expect(walker.pauseEndTime == initialPauseEnd + 10)
    }

    @Test("Position progress stays within [0, 1]")
    func position_progress_stays_within_bounds() {
        let walker = WalkerCharacter()
        for i in 0..<600 {
            _ = walker.tick(
                now: Double(i) * 0.1,
                dockBounds: (x: 0, width: 1000),
                displayWidth: 96
            )
            #expect(walker.positionProgress >= 0)
            #expect(walker.positionProgress <= 1)
        }
    }

    @Test("Position X = dockX + travel * progress")
    func position_x_maps_to_screen_coords() {
        let walker = WalkerCharacter()
        walker.positionProgress = 0.5
        let x = walker.tick(now: 0, dockBounds: (x: 200, width: 800), displayWidth: 96)
        // travel = 800 - 96 = 704, x = 200 + 0.5 * 704 = 552
        #expect(abs(x - 552) < 0.5)
    }

    @Test("movementPosition: 0 before accelStart, 1 after walkStop")
    func movement_position_clamps_to_zero_and_one() {
        let walker = WalkerCharacter()
        #expect(walker.movementPosition(at: 0) == 0)
        #expect(walker.movementPosition(at: walker.accelStart) == 0)
        #expect(walker.movementPosition(at: walker.walkStop + 0.5) == 1)
    }

    @Test("movementPosition is monotonically non-decreasing")
    func movement_position_monotonic() {
        let walker = WalkerCharacter()
        var prev = -1.0
        var t: CFTimeInterval = 0
        while t <= walker.videoDuration {
            let v = walker.movementPosition(at: t)
            #expect(v >= prev)
            prev = v
            t += 0.05
        }
    }

    @Test("Pause exits to walking once pauseEndTime elapses")
    func pause_exits_after_pause_end_time() {
        let walker = WalkerCharacter()
        walker.isPaused = true
        walker.isWalking = false
        // tick once with now far after the initial pauseEndTime to trigger startWalk
        _ = walker.tick(now: 999, dockBounds: (x: 0, width: 1000), displayWidth: 96)
        #expect(walker.isWalking)
        #expect(!walker.isPaused)
    }
}
