<div align="center">
  <h1>Deus eX AI</h1>
  <p><strong>AI dev environment manager for macOS</strong></p>
  <p>Track tokens, monitor quotas, optimize your system — all from the menu bar.</p>
</div>

<p align="center">
  <a href="https://github.com/glen15/dxai/stargazers"><img src="https://img.shields.io/github/stars/glen15/dxai?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/glen15/dxai/releases"><img src="https://img.shields.io/github/v/tag/glen15/dxai?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="README.ko.md"><img src="https://img.shields.io/badge/lang-한국어-blue?style=flat-square" alt="Korean"></a>
</p>

---

## What is dxai?

A macOS menu bar app + CLI that gives you a single dashboard for all your AI coding tools — Claude Code, Codex CLI, Gemini CLI.

No API keys needed. Everything runs locally by parsing your tools' log files.

### Menu Bar App

The core product. Lives in your menu bar and shows:

- **Today's token count** — total across all AI tools
- **Quota bars** — Claude/Codex 5-hour session & 7-day limits with reset timers
- **Pioneer Rank** — gamified tier system (Bronze → Challenger) based on daily usage
- **Kill Streak** — milestone notifications as you hit token thresholds
- **Quick Actions** — system status, AI env scan, disk cleanup, optimization
- **AI Env Scan** — global/project MCP servers, skills, CLAUDE.md/AGENTS.md detection
- **EN/KR** — full English and Korean localization
- **Auto Start** — launch at login toggle

### CLI Tools

```bash
dxai ai                # Token usage dashboard (Claude + Codex + Gemini)
dxai ai watch          # Real-time monitoring
dxai scan              # AI agent environment diagnosis
dxai scan --json       # Structured output (used by menu bar app)
dxai status            # System health (CPU, memory, disk, network)
dxai clean             # Cache, log, temp file cleanup
dxai optimize          # Memory, DNS, system DB rebuild
dxai analyze           # Disk usage visual explorer
dxai purge             # Build artifact cleanup (node_modules, .build, etc.)
dxai uninstall         # Full app removal including hidden files
```

---

## Install

### Menu Bar App (recommended)

```bash
brew tap glen15/dxai
brew install --cask dxaibar
```

### CLI Only

```bash
brew tap glen15/dxai
brew install dxai
```

### From Source

```bash
# CLI
curl -fsSL https://raw.githubusercontent.com/glen15/dxai/main/install.sh | bash

# Menu Bar App
cd app/DxaiBar
./scripts/build-app.sh release
open build/DxaiBar.app
```

### Requirements

- macOS 13 (Ventura) or later
- Python 3 (for AI features)

---

## Pioneer Rank System

Daily token usage determines your rank. Resets each day.

| Tier | Entry | Divisions |
|------|-------|-----------|
| Bronze | 10K | 5 → 1 |
| Silver | 500K | 5 → 1 |
| Gold | 8M | 5 → 1 |
| Platinum | 50M | 5 → 1 |
| Diamond | 220M | 5 → 1 |
| Master | 620M | 5 → 1 |
| Grandmaster | 1.5B | 5 → 1 |
| Challenger | 5B | Final rank |

8 tiers, 36 levels. macOS notifications on rank-up and kill streak milestones.

---

## Data Safety

- AI tool data (`~/.claude/`, `~/.codex/`) is **never deleted** by `dxai clean`
- All analysis runs locally. No data leaves your machine
- Log files (`.jsonl`) are parsed read-only. Originals are never modified

---

## Project Structure

```
dxai/
├── dxai                     # Main CLI entrypoint (Bash)
├── bin/                     # Command implementations
│   ├── ai.py                # Token dashboard
│   ├── scan.py              # AI environment scanner
│   ├── clean.sh             # Disk cleanup
│   ├── optimize.sh          # System optimization
│   └── ...
├── lib/                     # Shared libraries
├── cmd/                     # Go binaries (analyze, status)
├── app/
│   └── DxaiBar/             # macOS menu bar app (SwiftUI)
│       ├── Sources/
│       │   ├── DxaiBarApp.swift
│       │   ├── DxaiMenuView.swift
│       │   ├── DxaiViewModel.swift
│       │   ├── DxaiDatabase.swift
│       │   ├── ScanPanelView.swift
│       │   ├── StatusPanelView.swift
│       │   └── Localization.swift
│       └── scripts/
│           └── build-app.sh
├── homebrew/
│   ├── Formula/dxai.rb      # Homebrew formula (CLI)
│   └── Casks/dxaibar.rb     # Homebrew cask (menu bar app)
└── .github/workflows/
    └── release.yml           # CI/CD: build + release + Homebrew update
```

---

## Credits

Inspired by [Mole](https://github.com/tw93/Mole) by [Tw93](https://github.com/tw93) (MIT License). The system cleanup and optimization foundations from Mole were rebuilt and extended with an AI-first approach — token tracking, quota monitoring, and a gamified developer experience.

## License

MIT License. See [LICENSE](LICENSE).
