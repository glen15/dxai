# 데이터 모델 코드맵

**마지막 업데이트:** 2026-03-17
**DB:** Supabase PostgreSQL (Seoul, ldsqtmirplfgclzessrd)

## 테이블 스키마

### users

```sql
id            UUID PK DEFAULT gen_random_uuid()
device_uuid   TEXT NOT NULL UNIQUE
nickname      TEXT NOT NULL UNIQUE
total_coins   INT NOT NULL DEFAULT 0
last_tier     TEXT
last_division INT
created_at    TIMESTAMPTZ DEFAULT now()
updated_at    TIMESTAMPTZ DEFAULT now()
```

**인덱스:** nickname, total_coins DESC

### daily_records

```sql
id               UUID PK DEFAULT gen_random_uuid()
user_id          UUID NOT NULL FK -> users(id) ON DELETE CASCADE
date             DATE NOT NULL
daily_coins      INT NOT NULL CHECK (0..5000)
claude_tokens    BIGINT NOT NULL DEFAULT 0
codex_tokens     BIGINT NOT NULL DEFAULT 0
vanguard_tier    TEXT NOT NULL
vanguard_division INT
created_at       TIMESTAMPTZ DEFAULT now()

UNIQUE(user_id, date)
```

**인덱스:** date DESC, (user_id, date) DESC

## RLS (Row Level Security)

| 테이블 | anon | service_role |
|--------|------|-------------|
| users | - (차단) | ALL |
| daily_records | SELECT (Realtime용) | ALL |

Edge Functions는 `SUPABASE_SERVICE_ROLE_KEY`로 쓰기 수행.

## PostgreSQL RPC 함수

| 함수 | 용도 | 정렬 |
|------|------|------|
| `leaderboard_daily_by_tokens(date, limit, offset)` | 일별 토큰 랭킹 | claude+codex DESC |
| `leaderboard_weekly_enhanced(start, end, limit, offset)` | 주간 코인 랭킹 | period_coins DESC |
| `leaderboard_monthly_enhanced(start, end, limit, offset)` | 월간 코인 랭킹 | period_coins DESC |
| `leaderboard_total_enhanced(limit, offset)` | 누적 코인 랭킹 | total_coins DESC |
| `leaderboard_by_tokens(limit, offset)` | 누적 토큰 글로벌 랭킹 | total_tokens DESC |
| `leaderboard_period_count(start, end)` | 기간 내 활성 유저 수 | - |
| `tier_distribution(start, end)` | 기간 내 티어 분포 | - |
| `search_users(query, limit)` | 닉네임 검색 (ILIKE) | - |

## 마이그레이션 히스토리

| 버전 | 파일 | 내용 |
|------|------|------|
| 20260308000000 | initial.sql | users, daily_records 테이블 + RLS |
| 20260308000001 | leaderboard_functions.sql | leaderboard_period RPC |
| 20260311000000 | rename_pioneer_to_vanguard.sql | pioneer_tier -> vanguard_tier 리네이밍 |
| 20260311100000 | enhanced_leaderboard.sql | weekly/monthly/total enhanced RPC |
| 20260311110000 | monthly_daily_breakdown.sql | monthly 일별 분석 |
| 20260311120000 | token_ranking_and_search.sql | 토큰 기반 랭킹 + 검색 RPC |
| 20260311130000 | seed_dummy_users.sql | 더미 데이터 시드 |
| 20260311140000 | daily_leaderboard_by_tokens.sql | 일별 토큰 기준 랭킹 RPC |
| 20260311150000 | remove_points_use_coins.sql | daily_points 컬럼 제거 |
| 20260311160000 | delete_dummy_data.sql | 더미 데이터 삭제 |
| 20260312000000 | seed_20_dummy_users.sql | 20명 더미 유저 시드 |
| 20260315000000 | daily_rpc_add_total_tokens.sql | daily RPC에 total_tokens 추가 |
| 20260316000000 | user_token_rank.sql | 누적 토큰 기반 순위 컬럼 추가 |
| 20260316100000 | rls_restrict_anon_select.sql | anon SELECT 제한 |
| 20260316200000 | rls_anon_read_for_realtime.sql | Realtime 구독용 정책 복원 |
| 20260316300000 | add_secret_token.sql | 코인 인증용 secret_token |
| 20260317000000 | remove_users_anon_read.sql | users 테이블 anon SELECT 차단 |
| 20260317100000 | delete_dummy_users.sql | 더미 유저 전체 삭제 |

## 로컬 데이터 (앱)

### DxaiDatabase (로컬 파싱, DB 미사용)

```
소스: ~/.claude/projects/**/*.jsonl   (Claude Code 로그)
소스: ~/.codex/sessions/**/*.jsonl    (Codex CLI 로그)
캐시: 인메모리 (weeklyCache + fingerprint)
```

### DxaiPointService (로컬 JSON 영속화)

```
~/.config/dxai/points/
├── config.json    # { nickname, optIn, deviceUUID, lastRecordedDate }
├── history.json   # DailyRecord[] (최근 365일)
└── pending.json   # SubmissionPayload[] (미제출 큐, 최대 30건)
```

## Vanguard Coin 공식

```
코인 = base + bonus * (5 - division)

Challenger: 5000 (고정)
기타: COIN_TABLE[tier].base + COIN_TABLE[tier].bonus * (5 - division)
```

앱/서버 양쪽에서 동일한 coinTable로 검증 (coins_mismatch 에러).

## Supabase Realtime

```
채널: leaderboard-realtime
이벤트: postgres_changes (INSERT/UPDATE on daily_records)
구독자: web/src/app/page.tsx
```

## 관련 코드맵

- [architecture.md](architecture.md) -- 전체 아키텍처
- [frontend.md](frontend.md) -- 데이터 소비 측
- [backend.md](backend.md) -- 데이터 생산/제공 측
