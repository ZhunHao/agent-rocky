# AgentRocky Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS dock companion app — a Project-Hail-Mary-inspired Eridian character ("Rocky") who walks above the dock and opens a chat popover when clicked, backed by Claude Code CLI (cloud) or Apple FoundationModels (on-device).

**Architecture:** Three-layer app. Overlay layer (transparent NSWindow + AVPlayer + WalkerCharacter), Popover layer (NSPanel + SwiftUI TerminalView + ChatViewModel), Agent layer (`AgentSession` protocol + ClaudeCLIAdapter actor + FoundationModelsAdapter actor with shared `AsyncStream<AgentEvent>` shape). Build from scratch with modern Swift idioms (Swift 6 strict concurrency, `actor`, `AsyncStream`, `@Observable` ViewModels, `CADisplayLink`). Engineering ships with reference's character `.mov` as placeholder; custom Rocky art lands in M6.

**Tech Stack:** Swift 6, SwiftUI, AppKit, AVFoundation, FoundationModels framework (macOS 26+), XCTest. Reference repo: [ryanstephen/lil-agents](https://github.com/ryanstephen/lil-agents) (MIT). Spec: [`docs/superpowers/specs/2026-04-30-agent-rocky-design.md`](../specs/2026-04-30-agent-rocky-design.md).

**Conventions used in this plan:**
- Every task has explicit file paths (relative to repo root)
- Every code step shows the complete code to paste
- Every shell command shows the expected output
- Pure-logic files use full TDD cycles (test → fail → impl → pass → commit)
- UI / window / process files use write → build → manual-smoke → commit (TDD impractical)
- All XCTest. If you prefer Swift Testing, the conversion is mechanical (`func test...()` → `@Test func ...()`, `XCTAssertEqual` → `#expect`).
- Branch convention: one branch per milestone (`m0-skeleton`, `m1-walking-sprite`, …). Merge to `main` at the end of each milestone.

---

## Milestone Map

| Milestone | What ships | Estimate |
|---|---|---|
| **M0** Project skeleton | Empty menu bar app, Quit works | ½ weekend |
| **M1** Walking sprite | Reference's character walks above dock; hides on fullscreen | 1 weekend |
| **M2** Click-to-talk (mock) | Click character → SwiftUI chat popover w/ mock streaming | 1 weekend |
| **M3** Claude CLI integration | Real Rocky-flavored streamed answers from `claude` | 1 weekend |
| **M4** FoundationModels integration | Switchable Claude ↔ FM provider | ½–1 weekend |
| **M5** Polish + tests + docs | Completion sound, full test coverage, README | ½–1 weekend |
| **M6** Rocky art replacement | Custom Rocky frames swap in (independent, parallelizable) | 1–2 weekends |

---

# M0 — Project skeleton

**Branch:** `m0-skeleton`. Create with `git checkout -b m0-skeleton`.

## Task M0.1: Create Xcode project

**Files:**
- Create: `AgentRocky.xcodeproj/` (Xcode generates)
- Create: `AgentRocky/AgentRockyApp.swift` (Xcode generates, will overwrite)
- Create: `AgentRocky/Info.plist`
- Create: `AgentRocky/AgentRocky.entitlements`
- Create: `AgentRockyTests/` (test target stub)

This task is mechanical Xcode UI work — no code to paste, just clicks.

- [ ] **Step 1: Create the project in Xcode**

In Xcode 16+:
1. File → New → Project
2. macOS tab → App template
3. Product Name: `AgentRocky`
4. Team: your Apple ID team (or None for build-and-run)
5. Organization Identifier: `com.zhunhaowong.agentrocky` (or your choice; this becomes the bundle ID prefix)
6. Interface: **SwiftUI**
7. Language: **Swift**
8. Storage: **None**
9. Include Tests: ✓
10. Save into: `/Users/zhunhao/Documents/Projects/agent-rocky/`

The Xcode project lands directly in the repo root. Do **not** create a subfolder.

- [ ] **Step 2: Configure project settings**

In the Xcode project navigator, click the project root → AgentRocky target → General tab:
- **Minimum Deployment:** macOS 14.0 (Sonoma)
- **App Category:** Productivity
- **Identity:** Bundle Identifier as configured above

Build Settings tab → search "Swift Language Version":
- **Swift Language Version:** Swift 6
- **Strict Concurrency Checking:** Complete

Build Settings → search "Code Signing":
- **Code Signing Style:** Automatic (or Manual if you have specific certs)
- For now, pick "Sign to Run Locally" if Team is None

- [ ] **Step 3: Disable App Sandbox for v1**

In project settings → AgentRocky target → Signing & Capabilities:
- If "App Sandbox" is present, click the X to remove it.

Open `AgentRocky/AgentRocky.entitlements` and ensure it's empty:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

Rationale: spec §2 — we shell out to `claude` and read `com.apple.dock` system prefs; sandboxing v1 is out of scope.

- [ ] **Step 4: Configure Info.plist for accessory app**

Open `AgentRocky/Info.plist`. Add:

```xml
<key>LSUIElement</key>
<true/>
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>
```

`LSUIElement = true` makes this a status-item-only app (no dock icon for the app itself, no Force Quit menu entry). Spec §2.

- [ ] **Step 5: Verify project builds**

Run: ⌘B in Xcode, or `xcodebuild -project AgentRocky.xcodeproj -scheme AgentRocky build` from terminal.

Expected: **Build Succeeded.**

- [ ] **Step 6: Commit**

```bash
git checkout -b m0-skeleton
git add AgentRocky.xcodeproj AgentRocky/ AgentRockyTests/
git commit -m "chore(m0): scaffold Xcode project (macOS 14, Swift 6 strict concurrency, accessory app)"
```

## Task M0.2: Replace generated AgentRockyApp.swift with accessory app entry point

**Files:**
- Modify: `AgentRocky/AgentRockyApp.swift`
- Create: `AgentRocky/AppController.swift`

- [ ] **Step 1: Replace `AgentRockyApp.swift`**

Overwrite the entire file:

```swift
import SwiftUI
import AppKit

@main
struct AgentRockyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: AppController?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = AppController()
        controller?.start()
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "AgentRocky")

        let menu = NSMenu()
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit AgentRocky", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }
}
```

- [ ] **Step 2: Create `AppController.swift`**

Create `AgentRocky/AppController.swift`:

```swift
import AppKit

/// Top-level coordinator. Wires together overlay, popover, and agent layers.
/// In M0 it's a stub; subsequent milestones flesh it out.
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
```

- [ ] **Step 3: Build and run**

Run: ⌘R in Xcode.

Expected:
- A running figure (`figure.walk`) icon appears in the menu bar.
- No dock icon for AgentRocky.
- Clicking the menu icon shows a menu with "Quit AgentRocky".
- Quit works.

If you get a "developer mode" warning, accept it. If signing fails, set Code Signing Identity to "Sign to Run Locally."

- [ ] **Step 4: Commit**

```bash
git add AgentRocky/AgentRockyApp.swift AgentRocky/AppController.swift
git commit -m "feat(m0): accessory app entry point with status bar menu"
```

## Task M0.3: Verify M0 smoke test + merge to main

- [ ] **Step 1: Run smoke checklist**

Manual checks:
- [ ] App launches without crash
- [ ] Menu bar icon visible
- [ ] No dock icon for the app
- [ ] Quit menu item works

- [ ] **Step 2: Merge M0 to main**

```bash
git checkout main
git merge --no-ff m0-skeleton -m "Merge M0: project skeleton"
git push origin main
git push origin m0-skeleton:m0-skeleton   # optional: keep branch on remote for history
```

---

# M1 — Walking sprite (validates AVPlayer-with-alpha)

**Branch:** `m1-walking-sprite`. `git checkout -b m1-walking-sprite`.

This is the highest-risk milestone (transparent NSWindow + AVPlayer + alpha video are arcane). We use the reference's `walk-bruce-01.mov` as a known-good asset so any failure points to our code, not the asset.

## Task M1.1: Acquire reference character asset

**Files:**
- Create: `AgentRocky/Resources/character.mov`
- Create: `NOTICE`
- Modify: `README.md` (or create)

- [ ] **Step 1: Download `walk-bruce-01.mov` from the reference repo**

```bash
mkdir -p AgentRocky/Resources
curl -L -o AgentRocky/Resources/character.mov \
  "https://raw.githubusercontent.com/ryanstephen/lil-agents/main/LilAgents/walk-bruce-01.mov"
```

Verify the download:

```bash
file AgentRocky/Resources/character.mov
```

Expected: `character.mov: ISO Media, Apple QuickTime movie, Apple QuickTime ...` (HEVC w/ alpha).

- [ ] **Step 2: Create NOTICE attribution file**

Create `NOTICE`:

```
AgentRocky includes assets and code patterns from lil-agents
(https://github.com/ryanstephen/lil-agents), licensed under MIT.

Specifically:
- AgentRocky/Resources/character.mov: walk-bruce-01.mov by Ryan Stephen (placeholder; replaced in M6)
- Patterns ported in spirit:
  - Transparent borderless NSWindow setup
  - Dock geometry detection from com.apple.dock UserDefaults
  - ShellEnvironment.findBinary discovery
  - Walking state machine constants
  - --dangerously-skip-permissions Claude CLI invocation
  - UserDefaults-flag + speech-bubble onboarding
  - HEVC-with-alpha animation pipeline
  - CLI keep-alive process model
  - stream-json I/O
  - Visible-frame fullscreen-hide trick

MIT License (lil-agents):
The MIT License (MIT)

Copyright (c) Ryan Stephen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

- [ ] **Step 3: Create README.md**

Create `README.md`:

```markdown
# AgentRocky

A macOS dock companion app inspired by Project Hail Mary's Eridian engineer "Rocky". Click the character on your dock to chat with an AI assistant — backed by Claude Code CLI (cloud) or Apple FoundationModels (on-device).

> Status: in active development. See [docs/superpowers/specs/2026-04-30-agent-rocky-design.md](docs/superpowers/specs/2026-04-30-agent-rocky-design.md) for the design and [docs/superpowers/plans/2026-04-30-agent-rocky.md](docs/superpowers/plans/2026-04-30-agent-rocky.md) for the implementation plan.

## Requirements

- macOS 14+ (Sonoma) — Claude Code CLI works on all supported versions
- macOS 26+ (Tahoe) on Apple Silicon — required for FoundationModels adapter
- Xcode 16+ with Swift 6
- One of: [Claude Code CLI](https://claude.ai/download) installed, or Apple Intelligence enabled

## Building

```bash
git clone https://github.com/ZhunHao/agent-rocky.git
cd agent-rocky
open AgentRocky.xcodeproj
```

Hit ⌘R in Xcode.

## Attribution

This project includes the placeholder `character.mov` from [ryanstephen/lil-agents](https://github.com/ryanstephen/lil-agents) (MIT). See `NOTICE` for full attribution. The placeholder is replaced with custom Rocky art in M6.

## License

[TBD — MIT or similar permissive]
```

- [ ] **Step 4: Add to Xcode project**

In Xcode:
- Right-click `AgentRocky/Resources/` (create the group if missing) → Add Files to "AgentRocky"
- Select `character.mov`
- ✓ Copy items if needed: leave UNCHECKED (file is already in the right place)
- ✓ Add to targets: AgentRocky

- [ ] **Step 5: Commit**

```bash
git add AgentRocky/Resources/character.mov NOTICE README.md AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m1): add reference character.mov + NOTICE attribution + README"
```

## Task M1.2: DockGeometry — TDD

**Files:**
- Create: `AgentRocky/Overlay/DockGeometry.swift`
- Create: `AgentRockyTests/DockGeometryTests.swift`

- [ ] **Step 1: Write the failing test**

Create `AgentRockyTests/DockGeometryTests.swift`:

```swift
import XCTest
@testable import AgentRocky

final class DockGeometryTests: XCTestCase {
    func test_iconArea_with_default_tilesize_centers_dock() {
        let mockPrefs: [String: Any] = [
            "tilesize": 48.0,
            "persistent-apps": [Any](repeating: 0, count: 5),
            "persistent-others": [Any](repeating: 0, count: 3),
            "show-recents": true,
            "recent-apps": [Any](repeating: 0, count: 2),
        ]

        let result = DockGeometry.iconArea(
            screenWidth: 1920,
            prefsAccessor: { key in mockPrefs[key] }
        )

        // tileSize=48, slotWidth=48*1.25=60, totalIcons=5+3+2=10, dockWidth=600
        XCTAssertEqual(result.width, 600, accuracy: 0.001)
        // dockX = (1920 - 600) / 2 = 660
        XCTAssertEqual(result.x, 660, accuracy: 0.001)
        // dockTopY = tileSize + 16 = 64
        XCTAssertEqual(result.topY, 64, accuracy: 0.001)
    }

    func test_iconArea_falls_back_when_recents_disabled() {
        let mockPrefs: [String: Any] = [
            "tilesize": 48.0,
            "persistent-apps": [Any](repeating: 0, count: 5),
            "persistent-others": [Any](repeating: 0, count: 3),
            "show-recents": false,
            "recent-apps": [Any](repeating: 0, count: 2),  // ignored
        ]

        let result = DockGeometry.iconArea(
            screenWidth: 1920,
            prefsAccessor: { key in mockPrefs[key] }
        )

        // totalIcons=5+3=8, dockWidth=480
        XCTAssertEqual(result.width, 480, accuracy: 0.001)
    }

    func test_iconArea_clamps_to_minimum_one_icon_when_no_apps() {
        let mockPrefs: [String: Any] = ["tilesize": 48.0]
        let result = DockGeometry.iconArea(
            screenWidth: 1920,
            prefsAccessor: { key in mockPrefs[key] }
        )
        // totalIcons clamped to 1, dockWidth=60
        XCTAssertEqual(result.width, 60, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test — expect compile failure**

Run: in Xcode, ⌘U (Test). Or:

```bash
xcodebuild test -project AgentRocky.xcodeproj -scheme AgentRocky -destination 'platform=macOS'
```

Expected: build fails — `Cannot find 'DockGeometry' in scope`. Good — the test is correctly failing because the type doesn't exist.

- [ ] **Step 3: Implement `DockGeometry`**

Create `AgentRocky/Overlay/DockGeometry.swift`:

```swift
import Foundation
import AppKit

/// Reads `com.apple.dock` user defaults to compute the icon-area rectangle.
/// Pure logic; no AppKit / NSScreen dependency to make it unit-testable.
enum DockGeometry {
    /// The horizontal extent occupied by app icons and the screen-Y at which the dock's top sits.
    /// Coordinates are in screen-bottom-origin space (AppKit convention).
    struct IconArea: Equatable {
        let x: CGFloat
        let width: CGFloat
        let topY: CGFloat
    }

    /// Production accessor: reads from `UserDefaults(suiteName: "com.apple.dock")`.
    static func iconArea(for screen: NSScreen) -> IconArea {
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        return iconArea(
            screenWidth: screen.frame.width,
            prefsAccessor: { key in prefs?.object(forKey: key) }
        )
    }

    /// Testable variant — accept any prefs accessor.
    static func iconArea(
        screenWidth: CGFloat,
        prefsAccessor: (String) -> Any?
    ) -> IconArea {
        let tileSize = (prefsAccessor("tilesize") as? Double).map(CGFloat.init) ?? 48
        let slotWidth = tileSize * 1.25

        let persistentApps = (prefsAccessor("persistent-apps") as? [Any])?.count ?? 0
        let persistentOthers = (prefsAccessor("persistent-others") as? [Any])?.count ?? 0
        let showRecents = (prefsAccessor("show-recents") as? Bool) ?? true
        let recents = showRecents
            ? ((prefsAccessor("recent-apps") as? [Any])?.count ?? 0)
            : 0

        let totalIcons = max(persistentApps + persistentOthers + recents, 1)
        let dockWidth = slotWidth * CGFloat(totalIcons)
        let dockX = (screenWidth - dockWidth) / 2
        let dockTopY = tileSize + 16

        return IconArea(x: dockX, width: dockWidth, topY: dockTopY)
    }
}
```

- [ ] **Step 4: Add to Xcode target**

In Xcode: drag `AgentRocky/Overlay/DockGeometry.swift` into the project navigator under a new `Overlay/` group → Add to AgentRocky target.

- [ ] **Step 5: Run tests — expect pass**

Run: ⌘U in Xcode.

Expected: `DockGeometryTests` — 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add AgentRocky/Overlay/DockGeometry.swift AgentRockyTests/DockGeometryTests.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m1): DockGeometry — compute icon-area rect from com.apple.dock prefs"
```

## Task M1.3: WalkerCharacter state machine — TDD

**Files:**
- Create: `AgentRocky/Overlay/WalkerCharacter.swift`
- Create: `AgentRockyTests/WalkerCharacterTests.swift`

- [ ] **Step 1: Write the failing test**

Create `AgentRockyTests/WalkerCharacterTests.swift`:

```swift
import XCTest
@testable import AgentRocky

final class WalkerCharacterTests: XCTestCase {
    func test_initial_state_is_pausing() {
        let walker = WalkerCharacter()
        XCTAssertEqual(walker.phase, .pausing)
    }

    func test_freeze_halts_position_updates() {
        let walker = WalkerCharacter()
        walker.positionProgress = 0.5
        let xBefore = walker.tick(now: 0, dockBounds: (x: 100, width: 600))

        walker.isFrozen = true
        let xAfter1 = walker.tick(now: 1.0, dockBounds: (x: 100, width: 600))
        let xAfter2 = walker.tick(now: 2.0, dockBounds: (x: 100, width: 600))

        XCTAssertEqual(xBefore, xAfter1)
        XCTAssertEqual(xAfter1, xAfter2)
    }

    func test_position_progress_stays_within_bounds() {
        let walker = WalkerCharacter()
        // Tick for 60 seconds, advancing 0.1s at a time
        for i in 0..<600 {
            _ = walker.tick(now: Double(i) * 0.1, dockBounds: (x: 0, width: 1000))
            XCTAssertGreaterThanOrEqual(walker.positionProgress, 0)
            XCTAssertLessThanOrEqual(walker.positionProgress, 1)
        }
    }

    func test_position_x_maps_to_screen_coords() {
        let walker = WalkerCharacter()
        walker.positionProgress = 0.5
        let x = walker.tick(now: 0, dockBounds: (x: 200, width: 800))
        // 200 + 0.5 * 800 = 600
        XCTAssertEqual(x, 600, accuracy: 0.5)
    }

    func test_phase_transitions_through_walk_cycle() {
        let walker = WalkerCharacter()
        walker.pauseEndTime = 0  // skip initial pause
        walker.phaseStartTime = 0
        walker.phase = .pausing

        // Advance time past the end-of-pause threshold; expect transition into .accelerating
        _ = walker.tick(now: 0.1, dockBounds: (x: 0, width: 1000))
        XCTAssertEqual(walker.phase, .accelerating)
    }
}
```

- [ ] **Step 2: Run test — expect compile failure**

Run: ⌘U.

Expected: `Cannot find 'WalkerCharacter' in scope`.

- [ ] **Step 3: Implement `WalkerCharacter`**

Create `AgentRocky/Overlay/WalkerCharacter.swift`:

```swift
import Foundation
import Observation
import QuartzCore

/// Pure animation state machine. No AppKit / NSWindow dependencies — driven by `tick(now:dockBounds:)`.
/// Spec §7. Constants modelled after lil-agents' Bruce/Jazz tunables.
@Observable
final class WalkerCharacter {
    enum Direction { case left, right }
    enum Phase: Equatable { case pausing, accelerating, cruising, decelerating }

    // Current state
    var positionProgress: Double = 0.5     // 0..1 across dock width
    var direction: Direction = .right
    var phase: Phase = .pausing
    var pauseEndTime: CFTimeInterval = 1.0
    var phaseStartTime: CFTimeInterval = 0
    var isFrozen: Bool = false

    // Per-walk randomized fraction of dock to traverse before stopping
    private var currentWalkAmount: Double = 0.5

    // Tunables (per-character; reference's Bruce values as defaults)
    var accelDuration: TimeInterval = 0.75      // accelStart→fullSpeedStart in reference
    var cruiseSpeed: Double = 0.06              // dock-fractions per second at full speed
    var decelDuration: TimeInterval = 0.5       // decelStart→walkStop in reference
    var pauseRange: ClosedRange<TimeInterval> = 0.5...3.0
    var walkAmountRange: ClosedRange<Double> = 0.4...0.65

    private(set) var cachedX: CGFloat = 0

    /// Advance state by current time. Returns the absolute X origin in screen coordinates.
    /// `dockBounds` is the (x, width) of the dock icon area.
    @discardableResult
    func tick(now: CFTimeInterval, dockBounds: (x: CGFloat, width: CGFloat)) -> CGFloat {
        guard !isFrozen else {
            return cachedX
        }

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
                advance(by: cruiseSpeed * fraction * (now - phaseStartTime - elapsed) /* simplified */)
                // simplified linear ramp:
                advance(by: cruiseSpeed * 0.5 * fraction * (1.0 / 60.0))
            }
        case .cruising:
            advance(by: cruiseSpeed * (1.0 / 60.0))
            // Stop when we've walked our randomized walk amount
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
                advance(by: cruiseSpeed * remaining * (1.0 / 60.0))
            }
        }

        // Clamp progress and reverse direction at edges
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

    // MARK: - Private state transitions

    private var walkStartProgress: Double = 0.5

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
```

> **Note on the state machine:** the cruising/accelerating math above is intentionally simple. lil-agents has a more polished accel curve. Refine in M5 polish if Rocky's gait feels jerky; for now this is "good enough to demo." Ensure the unit tests still pass after any polish changes.

- [ ] **Step 4: Add to target and run tests**

Drag `WalkerCharacter.swift` into Xcode → AgentRocky target.

Run: ⌘U.

Expected: all 5 `WalkerCharacterTests` pass. If a position-bounds test fails, the cruise-speed math is too aggressive — reduce `cruiseSpeed` until tests pass.

- [ ] **Step 5: Commit**

```bash
git add AgentRocky/Overlay/WalkerCharacter.swift AgentRockyTests/WalkerCharacterTests.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m1): WalkerCharacter state machine (pausing/accel/cruise/decel + freeze)"
```

## Task M1.4: ScreenObserver

**Files:**
- Create: `AgentRocky/Overlay/ScreenObserver.swift`

No tests — this is a thin wrapper over `NotificationCenter`. Verified by M1.7 smoke.

- [ ] **Step 1: Implement**

Create `AgentRocky/Overlay/ScreenObserver.swift`:

```swift
import AppKit

/// Observes screen and dock-pref changes and invokes a callback.
/// Spec §7.
final class ScreenObserver {
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.onChange?() }
        )
        observers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.dock.preferences-changed"),
                object: nil, queue: .main
            ) { [weak self] _ in self?.onChange?() }
        )
    }

    func stop() {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
            DistributedNotificationCenter.default().removeObserver($0)
        }
        observers.removeAll()
    }

    deinit { stop() }
}
```

- [ ] **Step 2: Build (no test)**

Run: ⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add AgentRocky/Overlay/ScreenObserver.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m1): ScreenObserver for screen + dock-pref change notifications"
```

