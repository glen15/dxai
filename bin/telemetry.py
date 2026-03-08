#!/usr/bin/env python3
"""
dxai telemetry - Opt-in 익명 텔레메트리 (Pioneer Telemetry)

사용법:
    dxai telemetry on       활성화 (최초 동의 확인)
    dxai telemetry off      비활성화
    dxai telemetry show     다음 전송될 데이터 미리보기
    dxai telemetry status   현재 상태 확인
"""

import json
import os
import platform
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "dxai"
TELEMETRY_CONFIG = CONFIG_DIR / "telemetry.json"
TELEMETRY_ENDPOINT = "https://telemetry.dxai.dev/v1/report"


class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    GRAY = '\033[90m'
    END = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'


# ─── 설정 관리 ───────────────────────────────────────────────

def load_config():
    if TELEMETRY_CONFIG.exists():
        try:
            return json.loads(TELEMETRY_CONFIG.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"enabled": False, "uuid": None, "consented_at": None}


def save_config(config):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    TELEMETRY_CONFIG.write_text(
        json.dumps(config, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def is_enabled():
    return load_config().get("enabled", False)


# ─── 데이터 수집 (숫자만) ────────────────────────────────────

def _get_db_module():
    script_dir = Path(__file__).resolve().parent.parent
    db_path = script_dir / "lib" / "ai" / "db.py"
    if not db_path.exists():
        return None
    import importlib.util
    spec = importlib.util.spec_from_file_location("db", str(db_path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _get_dxai_version():
    script_dir = Path(__file__).resolve().parent.parent
    dxai_script = script_dir / "dxai"
    if dxai_script.exists():
        try:
            for line in dxai_script.read_text(encoding="utf-8").splitlines()[:20]:
                if line.startswith('VERSION='):
                    return line.split('"')[1]
        except Exception:
            pass
    return "unknown"


def collect_telemetry_payload():
    """전송할 데이터 수집 — 숫자와 버전 정보만, 개인 식별 정보 없음"""
    config = load_config()

    payload = {
        "uuid": config.get("uuid"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "dxai_version": _get_dxai_version(),
        "os_version": f"macOS {platform.mac_ver()[0]}",
        "arch": platform.machine(),
    }

    # DB에서 오늘 통계
    db = _get_db_module()
    if db:
        total = db.get_total_by_period(1)
        if total:
            payload["daily_tokens"] = total.get("total_tokens", 0)
            payload["daily_requests"] = total.get("requests", 0)

        breakdown = db.get_tool_breakdown(1)
        if breakdown:
            payload["tools_used"] = [r["tool"] for r in breakdown]

        cache = db.get_cache_efficiency(30)
        if cache:
            payload["cache_hit_ratio"] = cache["cache_hit_rate"] / 100

    # 개수만 (이름/경로 없음)
    claude_home = Path.home() / ".claude"

    skills_dir = claude_home / "skills"
    if skills_dir.exists():
        payload["skill_count"] = sum(1 for p in skills_dir.iterdir() if p.is_dir() or p.suffix == ".md")
    else:
        payload["skill_count"] = 0

    mcp_json = claude_home / "mcp.json"
    if mcp_json.exists():
        try:
            data = json.loads(mcp_json.read_text(encoding="utf-8"))
            payload["mcp_count"] = len(data.get("mcpServers", {}))
        except Exception:
            payload["mcp_count"] = 0
    else:
        payload["mcp_count"] = 0

    # 프로젝트 개수 (이름 없음)
    work_dir = Path.home() / "Desktop" / "work"
    if work_dir.exists():
        ai_sigs = [".claude", ".codex", ".gemini", "CLAUDE.md", "AGENTS.md"]
        count = 0
        for item in work_dir.iterdir():
            if item.is_dir() and any((item / s).exists() for s in ai_sigs):
                count += 1
        payload["active_projects"] = count
    else:
        payload["active_projects"] = 0

    # 활성 세션 개수
    try:
        result = subprocess.run(["ps", "aux"], capture_output=True, text=True, timeout=3)
        session_count = 0
        for line in result.stdout.splitlines():
            cols = line.split(None, 10)
            if len(cols) < 11:
                continue
            cmd = cols[10]
            tty = cols[6]
            if tty.startswith("s") and ("claude" in cmd or "codex" in cmd):
                if "Claude.app" not in cmd and "grep" not in cmd:
                    session_count += 1
        payload["session_count"] = session_count
    except Exception:
        payload["session_count"] = 0

    return payload


def send_telemetry(payload):
    """텔레메트리 전송 — 엔드포인트가 준비되면 활성화"""
    try:
        import urllib.request
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(
            TELEMETRY_ENDPOINT,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except Exception:
        return False


# ─── CLI 커맨드 ──────────────────────────────────────────────

def cmd_on():
    config = load_config()
    if config.get("enabled"):
        print(f"{Colors.GREEN}텔레메트리가 이미 활성화되어 있습니다.{Colors.END}")
        return

    print(f"{Colors.BOLD}dxai Pioneer Telemetry{Colors.END}")
    print()
    print("활성화하면 다음 데이터가 익명으로 수집됩니다:")
    print()
    print(f"  {Colors.GREEN}수집하는 것 (숫자만):{Colors.END}")
    print("    - 일일 토큰 사용량, 요청 수")
    print("    - 사용 도구 이름 (claude, codex, gemini)")
    print("    - 스킬/MCP/프로젝트 개수 (이름 없음)")
    print("    - 캐시 히트율, OS 버전, dxai 버전")
    print()
    print(f"  {Colors.RED}절대 수집하지 않는 것:{Colors.END}")
    print("    - 소스코드, 대화 내용, 프롬프트")
    print("    - 프로젝트명, 파일 경로, 사용자명")
    print("    - API 키, 시크릿, 환경변수")
    print("    - IP 주소 (서버에서도 저장 안 함)")
    print()
    print(f"전송 전 'dxai telemetry show'로 데이터를 확인할 수 있습니다.")
    print(f"언제든 'dxai telemetry off'로 끌 수 있습니다.")
    print()

    try:
        answer = input(f"{Colors.BOLD}동의하시겠습니까? (y/N): {Colors.END}").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        return

    if answer != 'y':
        print(f"\n{Colors.YELLOW}텔레메트리가 활성화되지 않았습니다.{Colors.END}")
        return

    config["enabled"] = True
    config["uuid"] = config.get("uuid") or str(uuid.uuid4())
    config["consented_at"] = datetime.now(timezone.utc).isoformat()
    save_config(config)

    print(f"\n{Colors.GREEN}텔레메트리가 활성화되었습니다.{Colors.END}")
    print(f"UUID: {Colors.GRAY}{config['uuid']}{Colors.END}")


def cmd_off():
    config = load_config()
    config["enabled"] = False
    save_config(config)
    print(f"{Colors.GREEN}텔레메트리가 비활성화되었습니다.{Colors.END}")
    print("수집된 로컬 데이터는 유지됩니다. 삭제하려면 ~/.config/dxai/telemetry.json 을 제거하세요.")


def cmd_show():
    payload = collect_telemetry_payload()
    print(f"\n{Colors.BOLD}다음 전송될 데이터:{Colors.END}\n")
    print(json.dumps(payload, indent=2, ensure_ascii=False))

    config = load_config()
    if not config.get("enabled"):
        print(f"\n{Colors.YELLOW}텔레메트리가 꺼져 있어 전송되지 않습니다.{Colors.END}")
    print()


def cmd_status():
    config = load_config()
    enabled = config.get("enabled", False)

    print(f"\n{Colors.BOLD}Pioneer Telemetry 상태{Colors.END}")
    print()

    if enabled:
        print(f"  상태:    {Colors.GREEN}활성{Colors.END}")
        print(f"  UUID:    {Colors.GRAY}{config.get('uuid', '?')}{Colors.END}")
        consented = config.get("consented_at", "?")
        print(f"  동의일:  {consented[:10] if consented else '?'}")
    else:
        print(f"  상태:    {Colors.RED}비활성{Colors.END}")
        print(f"\n  'dxai telemetry on'으로 활성화할 수 있습니다.")

    print(f"  설정파일: {TELEMETRY_CONFIG}")
    print(f"  엔드포인트: {Colors.GRAY}{TELEMETRY_ENDPOINT}{Colors.END}")
    print()


def main():
    args = sys.argv[1:]
    command = args[0].lower() if args else ''

    if command in ['-h', '--help', 'help', '']:
        if not command:
            cmd_status()
        else:
            print(__doc__)
        return

    if command == 'on':
        cmd_on()
    elif command == 'off':
        cmd_off()
    elif command == 'show':
        cmd_show()
    elif command == 'status':
        cmd_status()
    else:
        print(f"{Colors.RED}잘못된 명령어: {command}{Colors.END}")
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
