# dxai - Deus Ex AI

> Clean, optimize, and manage AI dev environments on your Mac

## 개요

dxai는 [Mole](https://github.com/tw93/Mole)(MIT 라이선스)을 fork하여, AI 개발 환경에 특화된 Mac 최적화 도구로 확장한 프로젝트다. 기존 Mole의 시스템 정리/최적화 기능을 전부 유지하면서, Claude Code/Codex/Gemini 등 AI 코딩 도구 사용자를 위한 기능을 추가한다.

- **원본**: https://github.com/tw93/Mole
- **Fork**: https://github.com/glen15/dxai
- **라이선스**: MIT

## 타겟 사용자

**우선순위:**

1. **Claude Code 사용자** — 1순위. 핵심 타겟
2. **Codex CLI 사용자** — 2순위
3. **Gemini CLI 사용자** — 3순위

여러 도구를 함께 사용하는 사용자일수록 더 큰 효과를 얻는다 (통합 대시보드, 통합 스캔).

- Mac 환경에서 AI 코딩 도구를 일상적으로 사용하는 개발자
- 토큰 비용을 추적하고 환경을 최적화하고 싶은 사용자

## 아키텍처

```
dxai
├── CLI (Shell + Go) — 터미널 인터페이스
│   ├── 기존 Mole 기능 전체 (리브랜딩)
│   ├── dxai ai       — AI 토큰 사용량 통합 대시보드 + Pioneer Alert
│   ├── dxai scan     — AI 에이전트 환경 진단 보고서
│   └── dxai telemetry — Opt-in 익명 텔레메트리
│
├── 데이터 레이어
│   ├── SQLite        — 로컬 시계열 데이터 축적 (~/.config/dxai/dxai.db)
│   └── Telemetry     — 가공된 인사이트 숫자만 익명 전송 (opt-in)
│
└── Swift 네이티브 앱 — macOS GUI
    ├── 메뉴바        — 토큰 사용량 실시간 표시 + 클릭 시 대시보드
    └── 알림          — Pioneer Alert 네이티브 알림
```

## 기존 기능 (Mole에서 유지)

리브랜딩: `mo` -> `dxai`

| 커맨드 | 기능 |
|--------|------|
| `dxai clean` | 시스템 캐시, 로그, 브라우저 잔여물 정리 |
| `dxai uninstall` | 앱 + 숨겨진 잔여 파일 완전 삭제 |
| `dxai optimize` | 시스템 DB 재구성, 서비스 리프레시 |
| `dxai analyze` | 디스크 사용량 시각화, 대용량 파일 탐색 |
| `dxai status` | 실시간 시스템 모니터링 (CPU/GPU/메모리/디스크/네트워크) |
| `dxai purge` | 프로젝트 빌드 산출물 정리 (node_modules 등) |
| `dxai installer` | 설치 파일(.dmg/.pkg) 정리 |
| `dxai touchid` | Touch ID로 sudo 설정 |
| `dxai completion` | Shell 자동완성 설정 |
| `dxai update` | dxai 업데이트 |

## 신규 기능

### 1. `dxai ai` — AI 토큰 사용량 통합 대시보드

기존 [ai-usage-monitor](https://github.com/glen15/ai-usage-monitor) 프로젝트의 `ccu` CLI 로직을 통합한다.

**서브커맨드:**

| 커맨드 | 기능 |
|--------|------|
| `dxai ai` | 전체 요약 (Claude + Codex + Gemini) |
| `dxai ai claude` | Claude 상세 (토큰, 비용, 모델별) |
| `dxai ai codex` | Codex 상세 |
| `dxai ai gemini` | Gemini 상세 |
| `dxai ai today` | 오늘 사용량 |
| `dxai ai week` | 최근 7일 |
| `dxai ai month` | 최근 30일 |
| `dxai ai watch` | 실시간 모니터링 |
| `dxai ai json` | JSON 출력 (스크립트 연동용) |

**데이터 소스:** (기존 [ai-usage-monitor](https://github.com/glen15/ai-usage-monitor)의 `ccu` 로직 기반)

- **Claude**
  - 할당량: `~/.claude/plugins/claude-hud/.usage-cache.json` 캐시 → `api.anthropic.com/api/oauth/usage` API 폴백
  - 토큰 통계: `~/.claude/projects/**/*.jsonl` 파싱 (input/output/cache_read/cache_creation 토큰)
  - 인증: `~/.claude/.credentials.json` → macOS Keychain 폴백

- **Codex**
  - 할당량: `~/.codex/auth.json`의 OAuth 토큰으로 `chatgpt.com/backend-api/wham/usage` 조회
  - 폴백: `~/.codex/sessions/**/*.jsonl`에서 `rate_limits` 이벤트 파싱
  - 토큰 통계: `~/.codex/sessions/**/*.jsonl`의 `token_count` 이벤트 파싱 (input/output/reasoning_output 토큰)

- **Gemini**
  - 구독(Gemini CLI): `~/.terminai/tmp/**/chats/session-*.json` 파싱 (input/output/cached/thoughts/tool 토큰)
  - API Key: Google Cloud Monitoring API로 `generativelanguage.googleapis.com` 지표 조회 (요청 수, 입력 토큰)
  - 인증: `~/.terminai/oauth_creds.json` 또는 `~/.gemini/oauth_creds.json`, ADC(`~/.config/gcloud/application_default_credentials.json`)

**비용 추정:**

현재 ccu는 Gemini API Key만 비용 추정 (`입력 토큰 × $0.10/1M`, Gemini 2.0 Flash 기준). Claude/Codex는 구독 기반이므로 할당량(%) 표시가 주된 지표. 향후 API 과금 사용자를 위해 모델별 가격표를 `~/.config/dxai/pricing.json`으로 관리하고, 자동 업데이트를 지원한다.

**표시 항목:**

- 입력/출력 토큰 수
- 캐시 읽기/생성 토큰 (프롬프트 캐싱 효율 확인)
- 모델별 사용량 breakdown
- 세션 수
- AI 도구별 디스크 점유량

**알림 (Pioneer Alert):**

토큰을 많이 쓰고 있으면 경고가 아니라 **칭찬**한다. AI 도구를 적극 활용하는 사용자는 파이오니어다.

임계치 기반 macOS 네이티브 알림 예시:

| 단계 | 조건 | 알림 메시지 |
|------|------|-------------|
| Bronze | 일 50K 토큰 돌파 | "오늘도 AI와 함께 시작! 🚀" |
| Silver | 일 500K 토큰 돌파 | "당신은 AI 시대의 파이오니어입니다 🏄" |
| Gold | 일 1M 토큰 돌파 | "1M 토큰 돌파! 오늘 진짜 일했다 🔥" |
| Diamond | 일 5M 토큰 돌파 | "전설의 5M... 당신이 곧 AI 시대 그 자체 💎" |

- 임계치는 `~/.config/dxai/config.toml`에서 커스터마이징 가능
- `dxai ai watch` 모드에서 실시간 감지
- 알림 끄기: `[alerts] pioneer = false`

### 2. `dxai scan` — AI 에이전트 환경 진단 보고서

내 AI 에이전트들이 **뭘 할 줄 알고**, **뭘 해왔고**, **지금 뭘 하는지** 한눈에 파악하는 진단 도구.

**프로젝트 탐색 범위:** `config.toml`의 `[scan] project_dirs`에 설정된 경로를 스캔한다. 기본값은 `["~/Desktop/work"]`. 각 경로의 하위 디렉토리에서 **AI 도구 흔적**이 있는 디렉토리를 프로젝트로 인식한다.

탐지 시그널 (하나라도 있으면 AI 프로젝트로 인식):

| 도구 | 디렉토리 | 파일 |
|------|----------|------|
| Claude Code | `.claude/` | `CLAUDE.md` |
| Codex | `.codex/` | `AGENTS.md` |
| Gemini | `.gemini/` | `GEMINI.md` |

**데이터 소스:**

| 도구 | 글로벌 설정 | 프로젝트별 설정 | 세션 이력 |
|------|-------------|-----------------|-----------|
| Claude Code | `~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.claude/mcp.json` | `<project>/.claude/CLAUDE.md`, `<project>/.claude/skills/`, `<project>/.claude/mcp.json` | `~/.claude/projects/**/*.jsonl` |
| Codex | `~/.codex/` 설정 | 프로젝트별 설정 | Codex CLI 로그 |
| Gemini | Gemini 설정 | 프로젝트별 설정 | Gemini API 로그 |

**포트 스캔:** `lsof -nP -iTCP -sTCP:LISTEN`으로 리스닝 포트를 수집하고 프로세스 정보(PID, 커맨드, 작업 디렉토리)를 매핑한다. 포트 파싱 로직은 [PortMan](https://github.com/Kwondongkyun/PortMan)의 `LsofParser`를 참고한다.

**출력 예시:**

```bash
$ dxai scan

dxai Agent Report
==========================================

[Global Setup]
  CLAUDE.md              ✓  (412 lines)
  Skills                 14개 (pptx, magi-system, ralph, tdd, ...)
  MCP Servers            5개 (notion, gmail, calendar, nxtflow, canva)

[Projects]  (~/Desktop/work/)
  dxai/
    CLAUDE.md            ✓
    Skills               2개 (build-fix, test-coverage)
    MCP                  글로벌 상속
    최근 세션            3시간 전 — "prd 확인"
    총 세션 수           12 (이번 주 5)

  my-app/
    CLAUDE.md            ✗  없음
    Skills               글로벌만
    MCP                  +supabase (프로젝트 전용)
    최근 세션            2일 전 — "로그인 버그 수정"
    총 세션 수           34 (이번 주 0)

[Active Sessions]
  dxai/                  실행 중 (PID 12345)

[Active Ports]
  :3000    node (Next.js)     PID 45123   ~/work/my-app/
  :5173    node (Vite)        PID 45200   ~/work/dxai/
  :8080    python (FastAPI)   PID 45300   ~/work/api-server/
  총 리스닝 포트: 12개 (dev: 8, system: 4)

[Summary]
  전체 프로젝트          8개
  CLAUDE.md 없는 프로젝트  3개
  이번 주 활성 프로젝트    4개
  총 세션 수 (30일)       127
==========================================
```

**보고서 섹션:**

1. **Global Setup** — 글로벌 CLAUDE.md, 스킬 목록, MCP 서버 목록
2. **Projects** — 프로젝트별 설정 현황, 스킬/MCP 상속 관계, 최근 세션 요약
3. **Active Sessions** — 현재 실행 중인 에이전트 세션
4. **Active Ports** — 에이전트/dev 서버가 점유 중인 리스닝 포트 현황
5. **Summary** — 전체 통계 요약

**옵션:**

| 옵션 | 기능 |
|------|------|
| `dxai scan` | 전체 보고서 출력 |
| `dxai scan --project <name>` | 특정 프로젝트 상세 보고 |
| `dxai scan --skills` | 스킬 목록만 (글로벌 + 프로젝트별) |
| `dxai scan --mcp` | MCP 서버 목록만 (글로벌 + 프로젝트별) |
| `dxai scan --sessions` | 세션 이력만 |
| `dxai scan --ports` | 리스닝 포트만 |
| `dxai scan --json` | JSON 출력 (스크립트 연동용) |

## Swift 네이티브 앱

### 메뉴바

- 메뉴바 아이콘 + 오늘 토큰 사용량 숫자 표시
- 클릭 시 팝오버 대시보드:
  - Claude/Codex/Gemini 토큰 요약
  - 시스템 상태 (CPU/메모리/디스크) 요약
  - 최근 세션 목록
- CLI의 `dxai ai` 데이터를 공유 (JSON 파일 또는 Unix socket)
- 새로고침 주기: 5분 (설정 가능)

### 알림 (UserNotifications)

- **Pioneer Alert**: CLI의 `dxai ai` 알림과 동일한 칭찬 알림을 macOS 네이티브 알림으로 전달
- 디스크 공간 부족 시 알림
  - 예: "디스크 90% 사용 중. `dxai clean` 실행을 권장합니다"
- 알림 임계치 설정 가능 (`~/.config/dxai/config.toml`)

### 기술 스택

- SwiftUI (macOS 13+)
- Combine (데이터 바인딩)
- UserNotifications framework
- CLI와 데이터 공유: `~/.config/dxai/dxai.db` (SQLite) — CLI와 Swift 앱이 같은 DB를 읽음

## 데이터 레이어

### 로컬 DB (SQLite)

`dxai ai`와 `dxai scan`의 데이터를 로컬 SQLite에 축적하여 시계열 인사이트를 제공한다.

**저장 위치:** `~/.config/dxai/dxai.db`

**수집 데이터:**

```
daily_stats:
  date, tool, model, input_tokens, output_tokens,
  cache_read_tokens, cache_write_tokens, session_count,
  active_projects, skill_count, mcp_count, peak_hour

port_snapshots:
  timestamp, port, process, pid, working_dir
```

**인사이트 대시보드:** `dxai ai insights`

```bash
$ dxai ai insights

dxai Insights (최근 30일)
==========================================

[트렌드]
  일평균 토큰           620K → 890K  (+43%)
  Opus 사용 비율        20% → 45%   (상승 중)
  캐시 히트율           38% → 52%   (개선 중)

[패턴]
  가장 활발한 시간대     14:00-17:00
  가장 활발한 요일       화, 목
  주력 프로젝트          dxai (전체의 34%)

[효율]
  캐시로 절감한 비용     $12.40 (이번 달)
  모델 최적화 제안       "Haiku로 대체 가능한 세션 15건 감지"
==========================================
```

### Opt-in 텔레메트리 (Pioneer Telemetry)

사용자가 **명시적으로 동의한 경우에만**, 가공된 인사이트 숫자를 익명으로 수집한다.

**원칙:**

- 기본값: **꺼짐** (`telemetry = false`)
- 수집 항목은 `dxai telemetry show`로 전송 전 확인 가능
- 원본 데이터(코드, 대화, 프로젝트명, 경로) **절대 포함 안 함**
- 개인정보처리방침 공개 필수

**수집하는 것 (숫자만):**

```
daily_tokens: 520000
tools_used: ["claude", "codex"]
model_mix: { opus: 30%, sonnet: 60%, haiku: 10% }
session_count: 8
active_projects: 3          # 개수만, 이름 없음
peak_hour: 14
skill_count: 12             # 개수만, 이름 없음
mcp_count: 5                # 개수만, 이름 없음
cache_hit_ratio: 0.42
os_version: "macOS 15.1"
dxai_version: "1.2.0"
```

**수집하지 않는 것:**

- 소스코드, 대화 내용, 프롬프트
- 프로젝트명, 파일 경로, 사용자명
- API 키, 시크릿, 환경변수
- IP 주소 (서버에서도 저장 안 함)

**활용:**

| 용도 | 예시 |
|------|------|
| 커뮤니티 벤치마크 | "당신은 상위 12% 파이오니어입니다" |
| 업계 트렌드 리포트 | "AI 코딩 도구 사용자 월평균 15M 토큰 소비" |
| 모델 채택 트렌드 | "Opus 사용 비율 3개월간 20% → 45% 증가" |
| 효율 인사이트 | "캐시 히트율 높은 사용자가 비용 40% 절감" |

**설정:**

```toml
[telemetry]
enabled = false              # 기본 꺼짐, 사용자가 명시적으로 켜야 함
endpoint = "https://telemetry.dxai.dev/v1"
```

**CLI 커맨드:**

| 커맨드 | 기능 |
|--------|------|
| `dxai telemetry on` | 텔레메트리 활성화 (최초 동의 확인) |
| `dxai telemetry off` | 비활성화 |
| `dxai telemetry show` | 다음 전송될 데이터 미리보기 |
| `dxai telemetry status` | 현재 상태 확인 |

## 설정 파일

`~/.config/dxai/config.toml`

```toml
[general]
refresh_interval = 300  # 초 (기본 5분)

[alerts]
pioneer = true                # Pioneer Alert 활성화
pioneer_levels = [50000, 500000, 1000000, 5000000]  # Bronze/Silver/Gold/Diamond
disk_threshold = 0.9          # 디스크 90% 시 알림

[ai.claude]
enabled = true
log_dir = "~/.claude/projects"

[ai.codex]
enabled = true

[ai.gemini]
enabled = true

[scan]
project_dirs = ["~/Desktop/work", "~/projects"]  # 프로젝트 탐색 경로

[telemetry]
enabled = false
```

## 리브랜딩 체크리스트

- [x] CLI 엔트리포인트: `mo` -> `dxai` (mo는 레거시 alias 유지)
- [x] 설정 디렉토리: `~/.config/mole/` -> `~/.config/dxai/`
- [x] 로그 디렉토리: mole 참조 -> dxai
- [x] README.md 전면 재작성
- [x] install.sh 수정
- [x] Makefile 수정
- [x] 내부 문자열/변수명에서 mole/mo 참조 변경 (74개 파일, 600+ 참조)
- [x] Homebrew Tap Formula 준비 (glen15/homebrew-dxai)
- [ ] Homebrew Tap 레포 생성 및 배포 (GitHub에서 수동)

## 구현 순서

### Phase 1: 리브랜딩 + 배포
- `mo` -> `dxai` 전환
- README, install.sh, Makefile 수정
- 빌드/테스트 확인
- Homebrew Tap 배포 (`glen15/homebrew-dxai`)
- GitHub Actions 릴리스 자동화

### Phase 2: `dxai ai` (핵심)
- ai-usage-monitor의 ccu 로직 통합
- Claude/Codex/Gemini 토큰 추적
- 서브커맨드 구현
- Pioneer Alert 알림

### Phase 3: 데이터 레이어
- SQLite 로컬 DB 구축
- 일별 데이터 축적 파이프라인
- `dxai ai insights` 인사이트 대시보드

### Phase 4: `dxai scan`
- 글로벌 설정 스캔 (CLAUDE.md, skills, MCP)
- 프로젝트별 설정/세션 이력 수집
- 활성 세션/포트 감지
- 보고서 포맷 구현

### Phase 5: Opt-in 텔레메트리
- 텔레메트리 서버 구축
- `dxai telemetry` CLI 커맨드
- 커뮤니티 벤치마크 기능
- 개인정보처리방침 작성

### Phase 6: Swift 네이티브 앱
- 메뉴바 앱 기본 구조
- CLI 데이터(SQLite) 연동
- Pioneer Alert 네이티브 알림

## 배포 (Homebrew)

### Stage 1: Homebrew Tap (Phase 1부터)

별도 심사 없이 바로 배포 가능. `glen15/homebrew-dxai` 레포에 formula를 관리한다.

**사용자 설치:**

```bash
brew tap glen15/dxai
brew install dxai
```

**레포 구조:** `glen15/homebrew-dxai`

```
homebrew-dxai/
└── Formula/
    └── dxai.rb
```

**Formula 핵심 내용:**

```ruby
class Dxai < Formula
  desc "Clean, optimize, and manage AI dev environments on your Mac"
  homepage "https://github.com/glen15/dxai"
  url "https://github.com/glen15/dxai/archive/refs/tags/v#{version}.tar.gz"
  license "MIT"

  depends_on :macos
  depends_on "go" => :build    # Go 컴파일용

  def install
    # Shell 스크립트 + Go 바이너리 설치
    # SQLite는 macOS 내장이므로 별도 의존성 불필요
  end
end
```

**릴리스 자동화 (GitHub Actions):**

```
git tag v1.0.0 && git push --tags
  → GitHub Release 자동 생성
  → tarball SHA256 계산
  → homebrew-dxai Formula 자동 업데이트 PR
```

### Stage 2: Homebrew Core (사용자 확보 후)

Tap으로 사용자를 확보한 뒤 공식 Homebrew Core에 등록한다.

**등록 조건:**

- GitHub star 일정 수 이상 (관례적으로 30-75+)
- 안정적 릴리스 이력
- 활성 사용자 존재
- Mole이 이미 Core에 있으므로 fork 구조상 유리

**등록 후:**

```bash
# Tap 없이 바로 설치 가능
brew install dxai
```

## 비기능 요구사항

- **AI 캐시 보호**: `dxai clean` 실행 시 다음 경로는 절대 삭제하지 않음
  - `~/.claude/` (세션 이력, 설정, 프롬프트 캐시)
  - `~/.codex/` (세션 로그, 인증)
  - `~/.terminai/`, `~/.gemini/` (Gemini 세션, 인증)
  - `~/.config/dxai/` (dxai 자체 DB, 설정)
- **안전성**: 모든 삭제 동작은 `--dry-run` 기본, `--apply`로 명시적 실행
- **호환성**: macOS 13 (Ventura) 이상
- **의존성**: CLI는 외부 의존성 최소화 (표준 라이브러리 + Go)
- **데이터 보호**: 원본 데이터(코드, 대화, 경로)는 로컬에만 저장. 텔레메트리는 opt-in 방식으로 가공된 숫자만 익명 전송