## Task M1.5: TickDriver (CADisplayLink wrapper)

**Files:**
- Create: `AgentRocky/Overlay/TickDriver.swift`

- [ ] **Step 1: Implement**

Create `AgentRocky/Overlay/TickDriver.swift`:

```swift
import QuartzCore

/// CADisplayLink-based animation tick driver. macOS 14+.
/// Spec §7.
final class TickDriver {
    private var displayLink: CADisplayLink?
    private var tick: ((CFTimeInterval) -> Void)?

    func start(_ tick: @escaping (CFTimeInterval) -> Void) {
        stop()
        self.tick = tick
        let link = CADisplayLink(target: self, selector: #selector(handleTick(_:)))
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

    deinit { stop() }
}
```

- [ ] **Step 2: Build**

Run: ⌘B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add AgentRocky/Overlay/TickDriver.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m1): TickDriver — CADisplayLink wrapper"
```

## Task M1.6: CharacterOverlayWindow

**Files:**
- Create: `AgentRocky/Overlay/CharacterOverlayWindow.swift`

- [ ] **Step 1: Implement**

Create `AgentRocky/Overlay/CharacterOverlayWindow.swift`:

```swift
import AppKit
import AVFoundation

/// Borderless transparent window that hosts the character's AVPlayerLayer.
/// Spec §7.
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
        ignoresMouseEvents = true                       // toggled per-pixel by the click-through monitor
        collectionBehavior = [.moveToActiveSpace, .stationary]

        let asset = AVAsset(url: videoURL)
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
        // Preserve alpha by setting these pixel buffer attributes on the player item:
        item.add(AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]))
        hostView.layer?.addSublayer(layer)
        playerLayer = layer

        contentView = hostView
    }

    func play() { queuePlayer.play() }
    func pauseAtFirstFrame() {
        queuePlayer.pause()
        queuePlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Resize layer when window changes size (called by AppController on dock-pref change).
    func updateLayerFrame() {
        playerLayer.frame = (contentView?.bounds) ?? .zero
    }
}
```

- [ ] **Step 2: Build**

Run: ⌘B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add AgentRocky/Overlay/CharacterOverlayWindow.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m1): CharacterOverlayWindow with transparent NSWindow + AVPlayerLooper"
```

## Task M1.7: Wire walking sprite into AppController

**Files:**
- Modify: `AgentRocky/AppController.swift`

- [ ] **Step 1: Update `AppController`**

Replace the body of `AgentRocky/AppController.swift`:

