# dxai - Deus eX AI

> AI dev environment manager for macOS

## 개요

dxai는 [Mole](https://github.com/tw93/Mole)(MIT 라이선스)에서 영감을 받아, AI 개발 환경에 특화된 macOS 도구로 재구성한 독립 프로젝트다. 시스템 정리/최적화 기반 위에 토큰 추적, 쿼터 모니터링, 게이미피케이션 개발자 경험을 더했다.

- **레포**: https://github.com/glen15/dxai
- **라이선스**: MIT
- **영감**: https://github.com/tw93/Mole (MIT)

## 타겟 사용자

**우선순위:**

1. **Claude Code 사용자** — 1순위. 핵심 타겟
2. **Codex CLI 사용자** — 2순위
여러 도구를 함께 사용하는 사용자일수록 더 큰 효과를 얻는다 (통합 대시보드, 통합 스캔).

## 아키텍처

```
dxai
├── 메뉴바 앱 (SwiftUI) — 핵심 제품
│   ├── 토큰 대시보드     — 오늘 토큰, 도구별 사용량
│   ├── 쿼터 모니터링     — Claude/Codex 5h/7d 제한 + 리셋 타이머
│   ├── Pioneer Rank     — 8등급 36레벨 게이미피케이션
│   ├── Token Milestone  — 16단계 토큰 마일스톤 알림
│   ├── Quick Actions    — 시스템 상태, AI 스캔, 정리, 최적화
│   ├── AI 환경 스캔     — 네이티브 SwiftUI UI
│   ├── About 페이지     — 앱 소개 + GitHub Star 링크
│   └── EN/KR 로컬라이제이션
│
├── CLI (Shell + Python + Go) — 터미널 인터페이스
│   ├── dxai ai          — AI 토큰 사용량 대시보드
│   ├── dxai scan        — AI 에이전트 환경 진단
│   ├── dxai status      — 시스템 상태 (Go)
│   ├── dxai clean       — 디스크 정리
│   ├── dxai optimize    — 시스템 최적화
│   ├── dxai analyze     — 디스크 분석 (Go)
│   ├── dxai purge       — 빌드 산출물 정리
│   └── dxai uninstall   — 전체 제거
│
└── 데이터 레이어
    └── SQLite           — 로컬 시계열 데이터 (~/.config/dxai/dxai.db)
```

## 현재 구현 상태

### 완료된 기능

#### 메뉴바 앱 (DxaiBar)
- [x] MenuBarExtra (.window 스타일) 기본 구조
- [x] 오늘 토큰 수 실시간 표시 (메뉴바 + 대시보드)
- [x] Claude/Codex 토큰 파싱 (`.jsonl` 로그)
- [x] Claude 쿼터 API 직접 호출 (`api.anthropic.com/api/oauth/usage`)
- [x] 5시간 세션 / 7일 주간 쿼터 바 + 리셋 타이머
- [x] Pioneer Rank 시스템 (8등급 36레벨, 디비전별 고유 멘트)
- [x] Token Milestone 알림 (16단계, AI 테마)
- [x] Quick Actions (status, scan, clean, optimize)
- [x] AI 환경 스캔 네이티브 SwiftUI UI (ScanPanelView)
- [x] About 페이지 (앱 소개, GitHub Star 링크)
- [x] EN/KR 로컬라이제이션 (L 구조체, @AppStorage 반응형)
- [x] 주간 인사이트 대시보드 (InsightsView — 7일 바 차트, 도구별/토큰 유형 분석)
- [x] 자동시작 기본 설정 (SMAppService)
- [x] macOS 네이티브 알림 (UNUserNotificationCenter + osascript 폴백)
- [x] SQLite 데이터 영속화 (DxaiDatabase)
- [x] 중복 실행 방지 (Bundle ID + PID 체크)

#### CLI
- [x] `dxai ai` — 토큰 대시보드 (Claude + Codex)
- [x] `dxai ai watch` — 실시간 모니터링
- [x] `dxai scan` — AI 환경 진단 (글로벌/프로젝트 MCP, 스킬, 세션, 포트)
- [x] `dxai scan --json` — JSON 출력 (메뉴바 앱 연동)
- [x] `dxai status` — 시스템 상태 (Go 바이너리)
- [x] `dxai clean` — 캐시/로그/임시파일 정리
- [x] `dxai optimize` — 메모리/DNS/시스템 DB 재구축
- [x] `dxai analyze` — 디스크 사용량 시각 탐색기 (Go 바이너리)
- [x] `dxai purge` — 빌드 산출물 정리
- [x] `dxai uninstall` — 전체 앱 제거

#### 배포/인프라
- [x] .app 번들 빌드 스크립트 (build-app.sh)
- [x] Homebrew Formula (CLI)
- [x] Homebrew Cask (메뉴바 앱)
- [x] GitHub Actions release.yml (태그 → 빌드 → 릴리스)
- [x] 독립 레포 (glen15/dxai, 클린 히스토리)
- [x] README.md (영문), README.ko.md (한국어), llms.txt (AI용)

### 미구현 / 향후 계획

#### 단기 (Next)
- [ ] 첫 릴리스 태그 (V1.0.0) 및 Homebrew Tap 레포 생성
- [ ] `dxai ai insights` — CLI 인사이트 커맨드 (메뉴바 앱에는 이미 구현)

#### 중기
- [ ] `dxai telemetry` — opt-in 익명 텔레메트리
- [ ] 커뮤니티 벤치마크 ("상위 N% 파이오니어")
- [ ] config.toml 기반 설정 커스터마이징
- [ ] 디스크 부족 알림

#### 장기
- [ ] Homebrew Core 등록 (star 30-75+ 확보 후)
- [ ] 모델별 비용 추정 (pricing.json)
- [ ] 다국어 확장 (JP, CN 등)

## Pioneer Rank 시스템

일일 토큰 사용량 기반 등급. 매일 초기화.

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

8개 등급, 36개 레벨. 디비전마다 고유 멘트. 등급 상승 시 macOS 네이티브 알림.

## Token Milestone

| 토큰 | 제목 (AI 테마) |
|------|---------------|
| 500K | Hello, World! |
| 1M | Token Millionaire |
| 1.5M | Prompt Artisan |
| 2M | Rate Limit Regular |
| 2.5M | Context Master |
| 3M | API Billing Alert |
| 5M | GPU Overheating |
| 7M | Datacenter Alert |
| 10M | Transformer Overload |
| 15M | Training Data Material |
| 20M | Sam Altman Notified |
| 30M | Dario Amodei Paged |
| 50M | Approaching Singularity |
| 100M | Anthropic Job Offer |
| 200M | OpenAI Job Offer |
| 500M | AGI Achieved |

EN/KR 모두 지원 (Localization.swift).

## 데이터 소스

- **Claude**: `~/.claude/projects/**/*.jsonl` (토큰), `api.anthropic.com` (쿼터)
- **Codex**: `~/.codex/sessions/**/*.jsonl` (토큰)

모든 데이터는 로컬 read-only 파싱. 원본 수정 없음.

## 데이터 안전

- AI 도구 데이터 (`~/.claude/`, `~/.codex/`)는 `dxai clean`으로 절대 삭제하지 않음
- 모든 분석은 로컬. 외부 전송 없음
- 로그 파일 (.jsonl)은 읽기 전용 파싱

## 기술 스택

| 컴포넌트 | 기술 |
|---------|------|
| 메뉴바 앱 | SwiftUI, macOS 13+, MenuBarExtra |
| CLI 엔트리포인트 | Bash |
| 토큰 파싱 | Python 3 |
| 시스템 모니터링 | Go (analyze, status) |
| 시스템 정리/최적화 | Bash |
| 데이터 영속화 | SQLite |
| 빌드/배포 | GitHub Actions, Homebrew |

## 프로젝트 구조

```
dxai/
├── dxai                     # CLI 엔트리포인트 (Bash)
├── bin/                     # 커맨드 구현 (Python/Shell)
├── lib/                     # 공유 라이브러리 (Shell)
├── cmd/                     # Go 바이너리 (analyze, status)
├── app/DxaiBar/             # 메뉴바 앱 (SwiftUI)
│   ├── Sources/
│   │   ├── DxaiBarApp.swift       # 앱 엔트리포인트
│   │   ├── DxaiMenuView.swift     # 메인 UI
│   │   ├── DxaiViewModel.swift    # 핵심 로직, 토큰 파싱, 랭크
│   │   ├── DxaiDatabase.swift     # SQLite 영속화
│   │   ├── InsightsView.swift      # 주간 인사이트 대시보드
│   │   ├── ScanPanelView.swift    # AI 환경 스캔 UI
│   │   ├── StatusPanelView.swift  # 시스템 상태 UI
│   │   └── Localization.swift     # EN/KR 문자열
│   └── scripts/build-app.sh       # .app 번들 빌더
├── homebrew/
│   ├── Formula/dxai.rb            # CLI formula
│   └── Casks/dxaibar.rb           # 메뉴바 앱 cask
├── tests/                         # Bats 테스트
├── scripts/                       # 빌드/체크 스크립트
├── docs/prd.md                    # 이 문서
└── .github/workflows/release.yml  # CI/CD
```
