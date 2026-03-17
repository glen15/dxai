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
│   ├── Vanguard Rank    — 8등급 36레벨 게이미피케이션
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
- [x] Vanguard Rank 시스템 (8등급 36레벨, 디비전별 고유 멘트)
- [x] Token Milestone 알림 (16단계, AI 테마)
- [x] Quick Actions (status, scan, clean, optimize)
- [x] AI 환경 스캔 네이티브 SwiftUI UI (ScanPanelView)
- [x] About 페이지 (앱 소개, GitHub Star 링크)
- [x] EN/KR 로컬라이제이션 (L 구조체, @AppStorage 반응형)
- [x] 주간 인사이트 대시보드 (전주 대비 추세, 캐시 적중률, 자연어 요약 불렛, 색상 카드)
- [x] 히어로 넘버 로컬라이즈 (KR: 억/만, EN: million/billion)
- [x] 자동시작 기본 설정 (SMAppService)
- [x] macOS 네이티브 알림 (UNUserNotificationCenter + osascript 폴백)
- [x] SQLite 데이터 영속화 (DxaiDatabase)
- [x] 중복 실행 방지 (Bundle ID + PID 체크)
- [x] 로컬 타임존 기반 날짜 경계 (UTC → TimeZone.current)
- [x] Vanguard Point 시스템 (Vanguard Rank → 포인트 변환, JSON 로컬 누적)
- [x] 포인트 3단 표시 (오늘·주간·누적) + 리더보드/설정 버튼
- [x] Settings UI (닉네임, opt-in 토글, 제출 데이터 미리보기)
- [x] 주간 토큰 누적 히어로 넘버 옆 표시

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
- [x] .app 번들 빌드 스크립트 (build-app.sh, CLI + Go 바이너리 + 아이콘 포함)
- [x] Homebrew Cask (`brew install --cask glen15/dxai/dxai`)
- [x] Homebrew Formula (CLI: `brew install dxai`)
- [x] GitHub Actions release.yml (태그 → Go 빌드 → Swift 앱 빌드 → 릴리스 → Homebrew 업데이트)
- [x] 독립 레포 (glen15/dxai, 클린 히스토리)
- [x] README.md (영문), README.ko.md (한국어)
- [x] AWS 웹 배포 (S3 + CloudFront + Route 53, vanguard.dx-ai.cloud)
- [x] DXAI 로고 아이콘 (AppIcon.icns 자동 생성)

### 미구현 / 향후 계획

#### Phase 1 — 릴리스 ✅
- [x] 첫 릴리스 태그 (V1.0.0 → V1.0.3 배포 완료)
- [x] Homebrew Tap 레포 생성 (`glen15/homebrew-dxai`)
- [x] Homebrew Cask: `brew install --cask glen15/dxai/dxai`
- [x] GitHub Actions CI/CD (빌드 → 릴리스 → Homebrew 자동 업데이트)
- [x] CLI 앱 번들 내장 (Resources/dxai + bin/ + lib/)
- [x] Go 바이너리 CI 빌드 포함 (analyze-go, status-go)
- [x] 닉네임/opt-in 설정 시 리더보드 즉시 제출
- [x] 사용자 확보 (사내 배포, 실 사용자 5명: DXAI, ELLA, karin, RIKA, MacMini)

#### Phase 2 — Vanguard 랭킹 서비스 ✅
- [x] Vanguard Point 로컬 시스템 (포인트 공식, JSON 영속화, 3단 표시)
- [x] Settings UI (닉네임 설정, opt-in 토글, 제출 데이터 미리보기)
- [x] Supabase 백엔드 (Edge Functions: submit-daily, leaderboard)
- [x] 앱→서버 제출 로직 (URLSession, 실패 시 로컬 큐 재시도)
- [x] Vanguard 랭킹 웹사이트 (Next.js + Tailwind + Magic UI)
- [x] Supabase Realtime 실시간 리더보드 (Live 탭)
- [x] 개인 프로필 페이지 (/user/?name=NICKNAME)
- [x] KST 타임존 통일 (Live/Daily/Weekly/Monthly)
- [x] 한/영 다국어 UI
- [x] 웹 배포 (AWS S3 + CloudFront, vanguard.dx-ai.cloud)
- [x] DXAI 로고 아이콘 (앱 아이콘 + About + 웹 navbar + favicon)

> **제출 데이터**: 닉네임, 일일 토큰 합계(도구별), 일일 Vanguard Point, 누적 포인트, 타임스탬프
> **수집하지 않는 것**: 프로젝트명, 프롬프트, 파일 경로, 대화 내용
> Vanguard Point는 AI 활용도를 보여주는 스펙/지표로 활용

#### Phase 3 — 확장 ✅
- [x] Apple Developer Program 등록 + 승인 (JEONGHUN LEE, Y6DMY4SBGN)
- [x] Developer ID 서명 + Apple 공증 + Staple (Gatekeeper 경고 제거)
- [x] Cloudflare → AWS 마이그레이션 (S3 + CloudFront + Route 53)
- [x] Terraform IaC 전환 (infra/main.tf)
- [x] 보안 강화 (API key 인증, RLS, CORS, rate limit, 보안 헤더)
- [x] 코드 정리 (미사용 의존성/CSS/함수 제거, 코드맵 업데이트)
- [ ] Homebrew Core 등록 (GitHub 30+ 스타 필요, 대기)

#### Phase 4 — 업적/배지 시스템
- [x] 업적 설계 (6카테고리 36개, 4단계 희귀도)
- [x] DB 스키마 (achievements + user_achievements + RPC + backfill)
- [x] Edge Function (submit-daily 업적 판정 + leaderboard 업적 조회)
- [ ] 앱 알림 (업적 달성 시 macOS 네이티브 알림)
- [x] 웹 프로필 배지 표시 (달성한 업적 목록)
- [x] 웹 업적 갤러리 (/achievements, 전체 업적 + 달성률)

## Vanguard Rank 시스템

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
| Vanguard 웹 | Next.js 16, Tailwind CSS 4, Magic UI, AWS S3 + CloudFront |
| 인프라 | Terraform, Route 53, ACM, CloudFront OAC |
| Vanguard 백엔드 | Supabase (Edge Functions, Realtime, PostgreSQL) |

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
│   │   ├── Localization.swift     # EN/KR 문자열
│   │   ├── SettingsView.swift    # 닉네임/opt-in 설정
│   │   └── DxaiPointService.swift # 포인트 시스템 + 서버 제출
│   └── scripts/build-app.sh       # .app 번들 빌더 (아이콘 + CLI 번들)
├── homebrew/
│   ├── Formula/dxai.rb            # CLI formula
│   └── Casks/dxai.rb              # 메뉴바 앱 cask
├── web/                           # Vanguard 랭킹 웹사이트 (Next.js)
│   └── src/app/                   # 페이지 및 컴포넌트
├── supabase/
│   ├── functions/                 # Edge Functions (submit-daily, leaderboard)
│   └── migrations/                # DB 스키마 마이그레이션
├── tests/                         # Bats 테스트
├── scripts/                       # 빌드/체크 스크립트
├── docs/prd.md                    # 이 문서
└── .github/workflows/release.yml  # CI/CD
```