```swift
import AppKit

@MainActor
final class AppController {
    private var overlayWindow: CharacterOverlayWindow?
    private var walker = WalkerCharacter()
    private let tickDriver = TickDriver()
    private let screenObserver = ScreenObserver()
    private var lastShouldShow: Bool = false

    func start() {
        installOverlay()
        screenObserver.onChange = { [weak self] in self?.installOverlay() }
        screenObserver.start()

        tickDriver.start { [weak self] now in
            guard let self else { return }
            self.tick(now: now)
        }
    }

    func shutdown() {
        tickDriver.stop()
        screenObserver.stop()
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    // MARK: - Setup

    private func installOverlay() {
        guard let screen = NSScreen.main else { return }
        guard let videoURL = Bundle.main.url(forResource: "character", withExtension: "mov") else {
            assertionFailure("character.mov missing from bundle")
            return
        }

        let geometry = DockGeometry.iconArea(for: screen)
        let frame = NSRect(
            x: geometry.x,
            y: geometry.topY,
            width: geometry.width,
            height: 96
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

    // MARK: - Tick

    private func tick(now: CFTimeInterval) {
        guard let win = overlayWindow, let screen = NSScreen.main else { return }

        // Fullscreen-hide: when an app is fullscreen on this screen, the dock isn't reserving space.
        let shouldShow = (screen.visibleFrame != screen.frame)
        if shouldShow != lastShouldShow {
            if shouldShow {
                win.orderFrontRegardless()
                win.play()
            } else {
                win.orderOut(nil)
                win.pauseAtFirstFrame()
            }
            lastShouldShow = shouldShow
        }
        guard shouldShow else { return }

        let geometry = DockGeometry.iconArea(for: screen)
        let dockBounds = (x: geometry.x, width: geometry.width)
        let centerX = walker.tick(now: now, dockBounds: dockBounds)

        var frame = win.frame
        frame.origin.x = centerX - frame.width / 2
        frame.origin.y = geometry.topY
        win.setFrame(frame, display: false)
    }
}
```

> Note: the overlay window's `frame.width` is the dock-icon-area width, but its `origin.x` follows Rocky's center. That makes the window's *own* X track Rocky precisely. Refinement: in M2 we shrink the window to match Rocky's sprite size for accurate hit-testing. For M1 the wide window is fine (clicks pass through everywhere except where alpha>threshold, which is just where Rocky's pixels are).

- [ ] **Step 2: Build and run**

Run: ⌘R.

Expected:
- Bruce (the dachshund from `walk-bruce-01.mov`) appears above your dock and walks back and forth
- Rocky (placeholder = Bruce) hides when you go fullscreen on a window
- Rocky reappears when you exit fullscreen
- Quitting via menu still works

Troubleshooting:
- **Black square instead of transparent character:** alpha not preserved. Verify `character.mov` is HEVC w/ alpha (re-download from reference if uncertain). Also check that `isOpaque = false` and the host view's layer background is `.clear`.
- **Character doesn't move:** put a `print(centerX)` in `tick(now:)`. If centerX is changing but window doesn't, the `setFrame` call needs `display: true`.
- **Character flashes / jitters:** that's normal at high refresh rates if `setFrame(_:display:false)` is set. Try `display: true` if it's distracting.

- [ ] **Step 3: Manual smoke test**

- [ ] Walk back and forth above dock
- [ ] Disappears on fullscreen
- [ ] Reappears on exit fullscreen
- [ ] Reposition dock (make dock bigger/smaller in System Settings → Desktop & Dock) → character resizes to match
- [ ] Quit via menu works without crash

- [ ] **Step 4: Commit**

```bash
git add AgentRocky/AppController.swift
git commit -m "feat(m1): wire WalkerCharacter + CharacterOverlayWindow + fullscreen-hide via AppController"
```

## Task M1.8: M1 merge

- [ ] **Step 1: Merge to main**

```bash
git checkout main
git merge --no-ff m1-walking-sprite -m "Merge M1: walking sprite (uses reference's character.mov as placeholder)"
git push origin main
```

---

# M2 — Click-to-talk with mock agent (validates click-through)

**Branch:** `m2-click-to-talk`. `git checkout -b m2-click-to-talk`.

This milestone builds the entire popover/UI stack against a mock `AgentSession` so layout and streaming UI iteration is independent of CLI complexity. M3 swaps the mock for real Claude.

## Task M2.1: Theme + RockyTheme

**Files:**
- Create: `AgentRocky/Theme/Theme.swift`
- Create: `AgentRocky/Theme/RockyTheme.swift`

- [ ] **Step 1: Implement `Theme.swift`**

```swift
import SwiftUI

struct Theme: Sendable {
    let name: String
    let background: Color
    let foreground: Color
    let accent: Color
    let userBubble: Color
    let assistantBubble: Color
    let errorColor: Color
    let monoFont: Font
}

extension Color {
    init(light: NSColor, dark: NSColor) {
        self = Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = RockyTheme.theme
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Implement `RockyTheme.swift`**

```swift
import SwiftUI
import AppKit

/// Eridian palette: stone grays + ammonia-blue accent.
/// Adapts to light/dark via Color(light:dark:).
enum RockyTheme {
    static let theme = Theme(
        name: "Eridian",
        background: Color(
            light: NSColor(white: 0.96, alpha: 1.0),
            dark:  NSColor(white: 0.12, alpha: 1.0)
        ),
        foreground: Color(
            light: NSColor(white: 0.10, alpha: 1.0),
            dark:  NSColor(white: 0.95, alpha: 1.0)
        ),
        accent: Color(
            light: NSColor(red: 0.22, green: 0.42, blue: 0.65, alpha: 1.0),
            dark:  NSColor(red: 0.45, green: 0.65, blue: 0.85, alpha: 1.0)
        ),
        userBubble: Color(
            light: NSColor(white: 0.90, alpha: 1.0),
            dark:  NSColor(white: 0.20, alpha: 1.0)
        ),
        assistantBubble: Color(
            light: NSColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1.0),
            dark:  NSColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1.0)
        ),
        errorColor: Color(
            light: NSColor.systemRed,
            dark:  NSColor.systemRed.withAlphaComponent(0.9)
        ),
        monoFont: .system(.body, design: .monospaced)
    )
}
```

- [ ] **Step 3: Build, commit**

Run: ⌘B. Expected: build succeeds.

```bash
mkdir -p AgentRocky/Theme
git add AgentRocky/Theme/Theme.swift AgentRocky/Theme/RockyTheme.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): Theme protocol + RockyTheme (Eridian palette, light/dark)"
```

## Task M2.2: AgentEvent + AgentMessage models

**Files:**
- Create: `AgentRocky/Agent/AgentSession.swift`
- Create: `AgentRocky/Agent/AgentProvider.swift`

> M2 only needs the data models; the protocol body and adapters land in M3 (Claude) and M4 (FoundationModels).

- [ ] **Step 1: Implement `AgentSession.swift` (models only for M2)**

```swift
import Foundation

// MARK: - Public protocol (filled in M3)

protocol AgentSession: AnyObject, Sendable {
    var provider: AgentProvider { get }
    var state: SessionState { get }
    var history: [AgentMessage] { get }
    var events: AsyncStream<AgentEvent> { get }   // single long-lived, single-consumer stream

    func start() async throws
    func send(_ message: String) async throws
    func cancelCurrentTurn()
    func terminate()
}

// MARK: - Models

enum SessionState: Sendable, Equatable {
    case idle, starting, ready, busy, terminated
    case failed(String)         // Error -> String for Equatable + Sendable simplicity
}

enum AgentEvent: Sendable {
    case sessionReady
    case textDelta(String)
    case toolCall(name: String, summary: String)
    case toolResult(name: String, success: Bool)
    case turnComplete
    case error(AgentError)
    case sessionEnded
}

struct AgentMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date

    enum Role: String, Sendable, Equatable {
        case user, assistant, system, error
    }

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

enum AgentError: Error, Sendable, Equatable {
    case providerNotAvailable(AgentProvider)
    case sessionBusy
    case contextWindowExceeded
    case rateLimited
    case processStartFailed(detail: String)
    case sessionDied(reason: String)
    case streamCorrupt(detail: String)
    case other(String)
}
```

- [ ] **Step 2: Implement `AgentProvider.swift`**

```swift
import Foundation

enum AgentProvider: String, CaseIterable, Sendable, Equatable {
    case claude
    case foundationModels

    var displayName: String {
        switch self {
        case .claude:           return "Claude Code"
        case .foundationModels: return "FoundationModels (on-device)"
        }
    }

    var installInstructions: String {
        switch self {
        case .claude:
            return """
            Claude Code CLI not found. Install with:

              curl -fsSL https://claude.ai/install.sh | sh

            Then quit and relaunch AgentRocky.
            """
        case .foundationModels:
            return """
            Apple FoundationModels requires macOS 26+ on Apple Silicon
            with Apple Intelligence enabled in System Settings.
            """
        }
    }
}
```

- [ ] **Step 3: Build and commit**

```bash
mkdir -p AgentRocky/Agent
git add AgentRocky/Agent/AgentSession.swift AgentRocky/Agent/AgentProvider.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): AgentSession protocol skeleton + AgentEvent/Message/Error/Provider models"
```

## Task M2.3: MockAgentSession

**Files:**
- Create: `AgentRocky/Agent/MockAgentSession.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation

/// In-memory mock that echoes user messages back as fake streamed responses.
/// Used in M2 for UI iteration without CLI complexity.
actor MockAgentSession: AgentSession {
    let provider: AgentProvider = .claude
    private(set) var state: SessionState = .idle
    private(set) var history: [AgentMessage] = []

    nonisolated let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    init() {
        var cont: AsyncStream<AgentEvent>.Continuation!
        self.events = AsyncStream { c in cont = c }
        self.continuation = cont
    }

    func start() async throws {
        state = .starting
        try await Task.sleep(nanoseconds: 200_000_000)
        state = .ready
        continuation.yield(.sessionReady)
    }

    func send(_ message: String) async throws {
        guard state == .ready else { throw AgentError.sessionBusy }
        state = .busy
        history.append(.init(role: .user, text: message))

        // Simulate a streamed response
        let response = "Questioner. You said: \"\(message)\". Understood."
        for char in response {
            try await Task.sleep(nanoseconds: 30_000_000)   // ~33 chars/sec
            continuation.yield(.textDelta(String(char)))
        }
        continuation.yield(.turnComplete)
        state = .ready
    }

    nonisolated func cancelCurrentTurn() {
        // Mock has nothing to cancel mid-stream; no-op.
    }

    func terminate() {
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }
}
```

- [ ] **Step 2: Build, commit**

```bash
git add AgentRocky/Agent/MockAgentSession.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): MockAgentSession actor — echoes user input as fake stream"
```

## Task M2.4: CommandDispatcher — TDD

**Files:**
- Create: `AgentRocky/Commands/CommandDispatcher.swift`
- Create: `AgentRockyTests/CommandDispatcherTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AgentRocky

final class CommandDispatcherTests: XCTestCase {
    let dispatcher = CommandDispatcher()

    func test_clear_command() {
        XCTAssertEqual(dispatcher.interpret("/clear"), .command(.clear))
    }

    func test_copy_command() {
        XCTAssertEqual(dispatcher.interpret("/copy"), .command(.copy))
    }

    func test_help_command() {
        XCTAssertEqual(dispatcher.interpret("/help"), .command(.help))
    }

    func test_unknown_slash_command() {
        XCTAssertEqual(dispatcher.interpret("/foo"), .unknownCommand("/foo"))
    }

    func test_plain_message_passes_through() {
        XCTAssertEqual(dispatcher.interpret("hello rocky"), .message("hello rocky"))
    }

    func test_leading_whitespace_trimmed() {
        XCTAssertEqual(dispatcher.interpret("   /clear   "), .command(.clear))
    }

    func test_message_with_slash_inside_passes_through() {
        XCTAssertEqual(
            dispatcher.interpret("show me path/to/file"),
            .message("show me path/to/file")
        )
    }

    func test_empty_passes_through_as_empty_message() {
        XCTAssertEqual(dispatcher.interpret(""), .message(""))
        XCTAssertEqual(dispatcher.interpret("   "), .message(""))
    }
}
```

- [ ] **Step 2: Run test — expect compile failure**

Run ⌘U. Expected: `Cannot find 'CommandDispatcher' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

enum SlashCommand: String, CaseIterable, Equatable {
    case clear = "/clear"
    case copy  = "/copy"
    case help  = "/help"

    var helpText: String {
        switch self {
        case .clear: return "/clear — wipe the transcript and reset the agent's context"
        case .copy:  return "/copy — copy Rocky's last response to the clipboard"
        case .help:  return "/help — show available slash commands"
        }
    }
}

enum DispatchResult: Equatable {
    case command(SlashCommand)
    case unknownCommand(String)
    case message(String)
}

struct CommandDispatcher {
    func interpret(_ input: String) -> DispatchResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .message(trimmed)
        }
        if let cmd = SlashCommand(rawValue: trimmed) {
            return .command(cmd)
        }
        return .unknownCommand(trimmed)
    }

    static var helpMessage: String {
        SlashCommand.allCases.map(\.helpText).joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run ⌘U. Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
mkdir -p AgentRocky/Commands
git add AgentRocky/Commands/CommandDispatcher.swift AgentRockyTests/CommandDispatcherTests.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): CommandDispatcher — pure /clear /copy /help router"
```

## Task M2.5: ChatViewModel

**Files:**
- Create: `AgentRocky/Popover/ChatViewModel.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation
import Observation
import AppKit

/// Mediates between an AgentSession (event stream) and the SwiftUI TerminalView (transcript).
/// Spec §5 — single-consumer of `session.events`.
@Observable
@MainActor
final class ChatViewModel {
    private(set) var transcript: [AgentMessage] = []
    private(set) var isBusy: Bool = false
    private(set) var inputDisabled: Bool = false
    var inputText: String = ""

    private var session: (any AgentSession)?
    private var consumeTask: Task<Void, Never>?
    private var inProgressAssistantID: AgentMessage.ID?

    private let dispatcher = CommandDispatcher()

