# 백엔드 코드맵

**마지막 업데이트:** 2026-03-17

## A. Supabase Edge Functions

**런타임:** Deno (Supabase hosted)
**프로젝트:** ldsqtmirplfgclzessrd (Seoul)
**배포:** `supabase functions deploy --no-verify-jwt`

### Edge Functions

| 함수 | 경로 | 메서드 | 역할 |
|------|------|--------|------|
| submit-daily | `supabase/functions/submit-daily/index.ts` | POST | 앱 -> 서버 일일 기록 제출 |
| leaderboard | `supabase/functions/leaderboard/index.ts` | GET | 리더보드 + 프로필 + 검색 |

### submit-daily

**흐름:** 요청 검증 -> 유저 upsert -> 기록 upsert -> 누적 재계산 -> 순위 반환

| 단계 | 상세 |
|------|------|
| 검증 | device_uuid, nickname(2-16자), date(7일 이내), coins-tier 매칭, rate limit(10/분) |
| 유저 | device_uuid로 조회 -> 있으면 update, 없으면 insert (nickname unique 제약) |
| 기록 | (user_id, date) unique -> 높은 코인만 업데이트, 토큰은 항상 갱신 |
| 응답 | `{ ok, total_coins, total_tokens, rank, live_rank }` |

### leaderboard

**라우팅:** `?type=` 파라미터로 7가지 모드

| 타입 | RPC / 쿼리 | 정렬 기준 |
|------|-----------|----------|
| realtime | `leaderboard_daily_by_tokens(date=today)` | 오늘 토큰 합계 DESC |
| daily | `leaderboard_daily_by_tokens(date=param)` | 해당일 토큰 합계 DESC |
| weekly | `leaderboard_weekly_enhanced(start, end)` | 주간 코인 합계 |
| monthly | `leaderboard_monthly_enhanced(start, end)` + `tier_distribution` | 월간 코인 합계 |
| total | `leaderboard_total_enhanced` | 누적 코인 DESC |
| ranking | `leaderboard_by_tokens` | 누적 토큰 DESC |
| search | `search_users(query)` | 닉네임 LIKE |

**프로필:** `?user=NICKNAME` -> 30일 히스토리, 주간/월간 통계, streak, 순위

### 공통 헬퍼

```
nowKST()           -- UTC+9 현재 시각
todayDateString()  -- KST 기준 오늘 날짜
parsePeriod()      -- YYYY-Wxx / YYYY-MM 파싱
calculateStreak()  -- 연속 활동일 계산
```

---

## B. CLI (dxai)

**진입점:** `dxai` (Bash script, v1.29.0)
**구조:** 서브커맨드 라우팅 -> bin/ 스크립트 위임

### 서브커맨드 매핑

| 커맨드 | 실행 파일 | 언어 | 역할 |
|--------|----------|------|------|
| `dxai ai` | `bin/ai.py` | Python 3 | AI 토큰 대시보드 (Claude+Codex) |
| `dxai scan` | `bin/scan.py` | Python 3 | AI 환경 스캔 (MCP, Skills, Projects) |
| `dxai status` | `bin/status-go` | Go (bubbletea) | 시스템 모니터링 TUI/JSON |
| `dxai analyze` | `bin/analyze-go` | Go (bubbletea) | 디스크 분석 TUI/JSON |
| `dxai clean` | `bin/clean.sh` | Bash | 캐시/로그/임시파일 정리 |
| `dxai optimize` | `bin/optimize.sh` | Bash | 메모리/DNS/네트워크 튜닝 |
| `dxai check` | `bin/check.sh` | Bash | 시스템 헬스 체크 |
| `dxai purge` | `bin/purge.sh` | Bash | 완전 삭제 |

### Go 프로그램 구조

```
cmd/
├── status/                 # dxai status (시스템 모니터링)
│   ├── main.go            # 진입점, --json 플래그
│   ├── metrics.go         # 메트릭 수집 오케스트레이터
│   ├── metrics_cpu.go     # CPU 사용률
│   ├── metrics_memory.go  # 메모리/스왑
│   ├── metrics_disk.go    # 디스크 사용량
│   ├── metrics_network.go # 네트워크 인터페이스
│   ├── metrics_battery.go # 배터리
│   ├── metrics_gpu.go     # GPU
│   ├── metrics_hardware.go # 하드웨어 정보
│   ├── metrics_health.go  # 헬스 스코어
│   ├── metrics_process.go # 상위 프로세스
│   ├── metrics_bluetooth.go # 블루투스
│   └── view.go            # Bubble Tea TUI 뷰
└── analyze/                # dxai analyze (디스크 분석)
    ├── main.go            # 진입점
    ├── scanner.go         # 디렉토리 스캔
    ├── cleanable.go       # 정리 가능 항목 감지
    ├── cache.go           # 결과 캐시
    ├── delete.go          # 삭제 실행
    ├── format.go          # 크기 포맷
    ├── heap.go            # 대용량 파일 힙
    ├── json.go            # JSON 출력
    ├── view.go            # Bubble Tea TUI 뷰
    └── constants.go       # 상수
```

### Bash 라이브러리 구조

```
lib/
├── core/                   # 공통 유틸리티
│   ├── common.sh          # 환경 감지, 상수
│   ├── commands.sh        # 서브커맨드 라우팅
│   ├── base.sh            # 기본 함수
│   ├── log.sh             # 로깅
│   ├── ui.sh              # UI 헬퍼
│   ├── help.sh            # 도움말
│   ├── sudo.sh            # sudo 관리
│   ├── timeout.sh         # 타임아웃
│   ├── file_ops.sh        # 파일 작업
│   └── app_protection.sh  # 앱 보호
├── clean/                  # 정리 모듈 (8개 파일)
├── check/                  # 헬스 체크
├── manage/                 # 관리 (자동수정, 업데이트, 화이트리스트)
├── optimize/               # 최적화
├── ui/                     # 메뉴 UI (paginated, simple)
└── uninstall/              # 제거 (brew, batch)
```

### Python 스크립트

| 파일 | 역할 |
|------|------|
| `bin/ai.py` | AI 토큰 대시보드: .jsonl 파싱, 쿼터 조회, 실시간 모니터링 |
| `bin/scan.py` | AI 환경 스캔: Claude/Codex 설정, MCP, Skills, 활성 세션, 포트 |
| `bin/telemetry.py` | 텔레메트리 수집 |
| `lib/ai/db.py` | AI 데이터 DB 헬퍼 |

## 관련 코드맵

- [architecture.md](architecture.md) -- 전체 아키텍처
- [frontend.md](frontend.md) -- macOS 앱 + 웹
- [data.md](data.md) -- DB 스키마
