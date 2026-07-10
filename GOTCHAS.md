# GOTCHAS

프로젝트에서 발견된 함정과 근본 원인 기록. fix 커밋 시 반드시 여기에 항목 추가.

### Hermes를 billing provider 기준으로 Codex에 합치면 도구별 통계가 왜곡됨
- **발견**: 2026-07-11
- **증상**: Hermes에서 수행한 작업이 모두 Codex 카드와 그래프에 표시되어 native Codex 사용량과 Hermes 오케스트레이션 사용량을 비교할 수 없음
- **근본 원인**: 최초 Hermes 지원은 누락된 OpenAI Codex 할당량을 복원하는 데 초점을 맞춰 `billing_provider = 'openai-codex'` 세션을 Codex에 합산함. 비용 제공자와 실제 실행 도구를 같은 분류 축으로 취급함
- **방어**:
  - 앱/CLI 통계는 실행 도구 기준으로 분류하고 Hermes DB의 모든 non-zero 세션을 `hermes`로 독립 반환
  - native Codex는 `.codex` 원천만 사용하며 Hermes를 다시 합산하지 않음
  - 로컬과 서버 모두 Claude + Codex + Hermes를 독립 저장하고 합계에서 한 번씩 더함
  - `hermes_tokens` 도입 전 서버 행은 이미 Codex+Hermes가 합산되어 있으므로 재분해하지 않고 Hermes 0으로 유지
  - 기본 Hermes DB와 profile DB는 경로 중복을 제거하고 0-token 세션은 요청 수에서도 제외
  - 앱 번들에는 개발 중 생성된 `__pycache__`/`.pyc`를 복사하지 않아 서명 리소스와 배포물을 결정적으로 유지
- **교훈**: “어디에서 실행했는가”와 “어느 provider의 quota를 썼는가”는 별도 축이다. 제품의 도구별 그래프는 실행 도구를, quota 바는 billing provider를 기준으로 해야 한다

---

### Hermes openai-codex 사용량 누락
- **발견**: 2026-07-08 (V1.0.23 준비)
- **증상**: Hermes에서 `openai-codex` OAuth/provider로 Codex를 사용하면 실제 Codex 할당량은 소모되지만 DXAI의 `codex_tokens`가 0 또는 과소 집계됨. 같은 날 `~/.hermes/state.db`에는 `billing_provider='openai-codex'` 세션 토큰이 존재하지만 `~/.codex/sessions`에는 오늘 `token_count` 이벤트가 없을 수 있음
- **근본 원인**: DXAI 앱/CLI가 Codex 사용량 소스를 `~/.codex/*`에 한정하고 Hermes의 canonical session store(`~/.hermes/state.db`, `~/.hermes/profiles/*/state.db`)를 읽지 않음
- **방어**:
  - 앱 `DxaiDatabase`: Hermes state DB들을 read-only로 스캔하고 `sessions.billing_provider = 'openai-codex'`의 input/output/cache/reasoning tokens를 Codex 집계에 추가
  - CLI `bin/ai.py`: 동일한 Hermes state DB 집계를 `get_codex_token_stats()`에 합산
  - 메시지 내용은 읽지 않고 `sessions`의 숫자 집계 컬럼만 조회하며, 프로필 DB schema/lock 문제는 fail-soft 처리
- **교훈**: “Codex 사용량”은 Codex CLI/App 로그만이 아니라 Codex 인증을 사용하는 상위 에이전트(Hermes 등)의 세션 저장소도 포함해야 한다. 새 agent/provider 경로가 추가될 때는 실제 billing provider와 로컬 저장 위치를 함께 확인할 것
- **후속**: 2026-07-11부터 Hermes는 로컬 앱/CLI와 Vanguard 서버·리더보드에서 독립 도구로 표시한다

---

### Codex archived_sessions 누락으로 토큰 0 표시
- **발견**: 2026-06-11
- **증상**: Codex/Hermes 계열 사용으로 할당량은 소모되지만 DXAI 토큰 사용량이 0 또는 과소 집계될 수 있음
- **근본 원인**: 앱/CLI 파서가 `~/.codex/sessions/**/*.jsonl`만 읽고 `~/.codex/archived_sessions/*.jsonl`을 무시함. Codex가 세션을 아카이브한 뒤에는 로컬 로그가 남아 있어도 집계 대상에서 빠짐
- **방어**:
  - 앱 `DxaiDatabase`: Codex 로그 루트를 `sessions` + `archived_sessions`로 확장
  - CLI `bin/ai.py`: 동일 경로 확장 및 같은 파일명이 양쪽에 있을 때 중복 집계 방지
- **교훈**: 외부 도구 로그 파서는 "현재 세션"과 "아카이브 세션" 경로를 함께 추적해야 한다. 새 Codex 실행 경로가 생기면 실제 파일 위치부터 확인할 것

