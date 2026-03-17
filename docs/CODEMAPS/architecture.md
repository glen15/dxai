# DXAI 전체 아키텍처

**마지막 업데이트:** 2026-03-17
**레포:** glen15/dxai (public)
**브랜딩:** DXAI (회사) / Vanguard (랭킹 서비스)

## 시스템 구성도

```
                          +---------------------+
                          |   Vanguard Web      |
                          |   (Next.js 16)      |
                          |  AWS S3 + CloudFront |
                          +----------+----------+
                                     |
                                     | fetch / Realtime
                                     v
+------------------+        +--------+---------+
|  DxaiBar App     | POST   |   Supabase       |
|  (macOS MenuBar) +------->+   Edge Functions  |
|  SwiftUI         |  15s   |   (Deno/TS)      |
+--------+---------+        +--------+---------+
         |                           |
         | .jsonl 파싱               | PostgreSQL
         v                           v
+------------------+        +------------------+
| ~/.claude/       |        |  Supabase DB     |
| ~/.codex/        |        |  (Seoul Region)  |
| (로컬 토큰 로그) |        |  users +         |
+------------------+        |  daily_records   |
                            +------------------+
         +
         | CLI 실행
         v
+------------------+
|  dxai CLI        |
|  (Bash + Python  |
|   + Go)          |
+------------------+
```

## 4개 영역

| 영역 | 기술 스택 | 진입점 | 코드맵 |
|------|----------|--------|--------|
| macOS 앱 | SwiftUI, Swift Package Manager, Sparkle | `app/DxaiBar/Sources/DxaiBarApp.swift` | [frontend.md](frontend.md) |
| Vanguard 웹 | Next.js 16, React 19, Tailwind 4, Supabase JS | `web/src/app/page.tsx` | [frontend.md](frontend.md) |
| Supabase 백엔드 | Deno Edge Functions, PostgreSQL, Realtime | `supabase/functions/` | [backend.md](backend.md) |
| CLI 도구 | Bash, Python 3, Go (bubbletea TUI) | `dxai` (bash) | [backend.md](backend.md) |

## 핵심 데이터 흐름

### 1. 토큰 수집 (로컬)
```
Claude Code .jsonl  -+
                     +-> DxaiDatabase.swift (파싱)
Codex CLI .jsonl    -+       |
                             v
                     DxaiViewModel.swift (집계)
                             |
                     15초 타이머 refresh()
```

### 2. 서버 제출
```
DxaiViewModel.refresh()
  -> DxaiPointService.recordDailyBest()
    -> submitToServer() [POST]
      -> submit-daily Edge Function
        -> users + daily_records upsert
        -> 응답: total_coins, total_tokens, live_rank
```

### 3. 웹 리더보드
```
page.tsx (Client)
  -> fetchLeaderboard() [GET]
    -> leaderboard Edge Function
      -> PostgreSQL RPC (leaderboard_daily_by_tokens 등)
  <- rankings JSON

Supabase Realtime (postgres_changes)
  -> daily_records 변경 감지
  -> 자동 새로고침
```

## Vanguard Rank 시스템

8 티어 x 5 디비전 = 36 레벨 + Challenger

| 티어 | 토큰 범위 (일일) | 코인 (base+bonus) |
|------|-----------------|-------------------|
| Bronze | 10K ~ 250K | 10 + 2/div |
| Silver | 500K ~ 5M | 25 + 5/div |
| Gold | 8M ~ 35M | 60 + 12/div |
| Platinum | 50M ~ 170M | 150 + 30/div |
| Diamond | 220M ~ 520M | 350 + 70/div |
| Master | 620M ~ 1.2B | 800 + 160/div |
| Grandmaster | 1.5B ~ 3.3B | 1800 + 360/div |
| Challenger | 5B+ | 5000 (고정) |

Account Level: 누적 토큰 기반, `Lv.N = 1M * 2^(N-2)` 무한 성장

## 배포

| 대상 | 방법 | 도메인/경로 |
|------|------|-------------|
| macOS 앱 | GitHub Release -> Homebrew Cask | `brew install --cask glen15/dxai/dxai` |
| CLI | GitHub Release -> Homebrew Formula | `brew install glen15/dxai/dxai` |
| 웹 | `npm run deploy` (S3 sync + CloudFront 무효화) | `vanguard.dx-ai.cloud` |
| 인프라 | Terraform (`infra/main.tf`) | Route 53 + ACM + S3 + CloudFront |
| Edge Functions | `supabase functions deploy` | `ldsqtmirplfgclzessrd.supabase.co` |

## 관련 코드맵

- [frontend.md](frontend.md) -- macOS 앱 + 웹 프론트엔드
- [backend.md](backend.md) -- Edge Functions + CLI + Go 프로그램
- [data.md](data.md) -- DB 스키마, 마이그레이션, 데이터 모델
