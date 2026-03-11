<div align="center">
  <img src="dexai_logo.png" width="128" alt="DXAI Logo">
  <h1>Deus eX AI</h1>
  <p><strong>macOS용 AI 개발 환경 매니저</strong></p>
  <p>토큰 추적, 쿼터 모니터링, 시스템 최적화 — 메뉴바 하나로.</p>
</div>

<p align="center">
  <a href="https://github.com/glen15/dxai/stargazers"><img src="https://img.shields.io/github/stars/glen15/dxai?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/glen15/dxai/releases"><img src="https://img.shields.io/github/v/tag/glen15/dxai?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="README.md"><img src="https://img.shields.io/badge/lang-English-blue?style=flat-square" alt="English"></a>
  <a href="README.ko.md"><img src="https://img.shields.io/badge/lang-한국어-blue?style=flat-square" alt="Korean"></a>
</p>

## 설치

```bash
brew install --cask glen15/dxai/dxai
```

macOS 13 (Ventura) 이상. API 키 불필요.

---

<p align="center">
  <img src="screenshot/kr1.png" width="280" alt="메뉴바 앱 (KR)">
  <img src="screenshot/egn1.png" width="280" alt="메뉴바 앱 (EN)">
</p>

<p align="center">
  <img src="screenshot/vanguard1.png" width="560" alt="Vanguard 리더보드">
</p>

---

## 주요 기능

- **토큰 대시보드** — Claude Code, Codex CLI 사용량 실시간 합산
- **쿼터 모니터링** — 5시간/7일 제한, 리셋 타이머
- **Vanguard 랭크** — 일일 사용량 기반 8등급 36레벨 (Bronze → Challenger)
- **Vanguard 리더보드** — opt-in 랭킹 ([vanguard.dx-ai.cloud](https://vanguard.dx-ai.cloud))
- **토큰 마일스톤** — 누적 달성 시 macOS 알림
- **시스템 관리** — 디스크 정리, 메모리 최적화, AI 환경 스캔
- **EN/KR** — 영어/한국어 완전 지원

---

## 데이터 안전

- 모든 데이터는 로컬 로그 파일(`.jsonl`)을 읽기 전용으로 파싱
- AI 도구 데이터(`~/.claude/`, `~/.codex/`)는 정리 대상에서 제외
- 리더보드 참여는 opt-in. 닉네임 + 토큰 수만 전송 (프롬프트/대화 내용 수집 없음)

---

## 크레딧

[Tw93](https://github.com/tw93)의 [Mole](https://github.com/tw93/Mole) (MIT)에서 영감을 받아, 시스템 관리 기반 위에 AI 토큰 추적과 게이미피케이션을 더했습니다.

## 라이선스

MIT License. [LICENSE](LICENSE) 참조.