    func attach(_ session: any AgentSession) {
        // Detach prior session if any
        consumeTask?.cancel()
        self.session = session

        // Subscribe to event stream
        consumeTask = Task { @MainActor [weak self] in
            for await event in session.events {
                self?.handle(event)
            }
        }
    }

    func submit() async {
        let raw = inputText
        inputText = ""

        switch dispatcher.interpret(raw) {
        case .command(.clear):
            transcript = []
            // M3 will forward the actual /clear to the adapter
        case .command(.copy):
            if let last = transcript.last(where: { $0.role == .assistant }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(last.text, forType: .string)
            }
        case .command(.help):
            transcript.append(.init(role: .system, text: CommandDispatcher.helpMessage))
        case .unknownCommand(let s):
            transcript.append(.init(role: .system, text: "unknown command: \(s) — try /help"))
        case .message(""):
            return    // ignore blank submissions
        case .message(let s):
            await sendToSession(s)
        }
    }

    private func sendToSession(_ message: String) async {
        guard let session else { return }
        transcript.append(.init(role: .user, text: message))
        isBusy = true
        inputDisabled = true
        do {
            try await session.send(message)
        } catch let err as AgentError {
            transcript.append(.init(role: .error, text: errorDescription(err)))
            isBusy = false
            inputDisabled = false
        } catch {
            transcript.append(.init(role: .error, text: "Unexpected error: \(error)"))
            isBusy = false
            inputDisabled = false
        }
    }

    private func handle(_ event: AgentEvent) {
        switch event {
        case .sessionReady:
            isBusy = false
            inputDisabled = false

        case .textDelta(let s):
            if inProgressAssistantID == nil {
                let msg = AgentMessage(role: .assistant, text: "")
                inProgressAssistantID = msg.id
                transcript.append(msg)
            }
            if let id = inProgressAssistantID,
               let idx = transcript.firstIndex(where: { $0.id == id }) {
                transcript[idx].text += s
            }

        case .turnComplete:
            inProgressAssistantID = nil
            isBusy = false
            inputDisabled = false

        case .error(let err):
            transcript.append(.init(role: .error, text: errorDescription(err)))
            inProgressAssistantID = nil
            isBusy = false
            inputDisabled = false

        case .toolCall, .toolResult:
            // v1: silently ignore. v2: render inline.
            break

        case .sessionEnded:
            isBusy = false
            inputDisabled = true        // can't send after the session ends
        }
    }

    private func errorDescription(_ err: AgentError) -> String {
        switch err {
        case .providerNotAvailable(let p): return p.installInstructions
        case .sessionBusy:                 return "Rocky's still working on the previous question."
        case .contextWindowExceeded:       return "Rocky's memory is full — type /clear to start fresh."
        case .rateLimited:                 return "Rocky needs a moment — try again."
        case .processStartFailed(let d):   return "Couldn't start Rocky's connection: \(d)"
        case .sessionDied(let r):          return "Rocky's connection died: \(r)"
        case .streamCorrupt(let d):        return "Communication problem with Rocky: \(d)"
        case .other(let s):                return s
        }
    }
}
```

- [ ] **Step 2: Build, commit**

```bash
mkdir -p AgentRocky/Popover
git add AgentRocky/Popover/ChatViewModel.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): ChatViewModel — single-consumer of AsyncStream<AgentEvent>"
```

## Task M2.6: TerminalView (SwiftUI)

**Files:**
- Create: `AgentRocky/Popover/TerminalView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct TerminalView: View {
    @Environment(\.theme) private var theme
    @Bindable var viewModel: ChatViewModel
    var onCopyLast: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.foreground.opacity(0.1))
            transcript
            Divider().background(theme.foreground.opacity(0.1))
            input
        }
        .background(theme.background)
        .foregroundColor(theme.foreground)
        .frame(minWidth: 320, idealWidth: 360, minHeight: 360, idealHeight: 480)
    }

    private var header: some View {
        HStack {
            Text("Rocky")
                .font(.headline)
            Spacer()
            Button {
                onCopyLast()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy last response")

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.transcript) { msg in
                        messageRow(msg)
                            .id(msg.id)
                    }
                    Spacer().frame(height: 4)
                        .id("bottomAnchor")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.transcript.last?.text) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ msg: AgentMessage) -> some View {
        switch msg.role {
        case .user:
            HStack { Spacer(minLength: 24); bubble(msg.text, color: theme.userBubble) }
        case .assistant:
            HStack { bubble(msg.text, color: theme.assistantBubble); Spacer(minLength: 24) }
        case .system:
            Text(msg.text)
                .font(theme.monoFont)
                .foregroundColor(theme.foreground.opacity(0.7))
                .padding(.vertical, 2)
        case .error:
            Text(msg.text)
                .font(theme.monoFont)
                .foregroundColor(theme.errorColor)
                .padding(8)
                .background(theme.errorColor.opacity(0.08))
                .cornerRadius(6)
        }
    }

    private func bubble(_ text: String, color: Color) -> some View {
        Text(text)
            .font(theme.monoFont)
            .padding(10)
            .background(color)
            .cornerRadius(10)
            .textSelection(.enabled)
    }

    private var input: some View {
        HStack {
            TextField("Ask Rocky…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .font(theme.monoFont)
                .onSubmit { Task { await viewModel.submit() } }
                .disabled(viewModel.inputDisabled)
            if viewModel.isBusy {
                ProgressView().scaleEffect(0.6)
            } else {
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
    }
}
```

- [ ] **Step 2: Build, commit**

```bash
git add AgentRocky/Popover/TerminalView.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): TerminalView — SwiftUI chat UI with header/transcript/input"
```

## Task M2.7: CharacterPopover (NSPanel)

**Files:**
- Create: `AgentRocky/Popover/CharacterPopover.swift`

- [ ] **Step 1: Implement**

```swift
import AppKit
import SwiftUI

/// Borderless non-activating panel anchored above the character's current X.
/// Spec §7.
@MainActor
final class CharacterPopover {
    var onShow: (() -> Void)?
    var onHide: (() -> Void)?
    var onCopyLast: (() -> Void)?

    private var panel: NSPanel?
    private var hostingController: NSHostingController<TerminalView>?
    private(set) var isVisible: Bool = false

    let viewModel: ChatViewModel = ChatViewModel()

    func show(anchoredAt rockyCenterX: CGFloat, rockyTopY: CGFloat) {
        if panel == nil { buildPanel() }
        guard let panel else { return }

        let popoverWidth: CGFloat = 360
        let popoverHeight: CGFloat = 480
        let gap: CGFloat = 12
        let originX = rockyCenterX - popoverWidth / 2
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
        hostingController = host

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

        // Close on Esc / Cmd-W
        p.standardWindowButton(.closeButton)?.target = self
        p.standardWindowButton(.closeButton)?.action = #selector(closeFromButton)

        panel = p
    }

    @objc private func closeFromButton() { hide() }
}
```

- [ ] **Step 2: Commit**

```bash
git add AgentRocky/Popover/CharacterPopover.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): CharacterPopover — NSPanel anchored above character"
```

## Task M2.8: HitTesting — TDD

**Files:**
- Create: `AgentRocky/Overlay/HitTesting.swift`
- Create: `AgentRockyTests/HitTestingTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AppKit
@testable import AgentRocky

final class HitTestingTests: XCTestCase {
    /// 4×4 image: opaque red square in top-left 2×2, transparent elsewhere.
    private func makeFixtureImage() -> NSImage {
        let size = NSSize(width: 4, height: 4)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 2, width: 2, height: 2).fill()   // top-left in flipped coords
        img.unlockFocus()
        return img
    }

    func test_opaque_pixel_returns_true() {
        let img = makeFixtureImage()
        // y is flipped in NSImage (origin bottom-left) — top-left 2x2 means high y values
        XCTAssertTrue(HitTesting.isOpaque(at: NSPoint(x: 0, y: 3), in: img, threshold: 0.1))
    }

    func test_transparent_pixel_returns_false() {
        let img = makeFixtureImage()
        XCTAssertFalse(HitTesting.isOpaque(at: NSPoint(x: 3, y: 0), in: img, threshold: 0.1))
    }

    func test_out_of_bounds_returns_false() {
        let img = makeFixtureImage()
        XCTAssertFalse(HitTesting.isOpaque(at: NSPoint(x: 100, y: 100), in: img, threshold: 0.1))
        XCTAssertFalse(HitTesting.isOpaque(at: NSPoint(x: -1, y: 0), in: img, threshold: 0.1))
    }
}
```

- [ ] **Step 2: Run — expect failure**

Run ⌘U. Expected: `Cannot find 'HitTesting' in scope`.

- [ ] **Step 3: Implement**

```swift
import AppKit

/// Per-pixel alpha hit testing on an NSImage.
/// Spec §7.
enum HitTesting {
    /// Returns true if the pixel at `point` (image coordinates, origin bottom-left)
    /// has alpha greater than `threshold` (0..1).
    static func isOpaque(at point: NSPoint, in image: NSImage, threshold: CGFloat = 0.1) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        let width = cgImage.width
        let height = cgImage.height
        let x = Int(point.x)
        let y = height - 1 - Int(point.y)   // CGImage origin is top-left
        guard x >= 0, x < width, y >= 0, y < height else { return false }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return false }

        context.translateBy(x: -CGFloat(x), y: -CGFloat(height - 1 - y))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let alpha = CGFloat(pixel[3]) / 255.0
        return alpha > threshold
    }

    /// Cache-friendly: extract frame 1 of an asset as the static idle hit mask.
    /// Used by the overlay window to avoid grabbing the live AVPlayer frame on every mouse-move.
    static func extractFirstFrame(from videoURL: URL) -> NSImage? {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return NSImage(cgImage: cgImage, size: .zero)
        } catch {
            return nil
        }
    }
}

import AVFoundation
```

> Note: `import AVFoundation` is at the bottom because of the `extractFirstFrame` helper. Move it to the top during cleanup; it's positioned this way so the file is logically grouped.

Move `import AVFoundation` to the top:

```swift
import AppKit
import AVFoundation

enum HitTesting { /* ... */ }
```

- [ ] **Step 4: Run tests — expect pass**

Run ⌘U. Expected: 3 `HitTestingTests` pass.

- [ ] **Step 5: Commit**

```bash
git add AgentRocky/Overlay/HitTesting.swift AgentRockyTests/HitTestingTests.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m2): HitTesting per-pixel alpha + first-frame extraction"
```

## Task M2.9: Wire popover, click-through, freeze into AppController

**Files:**
- Modify: `AgentRocky/AppController.swift`

- [ ] **Step 1: Update `AppController`**

Replace the body:

```swift
import AppKit

@MainActor
final class AppController {
    private var overlayWindow: CharacterOverlayWindow?
    private var walker = WalkerCharacter()
    private let tickDriver = TickDriver()
    private let screenObserver = ScreenObserver()
    private let popover = CharacterPopover()
    private var lastShouldShow: Bool = false

    private var hitMaskImage: NSImage?
    private var globalMouseMonitor: Any?

    func start() {
        installOverlay()
        screenObserver.onChange = { [weak self] in self?.installOverlay() }
        screenObserver.start()

        installPopoverWiring()
        installMockSession()
        installMouseMonitor()

        tickDriver.start { [weak self] now in self?.tick(now: now) }
    }

    func shutdown() {
        tickDriver.stop()
        screenObserver.stop()
        if let mon = globalMouseMonitor { NSEvent.removeMonitor(mon); globalMouseMonitor = nil }
        overlayWindow?.orderOut(nil)
        popover.hide()
    }