### Claude 5h quota와 오늘 토큰 숫자 불일치
- **발견**: 2026-06-11
- **증상**: Claude/Fable 5 사용으로 5시간 세션 리밋에 걸렸는데 메뉴바 상단 오늘 토큰은 낮게 보임
- **근본 원인**:
  - 메뉴바 상단은 KST 자정 이후 일일 토큰, Claude quota는 최근 5시간 롤링 윈도우라 자정 직후에는 서로 다른 기간을 보여줌
  - Claude 파서가 `cache_creation_input_tokens`를 total에 포함하지 않아 Fable 5처럼 cache creation이 큰 모델을 과소 집계함
- **방어**:
  - Claude total 계산에 `cache_creation_input_tokens` 포함
  - 도구 카드에 오늘 토큰과 별도로 최근 5시간 세션 토큰을 표시해 quota 소모와 비교 가능하게 함
  - 세션 토큰 표시 조건은 `세션 > 오늘`이 아니라 `세션이 있고 오늘과 다를 때`여야 함. 5시간 구간은 보통 오늘 총량보다 작아서 반대 조건이면 영원히 숨겨짐
  - CLI의 `today` 기준을 앱과 같은 로컬 날짜 기준으로 통일
- **교훈**: "오늘"과 "세션/롤링 quota"는 제품에서 같은 사용량처럼 보이지만 기간 정의가 다르다. 같은 화면에 둘 다 있을 때는 수치 기준을 분리해서 표시해야 한다.

### 메뉴바 패널 열린 상태에서 Claude subagent 토큰 갱신 지연
- **발견**: 2026-06-11
- **증상**: Claude Code/Fable 5를 계속 사용해 `~/.claude/projects/.../subagents/workflows/.../agent-*.jsonl`에는 토큰이 쌓이는데 메뉴바 카드 숫자가 이전 값에 머무름
- **근본 원인**: 메뉴바 UI 타이머가 기본 RunLoop 모드에 등록되어 패널/메뉴 상호작용 중 refresh가 밀릴 수 있음. 사용자가 패널을 열어놓고 관찰하면 CLI 집계와 메뉴바 표시가 어긋남
- **방어**:
  - refresh 타이머를 `.common` RunLoop 모드에 등록
  - 메뉴 패널 `onAppear`에서 강제 refresh
  - refresh 중복 실행 가드로 늦은 작업이 최신 표시를 덮는 상황 방지
- **교훈**: 메뉴바/팝오버 앱의 실시간 지표는 기본 RunLoop 타이머만 믿으면 안 된다. UI가 열린 상태에서 갱신되는지 반드시 직접 확인해야 한다.

### Codex/Hermes token_count JSONL flush 지연
- **발견**: 2026-06-11
- **증상**: Codex/Hermes를 계속 사용해도 DXAI Codex 토큰이 바로 늘지 않음. `~/.codex/sessions/*.jsonl`은 수정되지만 최근 구간에 `token_count` 이벤트가 없을 수 있음
- **근본 원인**: Codex Desktop/Hermes는 현재 스레드 토큰 누적을 `~/.codex/state_5.sqlite`의 `threads.tokens_used`에 먼저 반영하고, JSONL `token_count`는 지연되거나 일부 경로에서 누락될 수 있음
- **방어**:
  - Codex JSONL 집계값과 `state_5.sqlite`에서 오늘 생성된 thread의 `tokens_used` 합계를 비교
  - SQLite 합계가 더 크면 총 토큰을 그 값으로 보정
- **교훈**: Codex 계열 로그는 JSONL만 신뢰하면 안 된다. 진행 중인 Desktop/Hermes 세션은 state DB를 보조 소스로 써야 실시간 표시가 맞는다.

### 자정 경계 — 전일 토큰값이 오늘 row로 복사됨
- **발견**: 2026-04-17
- **증상**: karin의 2026-04-17 daily_record 값이 2026-04-16과 완전히 동일 (1280 coins / 1,052,110,797 claude_tokens). 자정 직후 최초 insert 후 하루 종일 업데이트 없음
- **근본 원인 (가설)**: 자정 직전 시작되어 자정을 넘긴 Claude 요청이 jsonl에 완료 시각(오늘) timestamp로 기록되면서 해당 usage가 오늘 집계로 복사. 혹은 앱 `db.todayStats()` 파싱의 파일 mdate/라인 timestamp 필터가 경계 케이스에서 어긋남
- **방어**:
  - 서버: `submit-daily`에서 새 date INSERT 시 전일 record와 claude/codex tokens가 정확히 같고 0이 아니면 `duplicate_of_previous_day`로 reject
  - 앱: `recordDailyBest`에서 오늘 로컬 row가 없고 전일 row와 tokens가 정확히 같으면 저장·제출 모두 스킵
  - 모니터링: `suspicious_duplicates` VIEW로 사후 오염 row 감시 (`SELECT * FROM suspicious_duplicates;`)
- **교훈**: 자정 기준 "오늘" 계산 로직은 경계 테스트 필수. 로컬 파일 기반 집계는 서버에서 재검증 레이어 필요

### 앱/웹 레벨 곡선 불일치
- **발견**: 2026-03-25
- **증상**: 리더보드 레벨 26, 로컬 메뉴바 레벨 14
- **근본 원인**: 웹에서 경험치 곡선을 `2x → 1.4x`로 수정할 때 앱 Swift 코드(`DxaiViewModel.levelThreshold`)를 함께 수정하지 않음
- **교훈**: 동일 로직이 앱(Swift)과 웹(TypeScript) 양쪽에 있을 때, 한쪽만 수정하면 반드시 불일치 발생. **양쪽 동시 수정 필수**.

