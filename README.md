<div align="center">
  <img src="dexai_logo.png" width="128" alt="DXAI Logo">
  <h1>Deus eX AI</h1>
  <p><strong>AI dev environment manager for macOS</strong></p>
  <p>Track tokens, monitor quotas, optimize your system — all from the menu bar.</p>
</div>

<p align="center">
  <a href="https://github.com/glen15/dxai/stargazers"><img src="https://img.shields.io/github/stars/glen15/dxai?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/glen15/dxai/releases"><img src="https://img.shields.io/github/v/tag/glen15/dxai?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="README.md"><img src="https://img.shields.io/badge/lang-English-blue?style=flat-square" alt="English"></a>
  <a href="README.ko.md"><img src="https://img.shields.io/badge/lang-한국어-blue?style=flat-square" alt="Korean"></a>
</p>

## Install

```bash
brew install --cask glen15/dxai/dxai
```

macOS 13 (Ventura) or later. No API keys needed.

---

<p align="center">
  <img src="screenshot/kr1.png" width="280" alt="Menu Bar (KR)">
  <img src="screenshot/egn1.png" width="280" alt="Menu Bar (EN)">
</p>

<p align="center">
  <img src="screenshot/vanguard1.png" width="560" alt="Vanguard Leaderboard">
</p>

---

## Features

- **Token Dashboard** — Claude Code, Codex CLI usage combined in real-time
- **Quota Monitoring** — 5-hour/7-day limits with reset timers
- **Vanguard Rank** — daily usage-based tier system: 8 tiers, 36 levels (Bronze → Challenger)
- **Vanguard Leaderboard** — opt-in ranking at [vanguard.dx-ai.cloud](https://vanguard.dx-ai.cloud)
- **Token Milestones** — macOS notifications on achievement
- **System Management** — disk cleanup, memory optimization, AI env scan
- **EN/KR** — full bilingual support

---

## Data Safety

- All data is parsed locally from read-only log files (`.jsonl`)
- AI tool data (`~/.claude/`, `~/.codex/`) is never deleted
- Leaderboard is opt-in. Only nickname + token counts are submitted (no prompts, code, or conversations)

---

## Credits

Inspired by [Mole](https://github.com/tw93/Mole) by [Tw93](https://github.com/tw93) (MIT License). System management foundations rebuilt and extended with AI token tracking and gamification.

## License

MIT License. See [LICENSE](LICENSE).