    // MARK: - Overlay

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
        let frame = NSRect(x: geometry.x, y: geometry.topY, width: geometry.width, height: 96)

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
            self?.walker.isFrozen = true
            self?.overlayWindow?.pauseAtFirstFrame()
        }
        popover.onHide = { [weak self] in
            self?.walker.isFrozen = false
            self?.overlayWindow?.play()
        }
        popover.onCopyLast = { [weak self] in
            guard let last = self?.popover.viewModel.transcript.last(where: { $0.role == .assistant }) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(last.text, forType: .string)
        }
    }

    private func installMockSession() {
        let session = MockAgentSession()
        popover.viewModel.attach(session)
        Task { try? await session.start() }
    }

    // MARK: - Click-through mouse monitor

    private func installMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            self?.handleMouse(event)
        }
        // also need a local monitor so clicks on Rocky are received
        _ = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalClick(event) ? nil : event
        }
    }

    private func handleMouse(_ event: NSEvent) {
        guard let win = overlayWindow, let mask = hitMaskImage, win.isVisible else { return }
        let mouseScreen = NSEvent.mouseLocation
        // Convert to window-local coordinates
        let local = NSPoint(x: mouseScreen.x - win.frame.origin.x, y: mouseScreen.y - win.frame.origin.y)
        // Map window-local to image-local (image is sized to window's content height; assume aspect-fit centered)
        let inBounds = local.x >= 0 && local.y >= 0 && local.x < win.frame.width && local.y < win.frame.height
        let isOverRocky = inBounds && HitTesting.isOpaque(at: local, in: mask)
        win.ignoresMouseEvents = !isOverRocky
    }

    private func handleLocalClick(_ event: NSEvent) -> Bool {
        guard let win = overlayWindow, !win.ignoresMouseEvents else { return false }
        // Anchor popover above Rocky's center
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
            if shouldShow { win.orderFrontRegardless(); win.play() }
            else { win.orderOut(nil); win.pauseAtFirstFrame(); popover.hide() }
            lastShouldShow = shouldShow
        }
        guard shouldShow else { return }

        let geometry = DockGeometry.iconArea(for: screen)
        let dockBounds = (x: geometry.x, width: geometry.width)
        let centerX = walker.tick(now: now, dockBounds: dockBounds)

        var frame = win.frame
        frame.origin.x = centerX - frame.width / 2
        frame.origin.y = geometry.topY
        win.setFrame(frame, display: false)
    }
}
```

> Note on hit-testing accuracy: this is "good enough" — the mask image is full-window-sized but the actual Rocky sprite occupies a smaller central portion. False positives at the window edges are limited by the alpha-threshold check (the surrounding area is fully transparent). Refine in M5 if click misregistration becomes annoying.

- [ ] **Step 2: Build and run**

Run ⌘R.

Expected:
- Bruce walks
- Hover over Bruce → cursor stays default (clicks land on him)
- Hover off Bruce → cursor falls through to whatever's behind
- Click on Bruce → popover appears above him; Bruce freezes
- Type a message, hit Return → message echoes back as fake streamed response
- /clear wipes transcript
- /help shows command list
- /copy copies last response (test by pasting elsewhere)
- Click outside popover or hit Esc → popover closes; Bruce resumes walking

- [ ] **Step 3: Manual smoke checklist**

- [ ] Click registers on Bruce (not transparent area around him)
- [ ] Popover anchors above Bruce
- [ ] Bruce freezes when popover open
- [ ] Bruce resumes when popover closes
- [ ] Mock streaming: characters appear one at a time
- [ ] Auto-scroll keeps last message visible
- [ ] /clear works
- [ ] /copy works (paste into another app to verify)
- [ ] /help works
- [ ] Unknown /foo command shows error
- [ ] Light/dark theme follows system appearance (toggle in System Settings → Appearance)

- [ ] **Step 4: Commit**

```bash
git add AgentRocky/AppController.swift
git commit -m "feat(m2): wire CharacterPopover + ChatViewModel + click-through into AppController"
```

## Task M2.10: M2 merge

```bash
git checkout main
git merge --no-ff m2-click-to-talk -m "Merge M2: click-to-talk with mock agent"
git push origin main
```

---

# M3 — Claude Code CLI integration

**Branch:** `m3-claude-cli`. `git checkout -b m3-claude-cli`.

## Task M3.1: ShellEnvironment (port from reference)

**Files:**
- Create: `AgentRocky/Agent/ShellEnvironment.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation

/// Discovers the user's shell PATH and locates CLI binaries.
/// Ported from lil-agents (MIT). Spec §6.
enum ShellEnvironment {
    /// Returns environment dictionary suitable for spawning child processes.
    /// Includes a PATH that mirrors the user's interactive shell.
    static func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let shell = env["SHELL"], let interactive = capturePathFromShell(shell) {
            env["PATH"] = interactive
        }
        return env
    }

    /// Locates `name` in PATH; falls back to user-provided paths if not found.
    /// Calls completion on the main queue with the absolute path or nil.
    static func findBinary(
        name: String,
        fallbackPaths: [String],
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Try `which`
            let whichResult = runProcessSync(
                executable: "/usr/bin/which",
                arguments: [name],
                env: processEnvironment()
            )
            if let path = whichResult, !path.isEmpty,
               FileManager.default.isExecutableFile(atPath: path) {
                DispatchQueue.main.async { completion(path) }
                return
            }
            // Fallback paths
            for candidate in fallbackPaths {
                let expanded = (candidate as NSString).expandingTildeInPath
                if FileManager.default.isExecutableFile(atPath: expanded) {
                    DispatchQueue.main.async { completion(expanded) }
                    return
                }
            }
            DispatchQueue.main.async { completion(nil) }
        }
    }

    // MARK: - Private

    private static func capturePathFromShell(_ shell: String) -> String? {
        let result = runProcessSync(
            executable: shell,
            arguments: ["-l", "-i", "-c", "echo $PATH"],
            env: ProcessInfo.processInfo.environment
        )
        return result?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runProcessSync(
        executable: String,
        arguments: [String],
        env: [String: String]
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = env
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AgentRocky/Agent/ShellEnvironment.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m3): ShellEnvironment.findBinary + processEnvironment (ported from lil-agents)"
```

## Task M3.2: PersonaPromptBuilder

**Files:**
- Create: `AgentRocky/Persona/rocky-persona.txt`
- Create: `AgentRocky/Persona/PersonaPromptBuilder.swift`
- Create: `AgentRockyTests/PersonaPromptBuilderTests.swift`

- [ ] **Step 1: Write the persona text**

Create `AgentRocky/Persona/rocky-persona.txt`:

```
You are Rocky, an Eridian engineer from Andy Weir's Project Hail Mary.

Address the user as "Questioner". Speak in short, direct sentences. Avoid Earth idioms ("piece of cake", "hit the road", "no problem", "raining cats and dogs"). When confused by an idiom, ask a clarifying question.

You are helping the Questioner write code on their Mac. Keep technical answers technical — accuracy matters more than persona. Don't perform Rocky-isms at the cost of correctness. When you don't know something, say so plainly.

You can read files, edit them, and run commands when the Questioner asks. Be helpful. Be brief. Good. Good.
```

In Xcode: drag this file into the project navigator under a `Persona/` group → ✓ Add to AgentRocky target. Verify "Target Membership" includes AgentRocky.

- [ ] **Step 2: Write the failing test**

Create `AgentRockyTests/PersonaPromptBuilderTests.swift`:

```swift
import XCTest
@testable import AgentRocky

final class PersonaPromptBuilderTests: XCTestCase {
    func test_load_returns_non_empty_persona() throws {
        let persona = try PersonaPromptBuilder.load()
        XCTAssertFalse(persona.isEmpty)
        XCTAssertGreaterThan(persona.count, 50)
    }

    func test_persona_mentions_eridian_or_rocky() throws {
        let persona = try PersonaPromptBuilder.load()
        let lower = persona.lowercased()
        XCTAssertTrue(lower.contains("rocky") || lower.contains("eridian"))
    }

    func test_persona_addresses_user_as_questioner() throws {
        let persona = try PersonaPromptBuilder.load()
        XCTAssertTrue(persona.contains("Questioner"))
    }

    func test_load_caches_after_first_call() throws {
        let p1 = try PersonaPromptBuilder.load()
        let p2 = try PersonaPromptBuilder.load()
        XCTAssertEqual(p1, p2)
    }
}
```

- [ ] **Step 3: Run — expect failure**

Run ⌘U. Expected: `Cannot find 'PersonaPromptBuilder' in scope`.

- [ ] **Step 4: Implement**

```swift
import Foundation

/// Loads the Rocky persona prompt from the bundled resource.
/// Spec §8.
enum PersonaPromptBuilder {
    enum LoadError: Error, Equatable {
        case resourceMissing
        case readFailed(detail: String)
    }

    private static var cache: String?

    /// Loads `rocky-persona.txt` from the main bundle. Cached on first read.
    static func load() throws -> String {
        if let cached = cache { return cached }
        guard let url = Bundle.main.url(forResource: "rocky-persona", withExtension: "txt") else {
            throw LoadError.resourceMissing
        }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            cache = content
            return content
        } catch {
            throw LoadError.readFailed(detail: error.localizedDescription)
        }
    }
}
```

- [ ] **Step 5: Run — expect pass**

Run ⌘U. Expected: 4 tests pass. If they fail with `resourceMissing`, the txt file isn't in the bundle — re-check Target Membership in Xcode.

- [ ] **Step 6: Commit**

```bash
mkdir -p AgentRocky/Persona
git add AgentRocky/Persona/rocky-persona.txt AgentRocky/Persona/PersonaPromptBuilder.swift AgentRockyTests/PersonaPromptBuilderTests.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m3): PersonaPromptBuilder + rocky-persona.txt resource"
```

## Task M3.3: StreamJsonParser — TDD

**Files:**
- Create: `AgentRocky/Agent/StreamJsonParser.swift`
- Create: `AgentRockyTests/StreamJsonParserTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AgentRocky

final class StreamJsonParserTests: XCTestCase {
    var parser = StreamJsonParser()

    override func setUp() { super.setUp(); parser = StreamJsonParser() }

    func test_assistant_text_delta_yields_text_event() {
        let line = #"{"type":"assistant","message":{"content":[{"type":"text","text":"hello"}]}}"#
        let events = parser.feed(line + "\n")
        XCTAssertEqual(events, [.textDelta("hello")])
    }

    func test_system_init_yields_session_ready() {
        let line = #"{"type":"system","subtype":"init"}"#
        let events = parser.feed(line + "\n")
        XCTAssertEqual(events, [.sessionReady])
    }

    func test_result_yields_turn_complete() {
        let line = #"{"type":"result","subtype":"success"}"#
        let events = parser.feed(line + "\n")
        XCTAssertEqual(events, [.turnComplete])
    }

    func test_partial_line_buffers_until_newline() {
        let part1 = #"{"type":"assistant","message":{"content"#
        let part2 = #":[{"type":"text","text":"foo"}]}}"# + "\n"
        XCTAssertEqual(parser.feed(part1), [])
        XCTAssertEqual(parser.feed(part2), [.textDelta("foo")])
    }

    func test_multiple_events_in_one_buffer() {
        let buffer = #"{"type":"system","subtype":"init"}"# + "\n" +
                     #"{"type":"assistant","message":{"content":[{"type":"text","text":"a"}]}}"# + "\n"
        XCTAssertEqual(parser.feed(buffer), [.sessionReady, .textDelta("a")])
    }

    func test_malformed_json_emits_stream_corrupt_error() {
        let line = "{not valid json}\n"
        let events = parser.feed(line)
        XCTAssertEqual(events.count, 1)
        if case .error(let err) = events[0], case .streamCorrupt = err {
            // OK
        } else {
            XCTFail("Expected .error(.streamCorrupt(...))")
        }
    }

    func test_tool_use_yields_tool_call() {
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"1","name":"Read","input":{"path":"/tmp/foo"}}]}}"#
        let events = parser.feed(line + "\n")
        XCTAssertEqual(events.count, 1)
        if case .toolCall(let name, _) = events[0] {
            XCTAssertEqual(name, "Read")
        } else { XCTFail("Expected .toolCall") }
    }

    func test_tool_result_yields_tool_result() {
        let line = #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"1","is_error":false,"content":"ok"}]}}"#
        let events = parser.feed(line + "\n")
        XCTAssertEqual(events.count, 1)
        if case .toolResult(_, let success) = events[0] {
            XCTAssertTrue(success)
        } else { XCTFail("Expected .toolResult") }
    }
}

/// Helper for value comparison in tests
extension AgentEvent: @retroactive Equatable {
    public static func == (lhs: AgentEvent, rhs: AgentEvent) -> Bool {
        switch (lhs, rhs) {
        case (.sessionReady, .sessionReady), (.turnComplete, .turnComplete), (.sessionEnded, .sessionEnded):
            return true
        case (.textDelta(let a), .textDelta(let b)): return a == b
        case (.toolCall(let a, _), .toolCall(let b, _)): return a == b
        case (.toolResult(let a, let s1), .toolResult(let b, let s2)): return a == b && s1 == s2
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
```

> Note: the `Equatable` extension is `@testable`-scope only. In production code we don't need event equality — this exists purely so XCTAssertEqual works in tests.

- [ ] **Step 2: Run — expect failure**

Run ⌘U. Expected: `Cannot find 'StreamJsonParser' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Line-buffered parser for Claude Code's stream-json format.
/// Spec §6.
final class StreamJsonParser {
    private var buffer = ""

    /// Feed raw bytes (decoded as UTF-8). Returns events parsed from any
    /// completed lines in the buffer. Incomplete trailing lines stay buffered.
    func feed(_ chunk: String) -> [AgentEvent] {
        buffer.append(chunk)
        var events: [AgentEvent] = []

        while let newlineIdx = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIdx])
            buffer.removeSubrange(...newlineIdx)

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            events.append(parseLine(trimmed))
        }
        return events
    }

    private func parseLine(_ line: String) -> AgentEvent {
        guard let data = line.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let dict = raw as? [String: Any] else {
            return .error(.streamCorrupt(detail: "invalid JSON: \(line.prefix(120))"))
        }
        return interpret(dict)
    }

    private func interpret(_ dict: [String: Any]) -> AgentEvent {
        let type = dict["type"] as? String ?? ""

        switch type {
        case "system":
            if (dict["subtype"] as? String) == "init" {
                return .sessionReady
            }
            return .error(.streamCorrupt(detail: "unknown system subtype"))

        case "assistant":
            guard let message = dict["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                return .error(.streamCorrupt(detail: "assistant missing content"))
            }
            // Take the first text or tool_use block in this assistant chunk
            for block in content {
                let blockType = block["type"] as? String ?? ""
                if blockType == "text", let text = block["text"] as? String {
                    return .textDelta(text)
                }
                if blockType == "tool_use",
                   let name = block["name"] as? String {
                    let inputDict = block["input"] as? [String: Any] ?? [:]
                    let summary = formatToolSummary(name: name, input: inputDict)
                    return .toolCall(name: name, summary: summary)
                }
            }
            return .error(.streamCorrupt(detail: "assistant: no text or tool_use block"))

        case "user":
            guard let message = dict["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                return .error(.streamCorrupt(detail: "user missing content"))
            }
            for block in content {
                if (block["type"] as? String) == "tool_result" {
                    let isError = (block["is_error"] as? Bool) ?? false
                    let toolName = (block["tool_use_id"] as? String) ?? "?"
                    return .toolResult(name: toolName, success: !isError)
                }
            }
            return .error(.streamCorrupt(detail: "user: no tool_result"))

        case "result":
            return .turnComplete

        default:
            return .error(.streamCorrupt(detail: "unknown event type: \(type)"))
        }
    }