### SubmitAPIKey 누락으로 서버 제출 전면 실패
- **발견**: 2026-03-25
- **증상**: 로컬에서 사용량 잡히지만 라이브 리더보드에 미반영
- **근본 원인**: 로컬 빌드 시 `SUBMIT_API_KEY` 환경변수가 Info.plist에 포함되지 않음 → 서버가 401 반환 → 앱은 4xx를 재시도하지 않음 → 데이터 영구 유실
- **교훈**: API key를 빌드 타임에 주입하는 구조는 `.env` 로드가 빌드 스크립트에 반드시 포함되어야 함. 배포 후 실제 제출 성공 로그까지 확인 필수.

### 4xx 에러 silent fail — 데이터 유실
- **발견**: 2026-03-25
- **증상**: 서버 거부(401/400)된 제출이 pending queue에 들어가지 않아 데이터 영구 손실
- **근본 원인**: `sendPayload`에서 4xx 응답을 로그만 남기고 버림. 5xx/네트워크 실패만 재시도 대상
- **교훈**: 인증 실패(401)는 "앱 설정 문제"이지 "잘못된 요청"이 아님. 최소한 401은 pending queue에 넣거나, 실패 카운터를 노출해서 사용자가 인지할 수 있게 해야 함.

### 빌드 버전 1.0.0 하드코딩
- **발견**: 2026-03-25
- **증상**: 로컬 빌드 앱 버전이 항상 1.0.0
- **근본 원인**: `build-app.sh`에서 `DXAI_VERSION` 미설정 시 `1.0.0` 폴백. CI만 태그에서 주입하고 로컬 빌드는 고려 안 함
- **교훈**: 기본값이 있는 변수는 "기본값이 맞는지" 검증해야 함. `git describe --tags`로 자동 감지가 더 안전.

### Homebrew Cask `auto_updates true` 누락 → brew와 Sparkle 불일치
- **발견**: 2026-05-25 (V1.0.22 릴리스 직후)
- **증상**: Sparkle이 1시간 주기로 새 버전 자동 다운로드/설치하는데, `brew outdated --cask`는 dxai를 outdated로 잘못 표시하거나 `brew upgrade --cask dxai`가 이미 최신인 앱을 다시 덮어쓰려 함
- **근본 원인**: `glen15/homebrew-dxai`의 `Casks/dxai.rb`에 `auto_updates true` 플래그 누락. 이 플래그가 없으면 Homebrew는 "앱이 스스로 업데이트한다"는 사실을 모르고 단순 버전 비교만 수행
- **방어**: cask에 `auto_updates true` 추가 (`glen15/homebrew-dxai@e02a00c`)
- **교훈**: Sparkle을 통합한 앱을 Homebrew Cask로 배포할 때는 **반드시** `auto_updates true` 명시. 두 업데이트 경로가 공존할 때 Homebrew 측에 "주 경로는 앱 내부"라고 알려야 충돌이 없음.

### 메뉴바 앱 메인 스레드 블로킹 — DispatchSemaphore + 동기 파일 I/O
- **발견**: 2026-05-25 (V1.0.22 작업)
- **증상**: 앱 시작 직후 최대 5초 UI 프리즈, 15초 주기 refresh마다 잠깐 멈춤
- **근본 원인 1**: `DxaiDatabase.fetchClaudeUsage`가 `DispatchSemaphore.wait()`로 URLSession 콜백을 메인 스레드에서 동기 대기. Anthropic API 응답이 느리면 그대로 메인 블로킹
- **근본 원인 2**: `DxaiViewModel.init() → refresh()` 가 `@MainActor` 동기 체인. 2,122개 jsonl 파일 enumerate + 파싱이 메인에서 수행
- **방어**:
  - `fetchClaudeUsage` → `async/await` (URLSession.data) 으로 전환, semaphore 제거
  - `refresh()` → `refreshAsync()` 로 분리, `Task.detached`로 파일 I/O 백그라운드화
  - `codexQuota`에 5분 인메모리 캐시 추가 (claudeQuota와 통일)
- **교훈**: `@MainActor` 클래스 안에서 `DispatchSemaphore`로 비동기→동기 변환하면 메인 스레드가 그대로 막힘. async API가 있다면 무조건 await으로. UI 응답성은 "데이터 정확성"보다 우선이므로 첫 화면은 캐시/빈 값으로 즉시 표시 후 백그라운드 갱신이 정석.

### Edge Function 배포 후 구버전 캐시
- **발견**: 2026-03 (이전)
- **증상**: Edge Function 코드 수정 후 배포했는데 이전 버전이 실행됨
- **근본 원인**: Supabase Edge Function의 콜드스타트 캐시. 배포 직후 즉시 반영되지 않을 수 있음
- **교훈**: 배포 후 반드시 실제 호출로 동작 확인. 캐시 문제 의심 시 수분 대기 후 재확인.
