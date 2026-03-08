<div align="center">
  <h1>Deus eX AI</h1>
  <p><strong>macOS용 AI 개발 환경 매니저</strong></p>
  <p>토큰 추적, 쿼터 모니터링, 시스템 최적화 — 메뉴바 하나로.</p>
</div>

<p align="center">
  <a href="https://github.com/glen15/dxai/stargazers"><img src="https://img.shields.io/github/stars/glen15/dxai?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/glen15/dxai/releases"><img src="https://img.shields.io/github/v/tag/glen15/dxai?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="README.md"><img src="https://img.shields.io/badge/lang-English-blue?style=flat-square" alt="English"></a>
</p>

---

## dxai란?

macOS 메뉴바 앱 + CLI로, AI 코딩 도구(Claude Code, Codex CLI, Gemini CLI)의 사용 현황을 한 곳에서 확인합니다.

API 키 불필요. 모든 데이터는 로컬에서 로그 파일을 파싱하여 수집합니다.

### 메뉴바 앱

핵심 제품. 메뉴바에서 바로 확인:

- **오늘의 토큰 수** — 모든 AI 도구의 합산
- **쿼터 바** — Claude/Codex 5시간 세션 및 7일 제한, 리셋 타이머
- **파이오니어 랭크** — 일일 사용량 기반 등급 시스템 (Bronze → Challenger)
- **킬 스트릭** — 토큰 마일스톤 도달 시 알림
- **Quick Actions** — 시스템 상태, AI 환경 스캔, 디스크 정리, 최적화
- **AI 환경 스캔** — 글로벌/프로젝트 MCP 서버, 스킬, CLAUDE.md/AGENTS.md 감지
- **EN/KR** — 영어/한국어 완전 지원
- **자동 시작** — 로그인 시 자동 실행 토글

### CLI 도구

```bash
dxai ai                # 토큰 사용량 대시보드 (Claude + Codex + Gemini)
dxai ai watch          # 실시간 모니터링
dxai scan              # AI 에이전트 환경 진단
dxai scan --json       # 구조화된 출력 (메뉴바 앱에서 사용)
dxai status            # 시스템 상태 (CPU, 메모리, 디스크, 네트워크)
dxai clean             # 캐시, 로그, 임시 파일 정리
dxai optimize          # 메모리, DNS, 시스템 DB 재구축
dxai analyze           # 디스크 사용량 시각 탐색기
dxai purge             # 빌드 산출물 정리 (node_modules, .build 등)
dxai uninstall         # 숨김 파일 포함 전체 앱 제거
```

---

## 설치

### 메뉴바 앱 (권장)

```bash
brew tap glen15/dxai
brew install --cask dxaibar
```

### CLI만 설치

```bash
brew tap glen15/dxai
brew install dxai
```

### 소스에서 빌드

```bash
# CLI
curl -fsSL https://raw.githubusercontent.com/glen15/dxai/main/install.sh | bash

# 메뉴바 앱
cd app/DxaiBar
./scripts/build-app.sh release
open build/DxaiBar.app
```

### 요구사항

- macOS 13 (Ventura) 이상
- Python 3 (AI 기능용)

---

## 파이오니어 랭크 시스템

일일 토큰 사용량이 등급을 결정합니다. 매일 초기화.

| 등급 | 진입 기준 | 디비전 |
|------|-----------|--------|
| Bronze | 10K | 5 → 1 |
| Silver | 500K | 5 → 1 |
| Gold | 8M | 5 → 1 |
| Platinum | 50M | 5 → 1 |
| Diamond | 220M | 5 → 1 |
| Master | 620M | 5 → 1 |
| Grandmaster | 1.5B | 5 → 1 |
| Challenger | 5B | 최종 등급 |

8개 등급, 36개 레벨. 등급 상승 및 킬 스트릭 마일스톤 시 macOS 알림.

---

## 데이터 안전

- AI 도구 데이터 (`~/.claude/`, `~/.codex/`)는 `dxai clean`으로 **절대 삭제되지 않음**
- 모든 분석은 로컬에서 실행. 데이터가 외부로 전송되지 않음
- 로그 파일 (`.jsonl`)은 읽기 전용으로 파싱. 원본 수정 없음

---

## 프로젝트 구조

```
dxai/
├── dxai                     # 메인 CLI 엔트리포인트 (Bash)
├── bin/                     # 커맨드 구현
│   ├── ai.py                # 토큰 대시보드
│   ├── scan.py              # AI 환경 스캐너
│   ├── clean.sh             # 디스크 정리
│   ├── optimize.sh          # 시스템 최적화
│   └── ...
├── lib/                     # 공유 라이브러리
├── cmd/                     # Go 바이너리 (analyze, status)
├── app/
│   └── DxaiBar/             # macOS 메뉴바 앱 (SwiftUI)
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
│   └── Casks/dxaibar.rb     # Homebrew cask (메뉴바 앱)
└── .github/workflows/
    └── release.yml           # CI/CD: 빌드 + 릴리스 + Homebrew 업데이트
```

---

## 크레딧

[Tw93](https://github.com/tw93)의 [Mole](https://github.com/tw93/Mole) (MIT 라이선스)에서 영감을 받아, 시스템 정리/최적화 기반을 AI 중심으로 재구성했습니다 — 토큰 추적, 쿼터 모니터링, 게이미피케이션 개발자 경험을 더했습니다.

## 라이선스

MIT License. [LICENSE](LICENSE) 참조.
