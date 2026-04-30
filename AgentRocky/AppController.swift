import AppKit

/// Top-level coordinator. Wires together overlay, popover, and agent layers.
/// In M0 it's a stub; subsequent milestones flesh it out.
@MainActor
final class AppController {
    func start() {
        // M1 will install: WalkerCharacter, CharacterOverlayWindow, ScreenObserver, TickDriver
        // M2 will install: CharacterPopover, ChatViewModel
        // M3 will install: ProviderDetector, ClaudeCLIAdapter
    }

    func shutdown() {
        // M1+: stop tick driver, terminate sessions
    }
}
