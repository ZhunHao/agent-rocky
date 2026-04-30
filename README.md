# AgentRocky

A macOS dock companion app inspired by Project Hail Mary's Eridian engineer "Rocky". Click the character above your dock to chat with an AI assistant — backed by Claude Code CLI (cloud) or Apple FoundationModels (on-device).

> **Status:** in active development. See [docs/superpowers/specs/2026-04-30-agent-rocky-design.md](docs/superpowers/specs/2026-04-30-agent-rocky-design.md) for the design and [docs/superpowers/plans/2026-04-30-agent-rocky.md](docs/superpowers/plans/2026-04-30-agent-rocky.md) for the implementation plan.

## Requirements

- macOS 14+ (Sonoma) — Claude Code CLI works on all supported versions
- macOS 26+ (Tahoe) on Apple Silicon — required for FoundationModels adapter
- Xcode 16+ (Xcode 26 recommended) with Swift 6
- One of: [Claude Code CLI](https://claude.ai/download) installed, or Apple Intelligence enabled

## Building

```bash
git clone https://github.com/ZhunHao/agent-rocky.git
cd agent-rocky
open AgentRocky.xcodeproj
```

Hit ⌘R in Xcode.

## Attribution

This project includes a placeholder `character.mov` from [ryanstephen/lil-agents](https://github.com/ryanstephen/lil-agents) (MIT). See `NOTICE` for full attribution. The placeholder is replaced with custom Rocky art in M6.

## License

TBD (likely MIT for parity with the reference repo).
