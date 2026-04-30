---
title: AgentRocky — Design
date: 2026-04-30
status: Draft (pending user review)
project: agent-rocky
related_reference: https://github.com/ryanstephen/lil-agents (MIT)
---

# AgentRocky — Design

A macOS desktop companion app: a Project-Hail-Mary-inspired Eridian character ("Rocky") who lives on the dock, walks back and forth above your icons, and opens a chat popover when clicked. Backed by either Claude Code CLI (cloud) or Apple FoundationModels (on-device).

Inspired by [lil-agents](https://github.com/ryanstephen/lil-agents); built from scratch with modern Swift idioms, FoundationModels support, and a Rocky persona layer.

---

## 1. Goal & non-goals

### Goal

Two co-equal goals (per Q1: "both, equal weight"):

1. **Learn Swift / SwiftUI / macOS app development idiomatically.** Modern concurrency (`actor`, `AsyncStream`, structured concurrency), `@Observable` ViewModels, AppKit interop, AVFoundation video, transparent windows, dock geometry, hit-testing.
2. **Ship an agent the author actually uses daily.** Click the character, ask a coding question, get a Rocky-flavored (persona) streamed answer from either Claude Code CLI or Apple FoundationModels.

### Asset / shipping strategy

Engineering and art are **decoupled milestones**:

- **M0–M5 (engineering v1)** ships with the reference repo's character art (Bruce/Jazz `.mov`) as a placeholder — fully functional product, visually identical to lil-agents for the character.
- **M6 (Rocky art replacement)** swaps the placeholder with custom-drawn Rocky frames. Independent of engineering — can run in parallel or serial.

Rocky's *persona* (voice, system prompt, addressing the user as "Questioner") ships in M3 — present from the first real CLI integration onward, regardless of which character art is rendering.

### Non-goals (v1)

- Multi-character (only Rocky in v1; architecture supports more)
- Multi-monitor / display picker (main display only)
- Multi-theme (one Eridian theme; protocol supports more)
- Tool-call inspection UI (tool calls surface as plain text in v1)
- Persistent conversation across app launches
- App distribution (Sparkle / notarized DMG / App Store)
- Personality post-processing or voice consistency enforcement beyond a single system prompt

### Timeline

4–8 weekends. Most-likely path: **5 weekends**.

---

## 2. Constraints

- **Platform:** macOS 14+ (Sonoma). Deployment target stays at 14 even though FoundationModels requires macOS 26 — FoundationModels code is gated behind `#available(macOS 26.0, *)` and the adapter advertises itself as unavailable on older OSes.
- **Architecture:** Universal (Apple Silicon + Intel). Apple Silicon required to actually run FoundationModels.
- **Distribution model (v1):** Build-and-run from Xcode. No installer, no notarization, no Sparkle. v2 graduation to notarized DMG + Sparkle.
- **App lifecycle:** `NSApplicationActivationPolicy.accessory` — menu bar only, no dock icon for the app itself.
- **Sandbox:** Disabled in v1 (we shell out to `claude` and read `com.apple.dock` system prefs). Sandboxing is v2 work.
- **Trust model:** Claude Code CLI launched with `--dangerously-skip-permissions` (Rocky reads/writes files and runs commands without prompting). Same trust trade-off as the reference. Documented in README.
- **Drawing pipeline:** HEVC w/ alpha `.mov` (Q7). Author Rocky frames as PNGs → stitch via `Scripts/make_rocky_video.swift` → bundle. Source PNGs committed to repo for re-stitching.
- **Character asset for v1 = reference's Bruce (or Jazz) `.mov`** as placeholder. The drawing of Rocky's own frames is deferred to a dedicated post-engineering milestone (M6). This decouples engineering risk from artistic-iteration time. The reference repo (`ryanstephen/lil-agents`) is MIT-licensed; we include attribution in `README.md` + a `NOTICE` file. Replace with custom Rocky bytes in M6 — the bundled filename stays `character.mov` so no code changes are needed during the swap.

---

## 3. Architecture overview

Three coordinated subsystems plus cross-cutting helpers.

```
┌────────────────────────────────────────────────────────────────────┐
│                     AgentRockyApp (@main)                          │
│                       ↓ AppDelegate                                │
│                       ↓ AppController                              │
│                                                                    │
│   ┌─────────────────┐    ┌─────────────────┐   ┌────────────────┐ │
│   │ Overlay layer   │    │ Popover layer   │   │ Agent layer    │ │
│   │                 │    │                 │   │                │ │
│   │ Transparent     │    │ NSPanel         │   │ AgentSession   │ │
│   │ NSWindow        │◄──►│ anchored above  │◄─►│ protocol       │ │
│   │ AVPlayerLayer   │click│ Rocky's X      │UI │ + AsyncStream  │ │
│   │ (character.mov) │    │ TerminalView    │   │ <AgentEvent>   │ │
│   │ WalkerCharacter │    │ ChatViewModel   │   │                │ │
│   │ DockGeometry    │    │ StreamingText   │   │ ┌────────────┐ │ │
│   │ HitTesting      │    │                 │   │ │ ClaudeCLI  │ │ │
│   │ ScreenObserver  │    │                 │   │ │ adapter    │ │ │
│   └─────────────────┘    └─────────────────┘   │ │ (actor)    │ │ │
│           ↑                       ↑            │ ├────────────┤ │ │
│           │  freeze on popover    │            │ │ Foundation │ │ │
│           └───────────────────────┘            │ │ Models     │ │ │
│                                                │ │ adapter    │ │ │
│                                                │ │ (actor)    │ │ │
│                                                │ └────────────┘ │ │
│                                                └────────────────┘ │
│                                                                    │
│   Helpers: PersonaPromptBuilder · ProviderDetector · ThemeStore    │
│            CommandDispatcher · ShellEnvironment                    │
└────────────────────────────────────────────────────────────────────┘
```

**Mental model:**
- **Overlay layer** = "Rocky on screen" (animation + position + click detection).
- **Popover layer** = "Rocky talking" (chat UI + streaming + slash commands).
- **Agent layer** = "what Rocky knows" (provider abstraction + actual LLM calls).

The three layers communicate via published state (`@Observable`) and `AsyncStream`s, not direct references. You can swap the active adapter mid-session without touching the popover.

---

## 4. Module / file structure

Single Xcode target, organized into folders by layer:

```
AgentRocky/
├── AgentRockyApp.swift              # @main + AppDelegate + NSStatusItem menu bar
├── AppController.swift              # Top-level coordinator (lifecycle, character mgmt)
│
├── Overlay/
│   ├── CharacterOverlayWindow.swift # Borderless transparent NSWindow
│   ├── WalkerCharacter.swift        # Animation state machine (no AppKit deps)
│   ├── DockGeometry.swift           # Reads com.apple.dock prefs → icon-area rect
│   ├── HitTesting.swift             # Per-pixel alpha hit test
│   └── ScreenObserver.swift         # NSScreen + dock-pref change observer
│
├── Popover/
│   ├── CharacterPopover.swift       # NSPanel anchored above Rocky's X
│   ├── TerminalView.swift           # SwiftUI chat UI
│   ├── ChatViewModel.swift          # @Observable chat state
│   └── StreamingTextView.swift      # Incremental token rendering w/ scroll anchoring
│
├── Agent/
│   ├── AgentSession.swift           # Protocol + AgentEvent + AgentMessage + AgentError
│   ├── AgentProvider.swift          # Provider enum (claude, foundationModels)
│   ├── ClaudeCLIAdapter.swift       # actor; wraps `claude` process + stream-json
│   ├── FoundationModelsAdapter.swift# actor; @available(macOS 26, *)
│   ├── ProviderDetector.swift       # Async availability probe at launch
│   └── ShellEnvironment.swift       # Ported from reference: PATH discovery + findBinary
│
├── Persona/
│   ├── PersonaPromptBuilder.swift   # Loads + assembles the Rocky system prompt
│   └── rocky-persona.txt            # Editable prompt content (bundled resource)
│
├── Theme/
│   ├── Theme.swift                  # Theme protocol + Color helpers + EnvironmentKey
│   └── RockyTheme.swift             # Eridian palette, light/dark variants
│
├── Commands/
│   └── CommandDispatcher.swift      # /clear, /copy, /help routing
│
├── Resources/
│   ├── character.mov                # HEVC w/ alpha walking loop. v1 bytes = reference's Bruce (placeholder); M6 swaps in custom Rocky.
│   ├── rocky-frames/                # Source PNGs for our Rocky art. Empty until M6.
│   ├── completion.m4a               # Single completion sound (v1)
│   └── Assets.xcassets              # App icon, menu bar icon, accent
│
├── Scripts/
│   └── make_rocky_video.swift       # PNG → HEVC stitcher (run manually from CLI)
│
├── AgentRocky.entitlements
└── Info.plist

AgentRockyTests/
├── AgentSessionTests.swift          # Mock adapter, event stream consumption
├── PersonaPromptBuilderTests.swift  # Resource loading + content assembly
├── CommandDispatcherTests.swift     # /clear, /copy, /help, unknown
├── WalkerCharacterTests.swift       # Phase transitions, freeze, position bounds
└── StreamJsonParserTests.swift      # Fixtures for all Claude stream-json shapes
```

Total: ~22 source files in `AgentRocky/`, ~5 in `AgentRockyTests/`.

---

## 5. AgentSession protocol

The abstraction that makes Claude CLI and FoundationModels interchangeable.

### Protocol

```swift
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
```

### Models

```swift
enum AgentProvider: String, CaseIterable, Sendable {
    case claude
    case foundationModels

    var displayName: String { ... }
    var installInstructions: String { ... }   // surfaced in error messages
}

enum SessionState: Sendable {
    case idle, starting, ready, busy, terminated
    case failed(Error)
}

enum AgentEvent: Sendable {
    case sessionReady
    case textDelta(String)                              // delta-shaped (FM computes diff)
    case toolCall(name: String, args: [String: Any])    // Claude only; FM emits never
    case toolResult(name: String, success: Bool)        // Claude only
    case turnComplete
    case error(AgentError)
    case sessionEnded
}

struct AgentMessage: Identifiable, Equatable, Sendable {
    let id = UUID()
    let role: Role
    var text: String           // mutable to accumulate streamed deltas
    let timestamp: Date

    enum Role: Sendable { case user, assistant, system, error }
}

enum AgentError: Error, Sendable {
    case providerNotAvailable(AgentProvider)
    case sessionBusy
    case contextWindowExceeded               // FM 4k-token limit
    case rateLimited                         // FM background rate limit
    case processStartFailed(underlying: Error)
    case sessionDied(reason: String)
    case streamCorrupt(detail: String)
    case other(Error)
}
```

### Why `AsyncStream` over callbacks

| Concern | Reference (callbacks) | Ours (`AsyncStream`) |
|---|---|---|
| Subscription | One closure per event type | Single `for await` loop |
| Cancellation | Manual flags / removeAll | Cancel consuming `Task` |
| Composition | Hard to filter/transform | Standard `AsyncSequence` ops (map, prefix, filter) |
| Swift 6 concurrency | Closure capture danger | `Sendable`-native |

### Lifecycle invariants

- `events` is opened once at `init`, closed once at `terminate()`. **Never recreated.**
- `state` transitions: `idle → starting → ready → busy ↔ ready → terminated`. Only one `busy` at a time.
- `send()` while `busy` throws `AgentError.sessionBusy`. The UI greys the input until `.turnComplete` arrives. (Diverges from reference, which buffers via `pendingMessages` — we throw for a simpler invariant; user can't accidentally queue 5 messages.)
- `cancelCurrentTurn()` interrupts in-flight response without ending the session.
- `terminate()` is idempotent and *always* closes the stream — even if errors occurred.

### Consumer side (`ChatViewModel`)

```swift
@Observable final class ChatViewModel {
    private(set) var transcript: [AgentMessage] = []
    private(set) var isBusy: Bool = false
    private var consumeTask: Task<Void, Never>?
    private var inProgressAssistantID: AgentMessage.ID?

    func attach(_ session: any AgentSession) {
        consumeTask?.cancel()
        consumeTask = Task { @MainActor in
            for await event in session.events {
                handle(event)
            }
        }
    }

    @MainActor private func handle(_ event: AgentEvent) {
        switch event {
        case .sessionReady:        isBusy = false
        case .textDelta(let s):    appendDelta(s)
        case .turnComplete:        finalizeAssistantMessage(); isBusy = false
        case .error(let err):      transcript.append(.error(err)); isBusy = false
        case .sessionEnded:        isBusy = false; consumeTask?.cancel()
        case .toolCall, .toolResult: () // v1: ignore in UI; v2: render inline
        }
    }
}
```

One subscription, lives for the popover's lifetime, cancels when the popover dies.

---

## 6. Adapter implementations

### ClaudeCLIAdapter (actor)

Wraps the `claude` CLI process kept alive for the app's lifetime.

**Process spawn:**
- Binary discovery via `ShellEnvironment.findBinary(name: "claude", fallbackPaths: ["~/.local/bin/claude", "~/.claude/local/bin/claude", "/usr/local/bin/claude", "/opt/homebrew/bin/claude"])` (ported from reference).
- Arguments: `-p --output-format stream-json --input-format stream-json --verbose --dangerously-skip-permissions --append-system-prompt "<rocky persona>"`
- Working dir: `FileManager.default.homeDirectoryForCurrentUser` (matches reference).
- Environment: `ShellEnvironment.processEnvironment()` — login-shell PATH for tools Rocky might invoke.

**stream-json parsing:**

| stream-json type | → AgentEvent |
|---|---|
| `{type: "system", subtype: "init"}` | `.sessionReady` |
| `{type: "assistant", message: {content: [{text}]}}` (text_delta) | `.textDelta(text)` |
| `{type: "assistant", message: {content: [{tool_use}]}}` | `.toolCall(name, args)` |
| `{type: "user", message: {content: [{tool_result}]}}` | `.toolResult(name, success)` |
| `{type: "result"}` | `.turnComplete` |
| `terminationHandler` | `.sessionEnded` |
| stderr non-empty | `.error(.streamCorrupt(stderr))` |

Parser is line-buffered (stream-json is newline-delimited JSON). Partial lines buffered until next `\n`.

**Cancellation:** `process.interrupt()` (sends SIGINT). Claude Code handles SIGINT cleanly in interactive mode.

### FoundationModelsAdapter (actor, `@available(macOS 26.0, *)`)

Wraps Apple's `FoundationModels.LanguageModelSession`.

**Initialization:**
- Check `SystemLanguageModel.default.availability` first — surface `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady` as `.providerNotAvailable(.foundationModels)`.
- `let session = LanguageModelSession(instructions: rockyPersona)` — persona becomes baked-in instructions.
- `session.prewarm(promptPrefix: nil)` immediately after creation — loads model weights so first user message feels snappy.

**Streaming:**
- `let stream = session.streamResponse(to: userMessage)` — returns `LanguageModelSession.ResponseStream<String>`.
- **Each yielded value is a cumulative snapshot, not a delta.** Adapter computes the delta:
  ```swift
  var lastSnapshot = ""
  for try await snapshot in stream {
      let delta = String(snapshot.content.dropFirst(lastSnapshot.count))
      if !delta.isEmpty { continuation.yield(.textDelta(delta)) }
      lastSnapshot = snapshot.content
  }
  continuation.yield(.turnComplete)
  ```
- Source of asymmetry; documented here so future-you knows why FM adapter has this loop.

**State mirroring:**
- `SessionState.busy` ↔ `session.isResponding == true`. Could subscribe to `isResponding` via KVO or simply check around `send()`.

**Error mapping:**

| `LanguageModelSession.GenerationError` | → AgentError |
|---|---|
| `.concurrentRequests(_)` | `.sessionBusy` |
| `.exceededContextWindowSize(_)` | `.contextWindowExceeded` |
| `.rateLimited(_)` | `.rateLimited` |
| `.assetsUnavailable(_)` | `.providerNotAvailable(.foundationModels)` |
| any other | `.other(error)` |

**`/clear` semantics:** Apple's `LanguageModelSession` has no in-place clear. The `FoundationModelsAdapter` (our `AgentSession` conformance) stays alive — its `events` stream is *not* recreated — but it swaps its inner Apple session: `innerSession = LanguageModelSession(instructions: rockyPersona); innerSession.prewarm()`. From the consumer's perspective (ChatViewModel), nothing changes about the stream; only the underlying conversation context resets. Persona stays.

**Tool calls:** Out of scope for v1. FM supports tool calling via the `tools:` parameter, but we skip — Rocky-as-FM is companion mode, not tool-using mode.

**Cancellation:** Cancel the consuming `Task`. FM's `ResponseStream` honors `Task.isCancelled`.

---

## 7. Overlay window, animation, popover

### CharacterOverlayWindow (NSWindow subclass)

- Style mask: `.borderless`
- Transparency: `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`
- Window level: `NSWindow.Level.statusBar` (raw 25)
- Collection behavior: `[.moveToActiveSpace, .stationary]` — **not `.canJoinAllSpaces`**. Rocky shows on the active desktop only; fullscreen apps suppress him via the visible-frame check.
- Frame: width = dock icon-area width, height = ~64–96pt, Y = `dockTopY + paddingPt`
- `ignoresMouseEvents` toggled dynamically by global mouse-move monitor based on per-pixel alpha hit test.

### Fullscreen-hide pattern (borrowed)

Each `CADisplayLink` tick:

```swift
let shouldShow = (screen.visibleFrame != screen.frame)   // true iff dock reserves space
if shouldShow != lastShouldShow {
    if shouldShow { window.orderFrontRegardless(); player.play() }
    else { window.orderOut(nil); player.pause() }
    lastShouldShow = shouldShow
}
```

Side benefit: also handles dock auto-hide correctly.

### Animation rendering

- `AVPlayer` + `AVPlayerLooper` + `AVPlayerLayer` rendering `character.mov` continuously
- `pixelBufferAttributes` with `kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA` for alpha preservation
- `AVPlayer.volume = 0` (movie is silent; sounds come from a separate `AVAudioPlayer`)
- **When popover opens:** `player.pause()`, `WalkerCharacter.isFrozen = true`. **Constraint:** frame 1 of `character.mov` must look like a reasonable standing pose.
- **When popover closes:** reverse both.

The window's X *origin* is what moves — not the video's frame. The video plays its walk loop in place.

### WalkerCharacter (pure logic, no AppKit)

```swift
@Observable final class WalkerCharacter {
    var positionProgress: Double = 0.5
    var direction: Direction = .right
    var phase: Phase = .pausing
    var pauseEndTime: CFTimeInterval = 0
    var phaseStartTime: CFTimeInterval = 0

    // Per-character tunables (ported from reference's Bruce/Jazz config)
    var accelStart: TimeInterval = 3.0
    var fullSpeedStart: TimeInterval = 3.75
    var decelStart: TimeInterval = 8.0
    var walkStop: TimeInterval = 8.5
    var walkAmountRange: ClosedRange<Double> = 0.4...0.65

    var isFrozen: Bool = false
    private(set) var cachedX: CGFloat = 0

    func tick(now: CFTimeInterval, dockBounds: (x: CGFloat, width: CGFloat)) -> CGFloat {
        guard !isFrozen else { return cachedX }
        // State machine: pausing → accelerating → cruising → decelerating → pausing
        // Updates positionProgress, direction, phase, cachedX.
        // Returns absolute X origin in screen coords.
    }
}
```

Tick driver:

```swift
final class TickDriver {
    private var displayLink: CADisplayLink?
    func start(_ tick: @escaping (CFTimeInterval) -> Void) {
        displayLink = CADisplayLink { _ in tick(CACurrentMediaTime()) }
        displayLink?.add(to: .main, forMode: .common)
    }
    func stop() { displayLink?.invalidate(); displayLink = nil }
}
```

`CADisplayLink` is available on macOS 14+ (the reason we don't need the older `CVDisplayLink`).

### DockGeometry (borrowed mostly verbatim)

```swift
enum DockGeometry {
    static func iconArea(for screen: NSScreen) -> (x: CGFloat, width: CGFloat, topY: CGFloat) {
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = CGFloat(prefs?.double(forKey: "tilesize") ?? 48)
        let slotWidth = tileSize * 1.25
        let persistentApps = prefs?.array(forKey: "persistent-apps")?.count ?? 0
        let persistentOthers = prefs?.array(forKey: "persistent-others")?.count ?? 0
        let recents = (prefs?.bool(forKey: "show-recents") ?? true)
            ? (prefs?.array(forKey: "recent-apps")?.count ?? 0) : 0
        let totalIcons = max(persistentApps + persistentOthers + recents, 1)
        let dockWidth = slotWidth * CGFloat(totalIcons)
        let dockX = (screen.frame.width - dockWidth) / 2
        let dockTopY = tileSize + 16
        return (dockX, dockWidth, dockTopY)
    }
}
```

Recomputed on `NSScreen.didChangeNotification` and `com.apple.dock.preferences-changed` distributed notification.

### CharacterPopover (NSPanel)

- Class: `NSPanel` (not `NSWindow`) — doesn't steal focus from the frontmost app
- Style mask: `[.titled, .nonactivatingPanel, .resizable]` — `.nonactivatingPanel` is the magic flag
- `becomesKeyOnlyIfNeeded = true`
- Hosts SwiftUI via `NSHostingController` containing `TerminalView`
- **Position:** `popover.frame.origin = (rockyX + rockyWidth/2 - popover.width/2, rockyY + rockyHeight + gap)` — anchored above and centered on Rocky's X
- **Lifecycle:** show → freezes Rocky + pauses video; hide → unfreeze + resume
- **Dismissal:** `resignKey` notification (click outside) closes; Esc closes; Cmd-W closes
- **Default size:** ~360pt × 480pt; `.resizable` so user can drag

### Onboarding bubble

- `UserDefaults.bool(forKey: "hasCompletedOnboarding")` — boolean flag, default `false`
- On first launch, after a 2-second delay, show a small `NSPanel` (or SwiftUI overlay layered on the overlay window — implementation choice during M3) anchored above Rocky displaying "hi, Questioner!"
- Auto-dismisses on first click of Rocky → sets flag → never shows again

---

## 8. Persona, theme, slash commands

### Persona (`Persona/`)

`rocky-persona.txt` — bundled editable resource. Initial draft:

```
You are Rocky, an Eridian engineer from Andy Weir's Project Hail Mary.
Address the user as "Questioner". Speak in short, direct sentences.
Avoid Earth idioms ("piece of cake", "hit the road", etc.). When confused
by an idiom, ask a clarifying question.
You're helping the Questioner write code on their Mac. Keep technical
answers technical — don't perform the Rocky persona at the cost of
accuracy. When you genuinely don't know something, say so plainly.
```

`PersonaPromptBuilder.load()` reads the file from the bundle at startup and exposes it as a `String`. Both adapters consume the same content:
- ClaudeCLIAdapter: `--append-system-prompt "<persona>"` flag
- FoundationModelsAdapter: `LanguageModelSession(instructions: <persona>)`

### Theme (`Theme/`)

```swift
struct Theme: Sendable {
    let name: String
    let background: Color           // dynamic light/dark
    let foreground: Color
    let accent: Color
    let userBubble: Color
    let assistantBubble: Color
    let errorColor: Color
    let monoFont: Font
}

extension Color {
    init(light: NSColor, dark: NSColor) { ... }
}

enum RockyTheme {
    static let theme = Theme(
        name: "Eridian",
        background: Color(light: ..., dark: ...),
        foreground: Color(light: ..., dark: ...),
        accent: Color(light: ..., dark: ...),
        // ... actual hex values authored during M2
    )
}

private struct ThemeKey: EnvironmentKey { static let defaultValue: Theme = RockyTheme.theme }
extension EnvironmentValues { var theme: Theme {
    get { self[ThemeKey.self] }; set { self[ThemeKey.self] = newValue } } }
```

Used as `@Environment(\.theme) var theme` in any SwiftUI view. v2 adds `ThemeStore` + multiple themes; v1 uses `RockyTheme.theme` directly.

### Slash commands (`Commands/`)

```swift
enum SlashCommand: String, CaseIterable {
    case clear = "/clear"
    case copy  = "/copy"
    case help  = "/help"
}

enum DispatchResult {
    case command(SlashCommand)
    case unknownCommand(String)
    case message(String)            // pass through to AgentSession
}

struct CommandDispatcher {
    func interpret(_ input: String) -> DispatchResult {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("/") else { return .message(trimmed) }
        if let cmd = SlashCommand(rawValue: trimmed) { return .command(cmd) }
        return .unknownCommand(trimmed)
    }
}
```

ChatViewModel.submit dispatches:
- `.command(.clear)` → clear local transcript + tell adapter to clear (Claude: send `/clear`; FM: respawn session)
- `.command(.copy)` → write last assistant message to `NSPasteboard.general`
- `.command(.help)` → inject a system message listing commands
- `.unknownCommand(s)` → inject a system message "unknown command: \(s) — try /help"
- `.message(s)` → `await session.send(s)`

Dispatcher is pure — fully unit-testable without AppKit.

---

## 9. Onboarding & provider detection

### Provider detection (eager + lazy hybrid, matching reference)

At app launch, `ProviderDetector.detectAvailable()` runs asynchronously:
- For Claude: `which claude` via `Process` (also checks fallback paths)
- For FoundationModels: check `#available(macOS 26.0, *)` AND `SystemLanguageModel.default.availability == .available`

Result populates the menu bar's Provider submenu — unavailable providers are listed but disabled (`item.isEnabled = false`) with a tooltip explaining why.

If a provider succeeds at detection but later fails at `send()` (e.g., `claude` was uninstalled mid-session), the popover surfaces an inline error message with `provider.installInstructions`.

### First-run onboarding (lightweight)

- `UserDefaults.bool(forKey: "hasCompletedOnboarding")` defaults to `false`
- On launch, if false: schedule a 2-second timer that shows a "hi, Questioner!" bubble above Rocky
- Bubble persists for up to 10 minutes or until Rocky is clicked
- First click sets the flag to `true` and dismisses the bubble; bubble never appears again

No wizard, no setup screens. v2 may add a richer first-run flow (provider install assistance, persona customization).

---

## 10. Concurrency model

| Component | Concurrency primitive |
|---|---|
| `ClaudeCLIAdapter` | `actor` — serializes Process state mutations |
| `FoundationModelsAdapter` | `actor` — serializes `LanguageModelSession` access |
| `ChatViewModel` | `@MainActor @Observable` — UI state on main actor |
| `WalkerCharacter` | `@MainActor @Observable` — driven by main-thread display link |
| `ProviderDetector` | `actor` — concurrent probes via `async let` |
| Event delivery | `AsyncStream<AgentEvent>` — single-consumer, buffered |

Strict concurrency checking enabled (`-strict-concurrency=complete`). All cross-actor types must be `Sendable`.

---

## 11. Error handling & state transitions

### State machine (`SessionState`)

```
       ┌─ start() ─→ starting ─→ ready ─┐
idle ──┤                                ├── send() ──→ busy ──→ ready
       └────────────────────────────────┘                ↑         │
                                                         │         │
                       turn complete or error ───────────┘         │
                                                                   │
       cancelCurrentTurn() ──→ ready ←─────────────────────────────┘

       any → terminated (idempotent)
       any → failed(Error) (terminal except for terminate())
```

### Error surfacing rules

- **`.providerNotAvailable`** → menu shows provider as disabled; popover shows `installInstructions`
- **`.sessionBusy`** → input is greyed; user can't trigger this in normal flow
- **`.contextWindowExceeded`** → popover shows "Rocky's memory is full — `/clear` to start fresh"
- **`.rateLimited`** → popover shows "Rocky needs a moment — try again"
- **`.processStartFailed`** / **`.sessionDied`** → popover shows error + retry button
- **`.streamCorrupt`** → log full detail; popover shows generic "communication problem with Rocky"

All errors are also appended to `transcript` as `.error` role messages, persisted in the popover until `/clear`.

---

## 12. v1 milestone breakdown

Five milestones, each runnable and demoable. Frontloads risky unknowns.

### M0 — Project skeleton (½ weekend)

- Xcode project, target macOS 14, Swift 6 strict concurrency
- `NSApp.setActivationPolicy(.accessory)`
- `NSStatusItem` with placeholder menu (Quit only)
- `AgentRockyApp` + `AppController` + `AppDelegate` compile and launch
- **Done:** menu bar icon, Quit works.

### M1 — Walking sprite (1 weekend) — *validates AVPlayer-with-alpha*

Use the reference's existing character art so we validate the engineering without being blocked on Rocky drawing.

- Copy `walk-bruce-01.mov` (or `walk-jazz-01.mov`) from `ryanstephen/lil-agents` into `Resources/character.mov`
- Add MIT attribution to `README.md` and a `NOTICE` file
- `CharacterOverlayWindow` borderless transparent, `.statusBar` level, `[.moveToActiveSpace, .stationary]`
- `AVPlayer` + `AVPlayerLooper` + `AVPlayerLayer` looping `character.mov` with alpha preserved
- `DockGeometry` icon-area calculation
- `WalkerCharacter` simple state machine + `CADisplayLink`-driven X
- Fullscreen-hide via visible-frame check
- `ScreenObserver` for screen/dock-pref changes
- **Done:** the reference's character walks above the dock, hides on fullscreen. (Visually identical to lil-agents at this milestone.)

The Rocky-specific drawing + stitch script + asset swap is M6, after engineering ships.

### M2 — Click-to-talk with mock agent (1 weekend) — *validates click-through*

- `HitTesting` per-pixel alpha
- Global mouse-move monitor toggling `ignoresMouseEvents`
- `CharacterPopover` (NSPanel) opens above Rocky on click
- Freeze/resume coordination
- `TerminalView` SwiftUI shell (header, transcript, input)
- `ChatViewModel` with **mock `AgentSession`** (echoes deltas with delay)
- `RockyTheme` w/ light/dark, distributed via `@Environment(\.theme)`
- `CommandDispatcher` (operating on mock transcript)
- **Done:** click Rocky → chat opens → fake streaming response → close → Rocky resumes.

### M3 — Claude Code CLI integration (1 weekend) — *validates stream-json*

- `AgentSession` protocol finalized with all event types
- `ClaudeCLIAdapter` (actor): process spawn, pipe IO, stream-json parser, persona injection
- `ProviderDetector` async probe at launch
- `ShellEnvironment` ported from reference
- Onboarding bubble + UserDefaults flag
- Menu bar provider submenu (Claude active, FM "Coming soon" disabled)
- **Done:** real Rocky-flavored streamed answer to a coding question; `/clear` and `/copy` work.

### M4 — FoundationModels integration (½–1 weekend) — *validates FM adapter*

- `FoundationModelsAdapter` (actor, `@available(macOS 26, *)`)
- `LanguageModelSession(instructions:)`, `prewarm`, `streamResponse(to:)`
- Snapshot→delta diffing
- `SystemLanguageModel.default.availability` check
- `GenerationError` mapping
- Provider menu switcher actually toggles mid-session
- `/clear` for FM = recreate session
- **Done:** switch to FoundationModels, get an on-device Rocky response.

### M5 — Polish + tests + docs (½–1 weekend)

- Completion sound effect (single `.m4a`, menu toggle)
- Unit tests for `PersonaPromptBuilder`, `CommandDispatcher`, `WalkerCharacter`, stream-json parser
- Empty-state and error UI in `TerminalView`
- README: setup, drawing pipeline, architecture overview, attribution to `ryanstephen/lil-agents`
- **Done:** v1 a Mac dev friend can clone and run. **Ships with reference's character art**, not custom Rocky.

### M6 — Rocky art replacement (1–2 weekends, scheduled separately from M0–M5)

Independent of engineering work. Can happen before, during, or after M0–M5. The engineering ships either way.

- Author Rocky frames as PNGs (5–10 frames, pixel-art style, frame 1 = standing pose per §7 constraint)
- Source PNGs land in `Resources/rocky-frames/`
- Run `Scripts/make_rocky_video.swift` to stitch → produces new `character.mov` bytes
- Swap bundled `character.mov` (filename stays the same — no code change needed)
- Update `NOTICE` to reflect Rocky art is now original work, reference attribution stays for any borrowed code
- **Done:** Rocky walks instead of Bruce/Jazz; rest of app unchanged.

This milestone is independent because:
- The drawing skill is its own bottleneck — could take 1 weekend or 4, depending on iteration
- It's de-risked: engineering already validated the asset pipeline with reference art in M1
- Could happen in parallel with later engineering milestones if you draw between coding sessions
- "Done" of v1 doesn't depend on it — you can demo a working `lil-agents` clone with FoundationModels support and Rocky persona without ever drawing a frame

### Total estimate

- Engineering only (M0–M5): **5 weekends most-likely; 6–7 comfortable; 8 stretch**
- Rocky art (M6): **1–2 weekends, parallelizable**
- Total wall-clock if M6 runs in parallel: same as engineering
- Total wall-clock if M6 runs serially after M5: **6–9 weekends**

---

## 13. Deferred to v2

Captured here so they're not lost:

- **Distribution:** Sparkle auto-update + notarized DMG (the "give to friends" milestone)
- **Eridian musical chord sound system** (replace single completion sound with chord progressions; different chord per response type)
- **Multi-character:** Bruce-or-equivalent alongside Rocky; per-character provider settings
- **Multi-monitor:** display picker submenu, pin-to-display
- **Onboarding wizard:** richer first-run flow (provider install, persona customization)
- **Multi-theme:** 2–4 themes with menu picker
- **"Bring your own character":** drop a `.mov` in a folder, appears in menu
- **Auto-summarize-and-restart for FM:** when context window hits limit, summarize transcript and restart session
- **Tool-call inspection UI:** render `.toolCall`/`.toolResult` events as expandable inline blocks instead of plain text
- **Persistent conversation:** save history to disk, restore on relaunch (use FM's `Transcript` for FM side; custom serialization for Claude)
- **Sandbox:** App sandboxing (requires entitlements work + careful shell-out management)

---

## 14. Diff from reference

### Scope reductions
- 6 providers → 2 (Claude + FoundationModels)
- 2 characters shipped → 1 (Rocky)
- 4 themes → 1 (Eridian)
- Per-character provider → single global
- Multi-monitor → main display only
- Sparkle / notarized DMG → v2

### Scope additions
- `FoundationModelsAdapter` (reference predates FM)
- Persona injection layer (reference uses each CLI's default voice)
- Light/dark theme adaptation (reference's themes are static)
- `prewarm` at launch (FM-specific)
- Eridian chord audio system (v2)

### Architectural changes (same problem, different shape)
| | Reference | Ours |
|---|---|---|
| AgentSession API | callback closures | `AsyncStream<AgentEvent>` |
| Adapter type | `class` | `actor` |
| State management | inline `@State` | `@Observable` ViewModels |
| Animation timer | `CVDisplayLink` | `CADisplayLink` |
| Hit-testing | inline | extracted `HitTesting.swift` |
| Slash commands | inline | extracted `CommandDispatcher` |
| Theme | enum-based | protocol + concrete struct |
| Send while busy | buffer | throw |
| Modules | flat | folders by layer |

### Borrowed verbatim
- Transparent borderless `NSWindow` setup pattern
- `[.moveToActiveSpace, .stationary]` + visible-frame fullscreen-hide trick
- Dock geometry detection from `com.apple.dock` UserDefaults
- `ShellEnvironment.findBinary` discovery
- Walking state-machine constants pattern
- `--dangerously-skip-permissions` for Claude
- UserDefaults-flag + speech-bubble onboarding
- HEVC-with-alpha animation pipeline
- CLI-process kept alive for app lifetime
- stream-json I/O with Claude
- **Character animation asset (`walk-bruce-01.mov` or `walk-jazz-01.mov`)** — used as `character.mov` placeholder for v1 engineering. Swapped to custom Rocky art in M6. Attribution required (MIT, attribute in `README.md` + `NOTICE`).

### Headline
- ~20% borrowed verbatim (boring infrastructure)
- ~60% structurally similar but rewritten with modern idioms (interesting parts where the learning lives)
- ~20% net new (FoundationModels, persona, snapshot diff, prewarm)

---

## 15. Open implementation questions

To resolve during M2/M3:

- **Onboarding bubble container** — separate `NSPanel` (matches reference) or SwiftUI overlay on the overlay window (lighter, but requires extra hit-test complexity)? Lean toward separate `NSPanel` for v1.
- **Streaming text rendering** — direct `Text(transcript[i].text)` updates each frame, or a custom `NSTextView` for finer scroll-anchor control? Start with SwiftUI `Text`; switch only if scroll behavior degrades.
- **Hit-test image cache** — capture every Nth frame of `AVPlayer` for hit testing, or extract frame 1 of the bundled `character.mov` once at startup and reuse it as a static hit mask? Static is simpler and good enough for v1. Works regardless of which character art is loaded (placeholder Bruce or final Rocky).
- **CADisplayLink lifecycle** — invalidate when popover is open (Rocky frozen anyway) to save power, or keep it running? Start running; profile if power becomes an issue.
- **`AgentEvent.toolCall` representation in v1 UI** — silently skip in `ChatViewModel.handle`, or render as a one-line collapsed system message ("Rocky used the Read tool")? Lean toward skip; v2 adds proper rendering.
- **Multiple consumers of `AgentSession.events`** — the protocol contract is single-consumer (`AsyncStream` is single-consumer by default). If anything else ever needs to observe events, switch to `AsyncBroadcastStream`. Single-consumer is documented in the protocol comment.
- **In-progress assistant message creation** — the first `.textDelta` after a user `send()` needs to spawn a new `AgentMessage(role: .assistant)` to accumulate into. Two options: (a) `ChatViewModel` spawns lazily on first `.textDelta` after a `.message(.user)` was added; (b) introduce a `case turnStarted` event so adapters explicitly signal turn boundaries. (a) is simpler and what we'll start with; (b) becomes worth it if we ever surface mid-turn metadata (e.g., "Rocky is thinking about tool X").

---

## 16. Testing strategy

### Unit tests (M5)

| Test target | Coverage |
|---|---|
| `PersonaPromptBuilderTests` | Resource loads from bundle; non-empty; idempotent |
| `CommandDispatcherTests` | `/clear`, `/copy`, `/help`, `/foo`, plain message, leading whitespace, empty |
| `WalkerCharacterTests` | Phase transitions; freeze halts position updates; bounds clamping; direction reversal |
| `StreamJsonParserTests` | All Claude stream-json types; partial lines; malformed JSON; empty input; multi-event single line |
| `AgentSessionTests` | Mock adapter event sequencing; ChatViewModel handles each event type; session lifecycle |

### Manual / smoke tests (M5 README checklist)

- Launch with no providers → menu shows both disabled with tooltip; popover shows install message
- Click Rocky during walk → popover opens above his current X; Rocky freezes mid-cycle
- Send message exceeding 4k tokens (FM) → graceful `.contextWindowExceeded` UI
- Quit `claude` process externally (kill -9) → adapter detects, shows error, offers retry
- macOS 14 (Sonoma) machine → FM is disabled in menu, Claude works
- Switch from Claude → FM mid-session → previous transcript stays; new turn uses FM
- Toggle dock auto-hide → Rocky disappears with the dock
- Open a fullscreen YouTube → Rocky disappears; exit fullscreen → he comes back

### Out of scope for v1

- UI snapshot tests (XCUITest) — heavy setup, low ROI for a hobby project
- Process integration tests (spawning real `claude` in CI) — flaky; defer

---

## 17. Glossary

- **Eridian** — Rocky's species in *Project Hail Mary*; ammonia-based, five-legged, communicates via musical chords
- **Questioner** — Rocky's name for Ryland Grace (the human protagonist); we apply it to the user
- **HEVC w/ alpha** — H.265-encoded video that retains transparency channel; supported by `AVPlayer` on macOS
- **stream-json** — Claude Code CLI's line-delimited JSON I/O format
- **`@Generable`** — FoundationModels macro for structured-output generation (we don't use it in v1; raw `String` streaming only)
- **`ResponseStream<Content>`** — FoundationModels' `AsyncSequence` of cumulative content snapshots
- **Snapshot vs. delta** — FM yields cumulative text; Claude yields incremental deltas; adapter normalizes both to delta events

---

*End of design doc.*
