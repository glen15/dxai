# 프론트엔드 코드맵

**마지막 업데이트:** 2026-03-17

## A. macOS 메뉴바 앱 (DxaiBar)

**프레임워크:** SwiftUI (MenuBarExtra, macOS 13+)
**빌드:** Swift Package Manager + Sparkle 2
**진입점:** `app/DxaiBar/Sources/DxaiBarApp.swift`

### 모듈 구조

```
app/DxaiBar/Sources/
├── DxaiBarApp.swift        # @main, MenuBarExtra(.window), 중복 실행 방지
├── DxaiViewModel.swift     # 핵심 상태 관리 (ObservableObject)
├── DxaiDatabase.swift      # .jsonl 파서 (Claude/Codex 토큰 직접 파싱)
├── DxaiPointService.swift  # Vanguard Coin + 서버 제출 + pending queue
├── DxaiMenuView.swift      # 메인 UI (대시보드, Quick Actions, 탭)
├── InsightsView.swift      # 주간 인사이트 (차트, 트렌드, 캐시 적중률)
├── StatusPanelView.swift   # 시스템 상태 (CPU, 메모리, 디스크, 배터리)
├── ScanPanelView.swift     # AI 환경 스캔 결과 (MCP, Skills, Projects)
├── SettingsView.swift      # 닉네임, 랭킹 참여, 자동 업데이트
├── UpdaterManager.swift    # Sparkle 2 자동 업데이트
├── DxaiColors.swift        # 적응형 컬러 팔레트 (다크/라이트)
└── Localization.swift      # L 구조체 (한/영 전체 문자열)
```

### 모듈 의존성

| 모듈 | 의존 대상 | 역할 |
|------|----------|------|
| DxaiBarApp | DxaiViewModel, UpdaterManager, DxaiMenuView | 앱 진입, 메뉴바 등록 |
| DxaiViewModel | DxaiDatabase, DxaiPointService, L | 토큰 집계, 알림, 타이머(15s), 태스크 실행 |
| DxaiDatabase | (로컬 파일시스템) | Claude/Codex .jsonl 파싱, Quota API 호출 |
| DxaiPointService | (URLSession, 로컬 JSON) | 코인 계산, 서버 제출, pending queue 관리 |
| DxaiMenuView | DxaiViewModel, InsightsView, SettingsView, DxaiColors, L | 전체 UI 조합 |
| StatusPanelView | DxaiColors | JSON -> 시스템 상태 시각화 |
| ScanPanelView | DxaiColors, L, FlowLayout | JSON -> AI 환경 시각화 |

### 핵심 타입

```
DxaiViewModel.VanguardLevel    # 8티어 x 5디비전 + Challenger
DxaiViewModel.MilestoneInfo    # 14단계 토큰 마일스톤 (2천만 ~ 20억)
DxaiDatabase.DailyStats        # 일별 도구별 토큰 통계
DxaiDatabase.QuotaInfo         # Claude/Codex 쿼터 (5h/7d)
DxaiPointService.PointConfig   # 닉네임, UUID, opt-in
DxaiPointService.DailyRecord   # 일별 코인/토큰 기록
DxaiPointService.SubmissionPayload  # 서버 제출 페이로드
SystemStatus                   # CLI `dxai status --json` 파싱 결과
ScanResult                     # CLI `dxai scan --json` 파싱 결과
```

### 외부 의존성

| 패키지 | 용도 |
|--------|------|
| Sparkle 2 | 자동 업데이트 (appcast.xml) |
| ServiceManagement | 로그인 시 자동 시작 |
| UserNotifications | 티어 승급/마일스톤 알림 |

---

## B. Vanguard 웹 (Next.js)

**프레임워크:** Next.js 16.1.6 (App Router, `output: "export"` 정적 빌드)
**배포:** AWS S3 + CloudFront (Terraform IaC)
**도메인:** vanguard.dx-ai.cloud (Route 53 + ACM)
**진입점:** `web/src/app/layout.tsx`

### 파일 구조

```
web/src/
├── app/
│   ├── layout.tsx              # 루트 레이아웃 (nav, footer, ClickSpark)
│   ├── page.tsx                # 메인 리더보드 (Live/Daily/Ranking/Search 탭)
│   ├── globals.css             # Tailwind + 커스텀 스타일
│   └── user/
│       └── page.tsx            # 개인 프로필 (?name= 쿼리 파라미터)
├── components/
│   ├── ranking-view.tsx        # Ranking 탭 (누적 토큰 기준)
│   ├── search-view.tsx         # Search 탭 (닉네임 검색)
│   ├── shared.tsx              # TierBadge, TIER_COLORS, TIER_BG
│   └── ui/
│       ├── animated-gradient-text.tsx
│       ├── border-beam.tsx
│       ├── click-spark.tsx
│       ├── number-ticker.tsx
│       └── sparkles-text.tsx
└── lib/
    ├── supabase.ts             # Supabase 클라이언트 + API 함수 + 유틸리티
    └── utils.ts                # cn() (clsx + tailwind-merge)
```

### 주요 컴포넌트

| 컴포넌트 | 위치 | 역할 |
|----------|------|------|
| Home (default) | `page.tsx` | 4탭 리더보드, PodiumCard, RankRow, Realtime 구독 |
| RankingView | `ranking-view.tsx` | 누적 토큰 글로벌 랭킹 |
| SearchView | `search-view.tsx` | 닉네임 검색 (debounce) |
| UserProfile | `user/page.tsx` | 개인 프로필 (?name= 쿼리, 30일 히스토리) |
| TierBadge | `shared.tsx` | 티어 배지 (SparklesText for Challenger) |

### lib/supabase.ts 공개 API

| 함수/타입 | 용도 |
|-----------|------|
| `fetchLeaderboard(type, params, page)` | Edge Function 호출 |
| `fetchSearch(query)` | 닉네임 검색 |
| `fetchUserProfile(nickname)` | 프로필 조회 |
| `formatTokens(n)`, `formatHeroTokens(n, lang)` | 숫자 포맷 |
| `vanguardMessage(tier, div, lang)` | 등급별 메시지 (36개) |
| `tokenMilestone(tokens, lang)` | 14단계 마일스톤 텍스트 |
| `calculateLevel(tokens)` | 누적 토큰 -> 레벨 |
| `tierProgress(tokens)` | 프로그레스 바 진행도 |
| `t(key, lang)` | 한/영 UI 문자열 |

### 외부 의존성

| 패키지 | 용도 |
|--------|------|
| @supabase/supabase-js | Supabase 클라이언트 + Realtime |
| motion | 애니메이션 (AnimatePresence, motion.div) |
| tailwind-merge + clsx | 클래스 유틸리티 |

### 데이터 흐름

```
page.tsx
  ├── fetchLeaderboard() -> leaderboard Edge Function -> PostgreSQL
  ├── Supabase Realtime (postgres_changes on daily_records)
  │   -> load(true) -> diff 감지 -> token-diff CSS 깜빡임
  └── 탭 전환: realtime | daily | ranking | search
```

## 관련 코드맵

- [architecture.md](architecture.md) -- 전체 아키텍처
- [backend.md](backend.md) -- Edge Functions, CLI
- [data.md](data.md) -- DB 스키마