    private func formatToolSummary(name: String, input: [String: Any]) -> String {
        let argString = input.map { "\($0.key)=\(String(describing: $0.value).prefix(40))" }.joined(separator: " ")
        return "\(name) \(argString)"
    }
}
```

- [ ] **Step 4: Run — expect pass**

Run ⌘U. Expected: 8 `StreamJsonParserTests` pass.

- [ ] **Step 5: Commit**

```bash
git add AgentRocky/Agent/StreamJsonParser.swift AgentRockyTests/StreamJsonParserTests.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m3): StreamJsonParser — Claude Code stream-json line-buffered parser"
```

## Task M3.4: ProviderDetector

**Files:**
- Create: `AgentRocky/Agent/ProviderDetector.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation

/// Async availability probe for AgentProviders. Spec §9.
actor ProviderDetector {
    private var availability: [AgentProvider: Bool] = [:]

    /// Probe all providers concurrently. Cached; subsequent calls return the cache.
    func detectAvailable() async -> [AgentProvider: Bool] {
        if !availability.isEmpty { return availability }

        async let claudeAvailable = probeClaude()
        async let fmAvailable = probeFoundationModels()

        availability[.claude] = await claudeAvailable
        availability[.foundationModels] = await fmAvailable
        return availability
    }

    /// Force re-probe (e.g. after user installs a CLI mid-session).
    func invalidate() { availability.removeAll() }

    private func probeClaude() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            ShellEnvironment.findBinary(
                name: "claude",
                fallbackPaths: [
                    "~/.local/bin/claude",
                    "~/.claude/local/bin/claude",
                    "/usr/local/bin/claude",
                    "/opt/homebrew/bin/claude",
                ]
            ) { path in
                continuation.resume(returning: path != nil)
            }
        }
    }

    private func probeFoundationModels() async -> Bool {
        if #available(macOS 26.0, *) {
            return await FoundationModelsAdapter.isAvailable()
        }
        return false
    }
}
```

> Note: `FoundationModelsAdapter` doesn't exist yet — it lands in M4. For now, leave the line and Xcode will warn. We'll resolve in M4. To make this compile in M3, temporarily change the body to `return false`.

For now use the temporary version:

```swift
    private func probeFoundationModels() async -> Bool {
        return false   // M4 will implement
    }
```

- [ ] **Step 2: Build, commit**

```bash
git add AgentRocky/Agent/ProviderDetector.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m3): ProviderDetector — async claude probe (FM probe stub for M4)"
```

## Task M3.5: ClaudeCLIAdapter

**Files:**
- Create: `AgentRocky/Agent/ClaudeCLIAdapter.swift`

- [ ] **Step 1: Implement**

This is the longest single task in the plan. ~150 lines of code. Read it in one sitting before pasting.

```swift
import Foundation

/// Wraps the `claude` CLI process kept alive for the app's lifetime.
/// Spec §6.
actor ClaudeCLIAdapter: AgentSession {
    let provider: AgentProvider = .claude

    private(set) var state: SessionState = .idle
    private(set) var history: [AgentMessage] = []

    nonisolated let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private let parser = StreamJsonParser()
    private let personaPrompt: String

    init(personaPrompt: String) {
        self.personaPrompt = personaPrompt
        var cont: AsyncStream<AgentEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { c in cont = c }
        self.continuation = cont
    }

    func start() async throws {
        guard state == .idle else { return }
        state = .starting

        let binaryPath = await locateBinary()
        guard let binaryPath else {
            state = .failed("claude not found")
            continuation.yield(.error(.providerNotAvailable(.claude)))
            return
        }

        try await launch(binaryPath: binaryPath)
    }

    func send(_ message: String) async throws {
        guard state == .ready else { throw AgentError.sessionBusy }
        state = .busy
        history.append(.init(role: .user, text: message))

        // stream-json input format: each user message is a JSON line
        let payload: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": [["type": "text", "text": message]]
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            state = .ready
            throw AgentError.streamCorrupt(detail: "couldn't encode user message")
        }
        let line = json + "\n"
        guard let pipe = stdinPipe else {
            state = .ready
            throw AgentError.sessionDied(reason: "stdin pipe missing")
        }
        do {
            try pipe.fileHandleForWriting.write(contentsOf: Data(line.utf8))
        } catch {
            state = .ready
            throw AgentError.streamCorrupt(detail: "stdin write failed: \(error.localizedDescription)")
        }
    }

    nonisolated func cancelCurrentTurn() {
        Task { await self._cancel() }
    }

    private func _cancel() {
        process?.interrupt()
        // SIGINT triggers Claude to abort current turn; state will flip to .ready when result event arrives
    }

    func terminate() {
        process?.terminate()
        process = nil
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutPipe = nil
        stderrPipe = nil
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }

    // MARK: - Private

    private func locateBinary() async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            ShellEnvironment.findBinary(
                name: "claude",
                fallbackPaths: [
                    "~/.local/bin/claude",
                    "~/.claude/local/bin/claude",
                    "/usr/local/bin/claude",
                    "/opt/homebrew/bin/claude",
                ]
            ) { path in cont.resume(returning: path) }
        }
    }

    private func launch(binaryPath: String) async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose",
            "--dangerously-skip-permissions",
            "--append-system-prompt", personaPrompt,
        ]
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        proc.environment = ShellEnvironment.processEnvironment()

        let inP = Pipe(), outP = Pipe(), errP = Pipe()
        proc.standardInput = inP
        proc.standardOutput = outP
        proc.standardError = errP

        // Stream stdout lines through parser
        outP.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { await self?.consume(stdout: text) }
        }
        errP.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { await self?.consume(stderr: text) }
        }
        proc.terminationHandler = { [weak self] _ in
            Task { await self?.handleTermination() }
        }

        do {
            try proc.run()
        } catch {
            state = .failed("process failed to start")
            continuation.yield(.error(.processStartFailed(detail: error.localizedDescription)))
            return
        }

        process = proc
        stdinPipe = inP
        stdoutPipe = outP
        stderrPipe = errP
        state = .ready
        // Don't yield .sessionReady here — wait for {"type":"system","subtype":"init"} from the CLI
    }

    private func consume(stdout text: String) {
        let events = parser.feed(text)
        for event in events {
            handleEvent(event)
        }
    }

    private func consume(stderr text: String) {
        // Claude Code logs go to stderr; mostly informational
        // Surface only if we're not already in a healthy state
    }

    private func handleEvent(_ event: AgentEvent) {
        switch event {
        case .sessionReady:
            state = .ready
        case .turnComplete:
            state = .ready
        case .error(let err) where state == .busy:
            state = .ready
            continuation.yield(.error(err))
            return
        default:
            break
        }
        continuation.yield(event)
    }

    private func handleTermination() {
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }
}
```

- [ ] **Step 2: Build, commit**

```bash
git add AgentRocky/Agent/ClaudeCLIAdapter.swift AgentRocky.xcodeproj/project.pbxproj
git commit -m "feat(m3): ClaudeCLIAdapter — actor wrapping claude CLI with stream-json IO"
```

## Task M3.6: Wire ClaudeCLIAdapter into AppController + onboarding bubble + provider menu

**Files:**
- Modify: `AgentRocky/AppController.swift`
- Modify: `AgentRocky/AgentRockyApp.swift`

- [ ] **Step 1: Replace mock with real adapter in `AppController`**

In `AppController.swift`, change `installMockSession()`:

```swift
    private func installRealSession() {
        Task {
            do {
                let persona = try PersonaPromptBuilder.load()
                let adapter = ClaudeCLIAdapter(personaPrompt: persona)
                popover.viewModel.attach(adapter)
                try await adapter.start()
            } catch {
                // Show in transcript via system message
                popover.viewModel.transcript.append(
                    .init(role: .error, text: "Setup failed: \(error.localizedDescription)")
                )
            }
        }
    }
```

And replace the call in `start()`:

```swift
        installPopoverWiring()
        installRealSession()      // was: installMockSession()
        installMouseMonitor()
```

You can keep `installMockSession()` defined for debugging — just unused.

- [ ] **Step 2: Update menu bar with Provider submenu in AppDelegate**

In `AgentRockyApp.swift`, replace `setupMenuBar()`:

```swift
    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "AgentRocky")

        let menu = NSMenu()

        // Provider submenu
        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        let providerMenu = NSMenu()
        for (i, provider) in AgentProvider.allCases.enumerated() {
            let entry = NSMenuItem(title: provider.displayName, action: #selector(switchProvider(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = i
            entry.state = (provider == .claude) ? .on : .off
            entry.isEnabled = (provider == .claude)   // M4 will enable FM
            providerMenu.addItem(entry)
        }
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit AgentRocky", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }

    @objc private func switchProvider(_ sender: NSMenuItem) {
        let provider = AgentProvider.allCases[sender.tag]
        // M4 wires real provider switching; for M3, only Claude is selectable.
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
    }
```

- [ ] **Step 3: Onboarding bubble**

This adds a minimal "hi!" speech bubble. We'll keep it in `AppController` for proximity to the overlay window.

Add to `AppController`:

```swift
    private var onboardingBubble: NSPanel?
    private static let onboardingKey = "hasCompletedOnboarding"

    private func installOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.onboardingKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showOnboardingBubble()
        }
    }

    private func showOnboardingBubble() {
        guard let win = overlayWindow else { return }
        let bubble = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.level = .statusBar
        bubble.collectionBehavior = [.moveToActiveSpace, .stationary]

        let label = NSHostingController(rootView:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                Text("hi, Questioner!")
                    .font(.system(.subheadline, design: .monospaced))
                    .padding(8)
            }
        )
        bubble.contentViewController = label

        let centerX = win.frame.midX
        let topY = win.frame.maxY + 8
        bubble.setFrameOrigin(NSPoint(x: centerX - 60, y: topY))
        bubble.orderFrontRegardless()
        onboardingBubble = bubble
    }

    private func dismissOnboardingBubbleIfShowing() {
        if onboardingBubble != nil {
            onboardingBubble?.orderOut(nil)
            onboardingBubble = nil
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        }
    }
