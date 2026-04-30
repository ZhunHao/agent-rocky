import Testing
import QuartzCore
@testable import AgentRocky

@MainActor
struct WalkerCharacterTests {

    @Test("Initial phase is pausing")
    func initial_state_is_pausing() {
        let walker = WalkerCharacter()
        #expect(walker.phase == .pausing)
    }

    @Test("Freeze halts position updates")
    func freeze_halts_position_updates() {
        let walker = WalkerCharacter()
        walker.positionProgress = 0.5
        let xBefore = walker.tick(now: 0, dockBounds: (x: 100, width: 600))

        walker.isFrozen = true
        let xAfter1 = walker.tick(now: 1.0, dockBounds: (x: 100, width: 600))
        let xAfter2 = walker.tick(now: 2.0, dockBounds: (x: 100, width: 600))

        #expect(xBefore == xAfter1)
        #expect(xAfter1 == xAfter2)
    }

    @Test("Position progress stays within [0, 1] over many ticks")
    func position_progress_stays_within_bounds() {
        let walker = WalkerCharacter()
        for i in 0..<600 {
            _ = walker.tick(now: Double(i) * 0.1, dockBounds: (x: 0, width: 1000))
            #expect(walker.positionProgress >= 0)
            #expect(walker.positionProgress <= 1)
        }
    }

    @Test("Position X maps progress*width into screen coords")
    func position_x_maps_to_screen_coords() {
        let walker = WalkerCharacter()
        walker.positionProgress = 0.5
        let x = walker.tick(now: 0, dockBounds: (x: 200, width: 800))
        // 200 + 0.5 * 800 = 600
        #expect(abs(x - 600) < 0.5)
    }

    @Test("Phase transitions out of pausing once pauseEndTime elapses")
    func phase_transitions_through_walk_cycle() {
        let walker = WalkerCharacter()
        walker.pauseEndTime = 0
        walker.phaseStartTime = 0
        walker.phase = .pausing
        _ = walker.tick(now: 0.1, dockBounds: (x: 0, width: 1000))
        #expect(walker.phase == .accelerating)
    }
}