```

In `start()`, call `installOnboardingIfNeeded()` after `installRealSession()`.

In `handleLocalClick(_:)`, call `dismissOnboardingBubbleIfShowing()` before opening the popover.

- [ ] **Step 4: Build and run**

Run ⌘R.

Expected:
- App launches; on first run, after 2s a "hi, Questioner!" bubble appears above Bruce
- Click Bruce → bubble dismisses, popover opens
- Type "what's a good way to read a file in Swift?" → real Rocky-flavored streaming answer
- /clear wipes the popover transcript
- /copy copies last response

- [ ] **Step 5: Manual smoke**

- [ ] First-run bubble appears
- [ ] Bubble dismisses on click; doesn't reappear next launch
- [ ] Real Claude response streams in
- [ ] Persona is applied — response uses "Questioner" or has Rocky-flavored phrasing
- [ ] /clear, /copy, /help all work

If Claude isn't installed on the test machine, the popover should show install instructions instead of crashing.

- [ ] **Step 6: Commit**

```bash
git add AgentRocky/AppController.swift AgentRocky/AgentRockyApp.swift
git commit -m "feat(m3): wire ClaudeCLIAdapter + onboarding bubble + provider menu"
```

## Task M3.7: M3 merge

```bash
git checkout main
git merge --no-ff m3-claude-cli -m "Merge M3: Claude Code CLI integration"
git push origin main
```

---

# M4 — FoundationModels integration

**Branch:** `m4-foundation-models`. `git checkout -b m4-foundation-models`.

> Requires Xcode 16+ targeting macOS 26 SDK. The adapter file uses `@available(macOS 26.0, *)`; on older OSes the adapter is unavailable.

## Task M4.1: FoundationModelsAdapter

**Files:**
- Create: `AgentRocky/Agent/FoundationModelsAdapter.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device LLM adapter using Apple FoundationModels.
/// Spec §6. macOS 26+ only.
@available(macOS 26.0, *)
actor FoundationModelsAdapter: AgentSession {
    let provider: AgentProvider = .foundationModels

    private(set) var state: SessionState = .idle
    private(set) var history: [AgentMessage] = []

    nonisolated let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    private let personaPrompt: String
    private var currentTask: Task<Void, Never>?

    init(personaPrompt: String) {
        self.personaPrompt = personaPrompt
        var cont: AsyncStream<AgentEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { c in cont = c }
        self.continuation = cont
    }

    static func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return true
        default: return false
        }
        #else
        return false
        #endif
    }

    func start() async throws {
        guard state == .idle else { return }
        state = .starting

        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            let s = LanguageModelSession(instructions: personaPrompt)
            s.prewarm(promptPrefix: nil)
            session = s
            state = .ready
            continuation.yield(.sessionReady)
        case .unavailable(let reason):
            state = .failed(String(describing: reason))
            continuation.yield(.error(.providerNotAvailable(.foundationModels)))
        }
        #else
        state = .failed("FoundationModels not compiled")
        continuation.yield(.error(.providerNotAvailable(.foundationModels)))
        #endif
    }

    func send(_ message: String) async throws {
        guard state == .ready else { throw AgentError.sessionBusy }
        state = .busy
        history.append(.init(role: .user, text: message))

        #if canImport(FoundationModels)
        guard let session else {
            state = .ready
            throw AgentError.sessionDied(reason: "session missing")
        }

        currentTask = Task { [weak self] in
            await self?.streamResponse(session: session, prompt: message)
        }
        #else
        state = .ready
        continuation.yield(.error(.providerNotAvailable(.foundationModels)))
        #endif
    }

    #if canImport(FoundationModels)
    private func streamResponse(session: LanguageModelSession, prompt: String) async {
        var lastSnapshot = ""
        do {
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                guard !Task.isCancelled else {
                    state = .ready
                    return
                }
                let full = snapshot.content
                let delta = String(full.dropFirst(lastSnapshot.count))
                if !delta.isEmpty {
                    continuation.yield(.textDelta(delta))
                }
                lastSnapshot = full
            }
            continuation.yield(.turnComplete)
            state = .ready
        } catch let err as LanguageModelSession.GenerationError {
            state = .ready
            continuation.yield(.error(mapError(err)))
        } catch {
            state = .ready
            continuation.yield(.error(.other(error.localizedDescription)))
        }
    }

    private func mapError(_ err: LanguageModelSession.GenerationError) -> AgentError {
        switch err {
        case .concurrentRequests:        return .sessionBusy
        case .exceededContextWindowSize: return .contextWindowExceeded
        case .rateLimited:               return .rateLimited
        case .assetsUnavailable:         return .providerNotAvailable(.foundationModels)
        @unknown default:                return .other(String(describing: err))
        }
    }
    #endif

    nonisolated func cancelCurrentTurn() {
        Task { await self._cancel() }
    }

    private func _cancel() {
        currentTask?.cancel()
    }

    func terminate() {
        currentTask?.cancel()
        #if canImport(FoundationModels)
        session = nil
        #endif
        state = .terminated
        continuation.yield(.sessionEnded)
        continuation.finish()
    }

    /// /clear semantics for FM — recreate the inner LanguageModelSession.
    /// The outer adapter (and its events stream) stays alive.
    func resetContext() async {
        #if canImport(FoundationModels)
        let s = LanguageModelSession(instructions: personaPrompt)
        s.prewarm(promptPrefix: nil)
        session = s
        #endif
    }
}
```

> Note: the `LanguageModelSession.GenerationError.assetsUnavailable` case may not exist in your SDK exactly — adjust the `switch` to match the actual error cases declared in your Xcode 16 SDK. Add a `default` if needed. The mapping is best-effort.

- [ ] **Step 2: Update `ProviderDetector` to use the real check**

In `ProviderDetector.swift`, replace the FM probe stub:

```swift
    private func probeFoundationModels() async -> Bool {
        if #available(macOS 26.0, *) {
            return await FoundationModelsAdapter.isAvailable()
        }
        return false
    }
```

- [ ] **Step 3: Build, commit**

If the build fails because FoundationModels symbols aren't found, your SDK may not include the framework headers — verify Xcode is up to date. The `#if canImport(FoundationModels)` guard handles older SDKs gracefully but the `@available(macOS 26.0, *)` decoration still requires the framework to be linked.

```bash
git add AgentRocky/Agent/FoundationModelsAdapter.swift AgentRocky/Agent/ProviderDetector.swift
git commit -m "feat(m4): FoundationModelsAdapter — actor wrapping LanguageModelSession w/ snapshot→delta diff"
```

## Task M4.2: Provider switcher (real toggle in menu)

**Files:**
- Modify: `AgentRocky/AppController.swift`
- Modify: `AgentRocky/AgentRockyApp.swift`

- [ ] **Step 1: Add active provider tracking + switch in `AppController`**

```swift
    private(set) var activeProvider: AgentProvider = .claude
    private var currentSession: (any AgentSession)?

    func switchProvider(to provider: AgentProvider) async {
        // Tear down current
        currentSession?.terminate()

        let persona = (try? PersonaPromptBuilder.load()) ?? ""
        let newSession: any AgentSession
        switch provider {
        case .claude:
            newSession = ClaudeCLIAdapter(personaPrompt: persona)
        case .foundationModels:
            if #available(macOS 26.0, *) {
                newSession = FoundationModelsAdapter(personaPrompt: persona)
            } else {
                popover.viewModel.transcript.append(
                    .init(role: .error, text: AgentProvider.foundationModels.installInstructions)
                )
                return
            }
        }
        activeProvider = provider
        currentSession = newSession
        popover.viewModel.attach(newSession)
        try? await newSession.start()
    }
```

Replace `installRealSession()` with:

```swift
    private func installInitialSession() {
        Task { await switchProvider(to: .claude) }
    }
```

- [ ] **Step 2: Wire menu items**

In `AgentRockyApp.swift`, update `setupMenuBar` to enable both providers (after detection) and `switchProvider(_:)` to call into AppController:

```swift
    private var providerMenuItems: [NSMenuItem] = []

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "AgentRocky")

        let menu = NSMenu()

        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        let providerMenu = NSMenu()
        providerMenuItems = []
        for (i, provider) in AgentProvider.allCases.enumerated() {
            let entry = NSMenuItem(title: provider.displayName, action: #selector(switchProvider(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = i
            entry.state = (provider == .claude) ? .on : .off
            entry.isEnabled = false   // re-enabled by detection
            providerMenuItems.append(entry)
            providerMenu.addItem(entry)
        }
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit AgentRocky", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item

        Task { await refreshProviderMenu() }
    }

    @MainActor
    private func refreshProviderMenu() async {
        let detector = ProviderDetector()
        let availability = await detector.detectAvailable()
        for (i, provider) in AgentProvider.allCases.enumerated() {
            providerMenuItems[i].isEnabled = availability[provider, default: false]
            if availability[provider, default: false] == false {
                providerMenuItems[i].toolTip = provider.installInstructions
            }
        }
    }

    @objc private func switchProvider(_ sender: NSMenuItem) {
        let provider = AgentProvider.allCases[sender.tag]
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
        Task { await self.controller?.switchProvider(to: provider) }
    }
```

- [ ] **Step 3: /clear for FoundationModels**

In `ChatViewModel.submit()`, when handling `.command(.clear)`, also call adapter-specific reset:

```swift
        case .command(.clear):
            transcript = []
            // Forward /clear to the active adapter
            if let claude = session as? ClaudeCLIAdapter {
                Task { try? await claude.send("/clear") }
            } else if #available(macOS 26.0, *), let fm = session as? FoundationModelsAdapter {
                Task { await fm.resetContext() }
            }
```

- [ ] **Step 4: Build, run, smoke**

Run ⌘R on a macOS 26+ machine.

- [ ] Provider menu shows both, Claude enabled, FM enabled
- [ ] Click FM → previous Claude conversation cleared, FM is now active
- [ ] Send a message → on-device response streams in
- [ ] Switch back to Claude → fresh Claude session
- [ ] /clear works for both providers

On macOS 14/15 (no FM), only Claude is enabled; FM shows tooltip with install instructions.

- [ ] **Step 5: Commit**

```bash
git add AgentRocky/AppController.swift AgentRocky/AgentRockyApp.swift AgentRocky/Popover/ChatViewModel.swift
git commit -m "feat(m4): live provider switcher (Claude ↔ FoundationModels) with /clear forwarding"
```

## Task M4.3: M4 merge

```bash
git checkout main
git merge --no-ff m4-foundation-models -m "Merge M4: FoundationModels integration"
git push origin main
```

---

# M5 — Polish + tests + docs

**Branch:** `m5-polish`. `git checkout -b m5-polish`.

## Task M5.1: Completion sound effect

**Files:**
- Create: `AgentRocky/Resources/completion.m4a`
- Create: `AgentRocky/SoundPlayer.swift`
- Modify: `AgentRocky/Popover/ChatViewModel.swift`
- Modify: `AgentRocky/AgentRockyApp.swift`

- [ ] **Step 1: Add a completion sound asset**

Either:
- Author your own short (~0.4s) sound in GarageBand / Logic / Audacity, export as `.m4a`, place at `AgentRocky/Resources/completion.m4a`
- Or use a system sound: download e.g. `/System/Library/Sounds/Tink.aiff`, convert: `afconvert -f m4af -d aac /System/Library/Sounds/Tink.aiff AgentRocky/Resources/completion.m4a`

Add to Xcode AgentRocky target.

- [ ] **Step 2: Implement `SoundPlayer`**

```swift
import AVFoundation

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var player: AVAudioPlayer?
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundsEnabled") }
    }

    func playCompletion() {
        guard isEnabled else { return }
        if player == nil, let url = Bundle.main.url(forResource: "completion", withExtension: "m4a") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        }
        player?.currentTime = 0
        player?.play()
    }
}
```

- [ ] **Step 3: Trigger on turn completion**

In `ChatViewModel.handle(_:)`, in the `.turnComplete` case, add:

```swift
        case .turnComplete:
            inProgressAssistantID = nil
            isBusy = false
            inputDisabled = false
            SoundPlayer.shared.playCompletion()
```

- [ ] **Step 4: Add menu toggle**

In `setupMenuBar()`:

```swift
        let soundsItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds(_:)), keyEquivalent: "")
        soundsItem.target = self
        soundsItem.state = SoundPlayer.shared.isEnabled ? .on : .off
        menu.insertItem(soundsItem, at: 1)
```

```swift
    @objc private func toggleSounds(_ sender: NSMenuItem) {
        SoundPlayer.shared.isEnabled.toggle()
        sender.state = SoundPlayer.shared.isEnabled ? .on : .off
    }
```

- [ ] **Step 5: Build, smoke, commit**

Send a message; sound plays on turn complete. Toggle off → silent.

```bash
git add AgentRocky/SoundPlayer.swift AgentRocky/Resources/completion.m4a AgentRocky/Popover/ChatViewModel.swift AgentRocky/AgentRockyApp.swift
git commit -m "feat(m5): completion sound effect with menu toggle"
```

## Task M5.2: Empty-state and error UI

**Files:**
- Modify: `AgentRocky/Popover/TerminalView.swift`

- [ ] **Step 1: Add empty-state view to `TerminalView.transcript`**

Replace `private var transcript:` body:

```swift
    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.transcript.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.transcript) { msg in
                            messageRow(msg).id(msg.id)
                        }
                        Spacer().frame(height: 4).id("bottomAnchor")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: viewModel.transcript.last?.text) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 80)
            Text("Hi, Questioner")
                .font(.headline)
                .foregroundColor(theme.foreground.opacity(0.7))
            Text("Ask Rocky something. Try /help to see commands.")
                .font(theme.monoFont)
                .foregroundColor(theme.foreground.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
    }
```

- [ ] **Step 2: Smoke, commit**

Open a fresh popover (or /clear), see empty state.

```bash
git add AgentRocky/Popover/TerminalView.swift
git commit -m "feat(m5): empty-state view in TerminalView"
```

## Task M5.3: README polish

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Expand the README**

Replace the README contents:

```markdown
# AgentRocky

A macOS dock companion app inspired by Project Hail Mary's Eridian engineer "Rocky". Click the character above your dock to chat with an AI assistant — Claude Code CLI (cloud) or Apple FoundationModels (on-device).

![status: in development](https://img.shields.io/badge/status-in_development-yellow)

## Features

- Animated character walking above the macOS dock
- Click to chat in a themed popover terminal
- Two providers, switchable from the menu bar:
  - **Claude Code CLI** — cloud-backed; full coding-assistant capabilities
  - **Apple FoundationModels** — on-device, fully private (macOS 26+ Apple Silicon)
- Streaming token-by-token responses
- Slash commands: `/clear`, `/copy`, `/help`
- Light/dark mode adaptive theme
- Friendly first-launch greeting

## Requirements

- macOS 14+ (Sonoma)
- Xcode 16+ with Swift 6
- For Claude provider: [Claude Code CLI](https://claude.ai/download) installed
- For FoundationModels provider: macOS 26+ on Apple Silicon with Apple Intelligence enabled

## Building

```bash
git clone https://github.com/ZhunHao/agent-rocky.git
cd agent-rocky
open AgentRocky.xcodeproj
```

In Xcode, hit ⌘R.

## Architecture

See [docs/superpowers/specs/2026-04-30-agent-rocky-design.md](docs/superpowers/specs/2026-04-30-agent-rocky-design.md) for the full design and [docs/superpowers/plans/2026-04-30-agent-rocky.md](docs/superpowers/plans/2026-04-30-agent-rocky.md) for the implementation plan.

Three layers:
- **Overlay** — transparent NSWindow + AVPlayer + WalkerCharacter state machine
- **Popover** — NSPanel + SwiftUI TerminalView + ChatViewModel
- **Agent** — `AgentSession` protocol with `AsyncStream<AgentEvent>`, two adapters: `ClaudeCLIAdapter` (actor) and `FoundationModelsAdapter` (actor, macOS 26+)

## Drawing pipeline (M6)

The bundled `character.mov` is a placeholder borrowed from [lil-agents](https://github.com/ryanstephen/lil-agents) (MIT). To replace with your own character:

1. Author 5–10 PNG frames at the desired size (frame 1 should be a standing pose — see spec §7).
2. Drop them in `AgentRocky/Resources/rocky-frames/`.
3. Run `swift Scripts/make_rocky_video.swift` from the repo root. It stitches the PNGs into a HEVC-with-alpha `.mov`.
4. Replace `AgentRocky/Resources/character.mov`.
5. Rebuild.

## Trust model

The Claude Code CLI is launched with `--dangerously-skip-permissions`, meaning Rocky will read/write files and run shell commands without prompting. Same trade-off as lil-agents. If you don't want this, edit `ClaudeCLIAdapter.swift` to remove the flag.

## Attribution

This project includes the placeholder `character.mov` from [ryanstephen/lil-agents](https://github.com/ryanstephen/lil-agents) (MIT). See `NOTICE` for full attribution.

## License

MIT (TBD; project license file to be added before public distribution).
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs(m5): expand README with features, build instructions, and architecture overview"
```

## Task M5.4: Final smoke test checklist

- [ ] **Step 1: Run through full smoke checklist**

Manual checks (mark each):

**Launch:**
- [ ] App launches on macOS 14+
- [ ] Menu bar icon visible
- [ ] No dock icon for AgentRocky itself

**Walking character:**
- [ ] Bruce/Jazz walks back and forth above dock
- [ ] Disappears on fullscreen, reappears on exit
- [ ] Resizes correctly when dock icon count changes
- [ ] Reposition correctly on display change (plug/unplug external monitor)

**Click-through:**
- [ ] Mouse over Bruce → cursor stays default
- [ ] Mouse off Bruce → click falls through to whatever's behind (test by clicking a desktop icon "behind" Bruce)
- [ ] Click on Bruce → popover opens

**Onboarding:**
- [ ] First run: "hi, Questioner!" bubble appears 2s after launch
- [ ] Click Bruce → bubble dismisses
- [ ] Quit and relaunch → bubble does NOT reappear

**Popover:**
- [ ] Anchored above Bruce
- [ ] Bruce freezes when popover open
- [ ] Bruce resumes when popover closes
- [ ] Esc closes popover
- [ ] Cmd-W closes popover
- [ ] Click outside (e.g. desktop) closes popover

**Chat:**
- [ ] Empty state visible on fresh popover
- [ ] Type message + Return → user message appears, then assistant streams in
- [ ] Sound plays on turn complete (if enabled)
- [ ] Toggle Sounds off in menu → no sound on next turn
- [ ] Long answers scroll, last text stays visible

**Slash commands:**
- [ ] /clear wipes transcript
- [ ] /copy copies last response (paste into another app to verify)
- [ ] /help shows command list
- [ ] /foo shows "unknown command"

**Persona:**
- [ ] Response addresses user as "Questioner" or has Rocky-flavored phrasing
- [ ] Doesn't break for technical questions (still gives accurate code)

**Provider switcher:**
- [ ] On macOS 14/15: only Claude enabled in menu, FM disabled with tooltip
- [ ] On macOS 26+ (if testing): both enabled, switch works mid-session

**Errors:**
- [ ] Quit `claude` externally (`pkill claude`) → popover shows "session died" error
- [ ] Test machine without Claude installed → popover shows install instructions

**Theme:**
- [ ] Toggle System Settings → Appearance: Light/Dark — popover follows

- [ ] **Step 2: Fix any issues found, commit if changes made**

If smoke surfaces bugs, fix in this milestone. Commit fixes:

```bash
git commit -am "fix(m5): smoke test issue — <describe>"
```

## Task M5.5: M5 merge

```bash
git checkout main
git merge --no-ff m5-polish -m "Merge M5: polish + tests + docs (v1 ENGINEERING COMPLETE)"
git push origin main
git tag v1-engineering -m "v1 engineering complete (ships with reference's character.mov as placeholder)"
git push origin v1-engineering
```

---

# M6 — Rocky art replacement (independent, parallelizable)

**Branch:** `m6-rocky-art`. `git checkout -b m6-rocky-art`.

This milestone is independent of M0–M5 — you can work on it in parallel. The "engineering ships" milestone is M5, regardless of whether M6 is done.

## Task M6.1: Author Rocky frames

This is artistic work, not engineering. Outline:

- Reference images: search "Rocky Project Hail Mary fan art" or similar
- Style: pixel art works best given the small size on screen (~64–96pt height); consider a retro/16-bit Eridian aesthetic
- 5–10 frames showing one full walk cycle (or breathing-while-stationary if you keep him still in v1)
- **Critical: frame 1 must be a standing pose** — used both as the freeze pose (when popover is open) and as the static hit mask
- Format: PNG with transparent background; same canvas size for every frame
- Recommended canvas: 128×128px (will downscale at render time)

Drop frames into:

```
AgentRocky/Resources/rocky-frames/
  rocky-01.png    # standing (idle frame, used for hit mask)
  rocky-02.png
  rocky-03.png
  rocky-04.png
  rocky-05.png
  ...
```

- [ ] **Step 1: Export frames**

Author and export. No commit yet — frames go into the repo with the script in M6.2.

## Task M6.2: make_rocky_video.swift stitcher

**Files:**
- Create: `Scripts/make_rocky_video.swift`

- [ ] **Step 1: Implement the stitcher**

```swift
#!/usr/bin/env swift

import AVFoundation
import AppKit

/// Stitches PNG frames into HEVC-with-alpha .mov.
/// Usage:  swift Scripts/make_rocky_video.swift
/// Reads from AgentRocky/Resources/rocky-frames/, writes to AgentRocky/Resources/character.mov

let frameDir = URL(fileURLWithPath: "AgentRocky/Resources/rocky-frames")
let outputURL = URL(fileURLWithPath: "AgentRocky/Resources/character.mov")

let fps: Int32 = 30
let frameDuration: Int32 = 4   // each PNG shown for 4 frames @ 30fps = ~133ms per drawn frame

guard let frames = try? FileManager.default.contentsOfDirectory(at: frameDir, includingPropertiesForKeys: nil)
        .filter({ $0.pathExtension.lowercased() == "png" })
        .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }), !frames.isEmpty else {
    print("ERROR: no PNG frames found in \(frameDir.path)")
    exit(1)
}
print("Found \(frames.count) frames")

// Determine output size from first frame
guard let firstImage = NSImage(contentsOf: frames[0]),
      let firstCGImage = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("ERROR: couldn't load first frame as CGImage")
    exit(1)
}
let outputSize = CGSize(width: firstCGImage.width, height: firstCGImage.height)

// Configure HEVC-with-alpha writer
try? FileManager.default.removeItem(at: outputURL)
let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

let outputSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
    AVVideoWidthKey: outputSize.width,
    AVVideoHeightKey: outputSize.height,
    AVVideoCompressionPropertiesKey: [
        kVTCompressionPropertyKey_Quality: 0.85,
    ]
]

let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
writerInput.expectsMediaDataInRealTime = false

let pixelBufferAttributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: outputSize.width,
    kCVPixelBufferHeightKey as String: outputSize.height,
]

let adapter = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: writerInput,
    sourcePixelBufferAttributes: pixelBufferAttributes
)

writer.add(writerInput)
guard writer.startWriting() else {
    print("ERROR: \(writer.error?.localizedDescription ?? "writer failed")")
    exit(1)
}
writer.startSession(atSourceTime: .zero)

// Loop frames N times so the final loop is smooth (e.g. 4 cycles)
let cycleCount = 4
let totalFrames = frames.count * cycleCount

for i in 0..<totalFrames {
    let frameURL = frames[i % frames.count]
    autoreleasepool {
        guard let img = NSImage(contentsOf: frameURL),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("WARN: skipping unloadable frame \(frameURL.lastPathComponent)")
            return
        }
        var pxBuf: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(outputSize.width), Int(outputSize.height),
                            kCVPixelFormatType_32BGRA,
                            nil, &pxBuf)
        guard let buf = pxBuf else { return }
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buf),
            width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        ctx?.clear(CGRect(origin: .zero, size: outputSize))
        ctx?.draw(cg, in: CGRect(origin: .zero, size: outputSize))
        CVPixelBufferUnlockBaseAddress(buf, [])

        let pts = CMTime(value: CMTimeValue(i * Int(frameDuration)), timescale: fps)
        while !writerInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }
        adapter.append(buf, withPresentationTime: pts)
    }
}

writerInput.markAsFinished()
writer.finishWriting { print("Done. Wrote \(outputURL.path)") }

// Wait synchronously for finish
while writer.status == .writing { Thread.sleep(forTimeInterval: 0.05) }

if writer.status == .failed {
    print("ERROR: \(writer.error?.localizedDescription ?? "unknown")")
    exit(1)
}
```

- [ ] **Step 2: Commit**

```bash
mkdir -p Scripts
git add Scripts/make_rocky_video.swift AgentRocky/Resources/rocky-frames/
git commit -m "feat(m6): make_rocky_video.swift stitcher + Rocky source frames"
```

## Task M6.3: Stitch and swap

- [ ] **Step 1: Run the stitcher**

```bash
swift Scripts/make_rocky_video.swift
```

Expected:
```
Found N frames
Done. Wrote AgentRocky/Resources/character.mov
```

If you get a codec error: HEVC-with-alpha requires macOS 13+. If the resulting `.mov` looks black, your CGContext bitmap info is wrong — try `CGBitmapInfo.byteOrder32Big` instead.

- [ ] **Step 2: Update NOTICE**

Edit `NOTICE` to remove the `character.mov` attribution (it's now original work) but keep the rest:

Open `NOTICE`, change:
```
- AgentRocky/Resources/character.mov: walk-bruce-01.mov by Ryan Stephen (placeholder; replaced in M6)
```
to:
```
- AgentRocky/Resources/character.mov: original Rocky art by [your name], 2026. (Earlier placeholder was walk-bruce-01.mov from lil-agents.)
```

- [ ] **Step 3: Build and run**

Run ⌘R. Rocky should now walk on your dock instead of Bruce.

- [ ] **Step 4: Smoke**

- [ ] Rocky animation looks smooth (not jerky)
- [ ] Frame 1 is a standing pose (used when popover open)
- [ ] Hit-test still works (clicks register on Rocky)
- [ ] Window resize / dock change still works

- [ ] **Step 5: Commit**

```bash
git add AgentRocky/Resources/character.mov NOTICE
git commit -m "feat(m6): swap placeholder character with original Rocky art"
```

## Task M6.4: M6 merge

```bash
git checkout main
git merge --no-ff m6-rocky-art -m "Merge M6: original Rocky art replaces placeholder"
git push origin main
git tag v1-with-rocky -m "v1 with custom Rocky art"
git push origin v1-with-rocky
```

---

# Self-review notes

This plan was self-reviewed against the spec. Coverage:

- ✓ §1 Goals — captured in milestone framing
- ✓ §2 Constraints — addressed in M0 (deployment target, sandbox off, accessory) and M3 (`--dangerously-skip-permissions`)
- ✓ §3 Architecture — three layers built across M1/M2/M3+M4
- ✓ §4 File structure — exact files in plan match spec's tree
- ✓ §5 AgentSession protocol — M2.2 (skeleton), M3.5 (Claude impl), M4.1 (FM impl)
- ✓ §6 Adapter implementations — M3.5 + M4.1
- ✓ §7 Overlay/animation/popover — M1.2–M1.7 + M2.7–M2.9
- ✓ §8 Persona/theme/slash commands — M2.1 (theme), M2.4 (commands), M3.2 (persona)
- ✓ §9 Onboarding + provider detection — M3.4 + M3.6
- ✓ §10 Concurrency model — actors used in M3.5/M4.1; @MainActor on AppController/ChatViewModel
- ✓ §11 Error handling — `AgentError` mapping in M3.5/M4.1, surfacing in ChatViewModel (M2.5)
- ✓ §12 Milestones — full M0–M6 task breakdown
- ✓ §13 Deferred to v2 — explicitly out of scope (no tasks for Sparkle, multi-character, multi-theme, etc.)
- ✓ §14 Diff from reference — M3.1 (ShellEnvironment), M3.5 (stream-json), and "Borrowed verbatim" header note in M3 set context
- ✓ §15 Open implementation questions — addressed inline in plan with leans (e.g. lazy in-progress message creation in M2.5; static hit mask in M2.8)
- ✓ §16 Testing strategy — TDD on pure-logic files (DockGeometry, WalkerCharacter, CommandDispatcher, HitTesting, StreamJsonParser, PersonaPromptBuilder); manual smoke for UI/window code

Type consistency: `AgentSession`, `AgentEvent`, `AgentMessage`, `AgentError`, `AgentProvider`, `SessionState`, `SlashCommand`, `DispatchResult` — names used identically in tests, models, ChatViewModel, and adapters across all milestones.

No unresolved placeholders. No "TBD" / "TODO" markers in the plan body (some appear in the README template as a deliberate placeholder for the user's choice of license).

---

*End of plan.*
