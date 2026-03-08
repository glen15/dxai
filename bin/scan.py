#!/usr/bin/env python3
"""
dxai scan - AI 에이전트 환경 보고서

사용법:
    dxai scan                    # 전체 보고서
    dxai scan --project NAME     # 특정 프로젝트 상세
    dxai scan --skills           # 스킬 목록
    dxai scan --mcp              # MCP 서버 목록
    dxai scan --sessions         # 세션 이력
    dxai scan --ports            # 리스닝 포트
    dxai scan --json             # JSON 출력
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


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


# ─── 글로벌 설정 감지 ────────────────────────────────────────

def get_global_setup():
    home = Path.home()
    claude_home = home / ".claude"

    setup = {
        "claude_md": None,
        "skills": [],
        "mcp_servers": [],
        "mcp_details": {},
        "hooks": False,
        "commands": [],
    }

    # CLAUDE.md
    claude_md = claude_home / "CLAUDE.md"
    if claude_md.exists():
        try:
            lines = claude_md.read_text(encoding="utf-8").splitlines()
            setup["claude_md"] = len(lines)
        except Exception:
            setup["claude_md"] = 0

    # Skills
    skills_dir = claude_home / "skills"
    if skills_dir.exists():
        for item in sorted(skills_dir.iterdir()):
            if item.is_dir():
                skill_md = item / "SKILL.md"
                setup["skills"].append({
                    "name": item.name,
                    "has_skill_md": skill_md.exists(),
                })
            elif item.suffix == ".md" and item.name != "README.md":
                setup["skills"].append({
                    "name": item.stem,
                    "has_skill_md": False,
                })

    # MCP servers
    mcp_json = claude_home / "mcp.json"
    if mcp_json.exists():
        try:
            data = json.loads(mcp_json.read_text(encoding="utf-8"))
            servers = data.get("mcpServers", {})
            setup["mcp_servers"] = list(servers.keys())
            setup["mcp_details"] = {
                name: {
                    "command": cfg.get("command", "?"),
                    "type": cfg.get("type", "?"),
                }
                for name, cfg in servers.items()
            }
        except Exception:
            pass

    # Hooks
    hooks_dir = claude_home / "hooks"
    if hooks_dir.exists() and any(hooks_dir.iterdir()):
        setup["hooks"] = True

    # Commands
    commands_dir = claude_home / "commands"
    if commands_dir.exists():
        for item in sorted(commands_dir.iterdir()):
            if item.is_file() and item.suffix == ".md":
                setup["commands"].append(item.stem)
            elif item.is_dir():
                for sub in sorted(item.iterdir()):
                    if sub.suffix == ".md":
                        setup["commands"].append(f"{item.name}/{sub.stem}")

    return setup


# ─── 프로젝트 감지 ───────────────────────────────────────────

AI_SIGNATURES = [
    ".claude",
    ".codex",
    "CLAUDE.md",
    "AGENTS.md",
]


def find_ai_projects(scan_dirs=None):
    home = Path.home()
    if scan_dirs is None:
        scan_dirs = [home / "Desktop" / "work"]

    projects = []
    seen = set()

    for scan_dir in scan_dirs:
        scan_path = Path(scan_dir).expanduser()
        if not scan_path.exists():
            continue

        for item in sorted(scan_path.iterdir()):
            if not item.is_dir() or item.name.startswith("."):
                continue
            if item.resolve() in seen:
                continue
            seen.add(item.resolve())

            signatures = []
            for sig in AI_SIGNATURES:
                if (item / sig).exists():
                    signatures.append(sig)

            if not signatures:
                continue

            projects.append(get_project_info(item, signatures))

    return projects


def _get_git_info(project_dir):
    """프로젝트의 git 정보를 수집한다."""
    info = {
        "git_repo": None,
        "git_branch": None,
        "git_last_commit": None,
        "git_last_time": None,
        "git_dirty": False,
    }
    git_dir = project_dir / ".git"
    if not git_dir.exists():
        return info

    def _git(*args):
        try:
            r = subprocess.run(
                ["git", "-C", str(project_dir)] + list(args),
                capture_output=True, text=True, timeout=3,
            )
            return r.stdout.strip() if r.returncode == 0 else None
        except Exception:
            return None

    # remote origin → owner/repo
    remote = _git("remote", "get-url", "origin")
    if remote:
        # SSH: git@github.com:owner/repo.git
        m = re.search(r'[:/]([^/]+/[^/]+?)(?:\.git)?$', remote)
        if m:
            info["git_repo"] = m.group(1)

    # current branch
    info["git_branch"] = _git("branch", "--show-current") or None

    # last commit message + relative time
    log = _git("log", "-1", "--format=%s\t%ar")
    if log and "\t" in log:
        msg, ago = log.rsplit("\t", 1)
        info["git_last_commit"] = msg[:80]
        info["git_last_time"] = ago

    # dirty (uncommitted changes)
    status = _git("status", "--porcelain", "--untracked-files=no")
    if status:
        info["git_dirty"] = True

    return info


def get_project_info(project_dir, signatures):
    info = {
        "name": project_dir.name,
        "path": str(project_dir),
        "signatures": signatures,
        "claude_md": None,
        "agents_md": None,
        "skills": [],
        "mcp_servers": [],
        "has_local_mcp": False,
        "sessions": [],
        "session_count": 0,
        "last_session": None,
    }

    # Git info
    info.update(_get_git_info(project_dir))

    # CLAUDE.md
    claude_md = project_dir / "CLAUDE.md"
    if claude_md.exists():
        try:
            lines = claude_md.read_text(encoding="utf-8").splitlines()
            info["claude_md"] = len(lines)
        except Exception:
            info["claude_md"] = 0

    # AGENTS.md
    agents_md = project_dir / "AGENTS.md"
    if agents_md.exists():
        try:
            lines = agents_md.read_text(encoding="utf-8").splitlines()
            info["agents_md"] = len(lines)
        except Exception:
            info["agents_md"] = 0

    # Project-level skills
    skills_dir = project_dir / ".claude" / "skills"
    if skills_dir.exists():
        for item in sorted(skills_dir.iterdir()):
            if item.is_dir():
                info["skills"].append(item.name)
            elif item.suffix == ".md":
                info["skills"].append(item.stem)

    # Project-level MCP
    for mcp_file in [project_dir / ".claude" / "mcp.json", project_dir / "mcp.json"]:
        if mcp_file.exists():
            try:
                data = json.loads(mcp_file.read_text(encoding="utf-8"))
                servers = data.get("mcpServers", {})
                info["mcp_servers"] = list(servers.keys())
                info["has_local_mcp"] = True
            except Exception:
                pass
            break

    # Sessions from ~/.claude/projects/
    project_sessions_dir = _get_sessions_dir(project_dir)
    if project_sessions_dir and project_sessions_dir.exists():
        jsonl_files = sorted(
            project_sessions_dir.glob("*.jsonl"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        info["session_count"] = len(jsonl_files)

        if jsonl_files:
            latest = jsonl_files[0]
            info["last_session"] = {
                "time": datetime.fromtimestamp(
                    latest.stat().st_mtime, tz=timezone.utc
                ).isoformat(),
                "topic": _extract_session_topic(latest),
            }

            # Recent sessions (last 5)
            for f in jsonl_files[:5]:
                mtime = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
                info["sessions"].append({
                    "id": f.stem,
                    "time": mtime.isoformat(),
                    "topic": _extract_session_topic(f),
                })

    return info


def _get_sessions_dir(project_dir):
    encoded = str(project_dir).replace("/", "-")
    sessions_dir = Path.home() / ".claude" / "projects" / encoded
    if sessions_dir.exists():
        return sessions_dir
    return None


def _extract_session_topic(jsonl_path):
    try:
        with open(jsonl_path, 'r', encoding='utf-8') as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if entry.get("type") != "user":
                    continue

                msg = entry.get("message", "")
                text = _extract_text_from_message(msg)
                if text and len(text) > 3:
                    return text[:80]
    except Exception:
        pass
    return None


def _extract_text_from_message(msg):
    if isinstance(msg, str):
        return msg.strip()
    if isinstance(msg, dict):
        content = msg.get("content", "")
        if isinstance(content, str):
            return content.strip()
        if isinstance(content, list):
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text":
                    text = item.get("text", "").strip()
                    if text:
                        return text
    return None


# ─── 활성 세션 감지 ──────────────────────────────────────────

def get_active_sessions():
    sessions = []
    try:
        result = subprocess.run(
            ["ps", "aux"],
            capture_output=True, text=True, timeout=5,
        )
        for line in result.stdout.splitlines():
            cols = line.split(None, 10)
            if len(cols) < 11:
                continue

            cmd = cols[10]
            pid = cols[1]

            # Claude Code CLI (only direct CLI invocations, not spawned children)
            if re.search(r'\bclaude\b', cmd) and 'grep' not in cmd:
                # Skip non-CLI processes
                if any(skip in cmd for skip in [
                    'Claude.app', 'chrome-native', 'shell-snapshots',
                    'bash /Users', 'adapters/',
                ]):
                    continue
                # Only match direct claude CLI process (tty-attached)
                tty = cols[6] if len(cols) > 6 else ""
                if tty == "??" or not tty.startswith("s"):
                    continue

                cwd = _get_process_cwd(pid)
                sessions.append({
                    "tool": "claude",
                    "pid": int(pid),
                    "cwd": cwd,
                    "cmd": cmd[:120],
                })

            # Codex CLI (only direct CLI invocations)
            elif re.search(r'\bcodex\b', cmd) and 'grep' not in cmd:
                tty = cols[6] if len(cols) > 6 else ""
                if tty == "??" or not tty.startswith("s"):
                    continue
                cwd = _get_process_cwd(pid)
                sessions.append({
                    "tool": "codex",
                    "pid": int(pid),
                    "cwd": cwd,
                    "cmd": cmd[:120],
                })

    except Exception:
        pass

    return sessions


def _get_process_cwd(pid):
    try:
        result = subprocess.run(
            ["lsof", "-p", str(pid), "-Fn"],
            capture_output=True, text=True, timeout=3,
        )
        for line in result.stdout.splitlines():
            if line.startswith("n") and line.startswith("n/"):
                path = line[1:]
                if os.path.isdir(path) and "/Users/" in path:
                    return path
    except Exception:
        pass
    return None


# ─── 포트 감지 ───────────────────────────────────────────────

SYSTEM_PORTS = {
    "rapportd", "veraport", "delfino", "ControlCe",
    "LogiPlugi", "logioptio", "mDNSResp",
}


def get_listening_ports():
    ports = []
    try:
        result = subprocess.run(
            ["lsof", "-nP", "-iTCP", "-sTCP:LISTEN"],
            capture_output=True, text=True, timeout=5,
        )
        for line in result.stdout.splitlines()[1:]:
            cols = line.split()
            if len(cols) < 9:
                continue

            command = cols[0]
            pid = cols[1]

            if command in SYSTEM_PORTS:
                continue

            name_col = cols[8]
            port_match = re.search(r':(\d+)$', name_col)
            if not port_match:
                continue

            port = int(port_match.group(1))

            # Skip ephemeral/system ports
            if port > 49152:
                continue

            cwd = _get_process_cwd(pid)

            ports.append({
                "port": port,
                "command": command,
                "pid": int(pid),
                "cwd": cwd,
            })

    except Exception:
        pass

    # Deduplicate by port
    seen = set()
    unique = []
    for p in ports:
        if p["port"] not in seen:
            seen.add(p["port"])
            unique.append(p)

    return sorted(unique, key=lambda x: x["port"])


# ─── 표시 함수 ───────────────────────────────────────────────

def _relative_time(iso_str):
    try:
        dt = datetime.fromisoformat(iso_str)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        diff = now - dt
        seconds = int(diff.total_seconds())
        if seconds < 60:
            return "방금"
        if seconds < 3600:
            return f"{seconds // 60}분 전"
        if seconds < 86400:
            return f"{seconds // 3600}시간 전"
        days = seconds // 86400
        if days == 1:
            return "어제"
        if days < 7:
            return f"{days}일 전"
        if days < 30:
            return f"{days // 7}주 전"
        return f"{days // 30}개월 전"
    except Exception:
        return "?"


def _short_path(path):
    if not path:
        return "?"
    home = str(Path.home())
    if path.startswith(home):
        return "~" + path[len(home):]
    return path


def display_full_report():
    setup = get_global_setup()
    projects = find_ai_projects()
    active = get_active_sessions()
    ports = get_listening_ports()

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}  dxai Agent Report{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")

    # Global Setup
    print(f"\n{Colors.BOLD}{Colors.BLUE}[Global Setup]{Colors.END}")

    claude_md = setup["claude_md"]
    if claude_md:
        print(f"  CLAUDE.md            {Colors.GREEN}Yes{Colors.END}  ({claude_md} lines)")
    else:
        print(f"  CLAUDE.md            {Colors.RED}No{Colors.END}")

    skills = setup["skills"]
    if skills:
        names = ", ".join(s["name"] for s in skills[:6])
        extra = f", +{len(skills)-6}" if len(skills) > 6 else ""
        print(f"  Skills               {Colors.GREEN}{len(skills)}{Colors.END} ({names}{extra})")
    else:
        print(f"  Skills               {Colors.GRAY}0{Colors.END}")

    mcp = setup["mcp_servers"]
    if mcp:
        names = ", ".join(mcp[:6])
        extra = f", +{len(mcp)-6}" if len(mcp) > 6 else ""
        print(f"  MCP Servers          {Colors.GREEN}{len(mcp)}{Colors.END} ({names}{extra})")
    else:
        print(f"  MCP Servers          {Colors.GRAY}0{Colors.END}")

    if setup["hooks"]:
        print(f"  Hooks                {Colors.GREEN}Yes{Colors.END}")

    if setup["commands"]:
        print(f"  Commands             {Colors.GREEN}{len(setup['commands'])}{Colors.END}")

    # Projects
    print(f"\n{Colors.BOLD}{Colors.BLUE}[Projects]{Colors.END}  ({len(projects)} detected)")

    for proj in projects:
        sigs = " ".join(f"{Colors.GRAY}{s}{Colors.END}" for s in proj["signatures"])
        print(f"\n  {Colors.BOLD}{proj['name']}/{Colors.END}  {sigs}")

        if proj["claude_md"]:
            print(f"    CLAUDE.md          {Colors.GREEN}Yes{Colors.END} ({proj['claude_md']} lines)")
        if proj["agents_md"]:
            print(f"    AGENTS.md          {Colors.GREEN}Yes{Colors.END} ({proj['agents_md']} lines)")

        if proj["skills"]:
            print(f"    Skills             {', '.join(proj['skills'])}")

        if proj["has_local_mcp"]:
            print(f"    MCP                {', '.join(proj['mcp_servers'])}")
        else:
            print(f"    MCP                {Colors.GRAY}global inherited{Colors.END}")

        if proj["last_session"]:
            ago = _relative_time(proj["last_session"]["time"])
            topic = proj["last_session"]["topic"] or ""
            if topic:
                topic = f' — "{topic[:50]}"'
            print(f"    Last session       {ago}{topic}")
            print(f"    Total sessions     {proj['session_count']}")

    # Active Sessions
    print(f"\n{Colors.BOLD}{Colors.BLUE}[Active Sessions]{Colors.END}  ({len(active)})")
    if active:
        for s in active:
            cwd_display = _short_path(s["cwd"]) if s["cwd"] else ""
            print(f"  {s['tool']:8} PID {s['pid']:6}  {cwd_display}")
    else:
        print(f"  {Colors.GRAY}없음{Colors.END}")

    # Ports
    print(f"\n{Colors.BOLD}{Colors.BLUE}[Active Ports]{Colors.END}  ({len(ports)})")
    if ports:
        for p in ports:
            cwd_display = _short_path(p["cwd"]) if p["cwd"] else ""
            print(f"  :{p['port']:<6} {p['command']:14} PID {p['pid']:6}  {cwd_display}")
    else:
        print(f"  {Colors.GRAY}없음{Colors.END}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_skills():
    setup = get_global_setup()
    projects = find_ai_projects()

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}  Skills Inventory{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")

    print(f"\n{Colors.BOLD}[Global]{Colors.END}")
    if setup["skills"]:
        for s in setup["skills"]:
            marker = f"{Colors.GREEN}SKILL.md{Colors.END}" if s["has_skill_md"] else f"{Colors.GRAY}.md{Colors.END}"
            print(f"  {s['name']:30} {marker}")
    else:
        print(f"  {Colors.GRAY}없음{Colors.END}")

    for proj in projects:
        if proj["skills"]:
            print(f"\n{Colors.BOLD}[{proj['name']}]{Colors.END}")
            for name in proj["skills"]:
                print(f"  {name}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_mcp():
    setup = get_global_setup()
    projects = find_ai_projects()

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}  MCP Servers{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")

    print(f"\n{Colors.BOLD}[Global]{Colors.END}")
    if setup["mcp_servers"]:
        for name in setup["mcp_servers"]:
            detail = setup["mcp_details"].get(name, {})
            cmd = detail.get("command", "?")
            print(f"  {name:25} {Colors.GRAY}{cmd}{Colors.END}")
    else:
        print(f"  {Colors.GRAY}없음{Colors.END}")

    for proj in projects:
        if proj["has_local_mcp"]:
            print(f"\n{Colors.BOLD}[{proj['name']}]{Colors.END}")
            for name in proj["mcp_servers"]:
                print(f"  {name}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_sessions():
    projects = find_ai_projects()

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}  Session History{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")

    for proj in projects:
        if not proj["sessions"]:
            continue
        print(f"\n{Colors.BOLD}{proj['name']}/{Colors.END}  (총 {proj['session_count']}개)")
        for s in proj["sessions"]:
            ago = _relative_time(s["time"])
            topic = s["topic"] or ""
            if topic:
                topic = f' — "{topic[:60]}"'
            print(f"  {ago:12}{topic}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_ports():
    ports = get_listening_ports()

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}  Active Ports{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")

    if ports:
        for p in ports:
            cwd_display = _short_path(p["cwd"]) if p["cwd"] else ""
            print(f"\n  :{p['port']:<6} {p['command']}")
            print(f"    PID {p['pid']}  {cwd_display}")
    else:
        print(f"\n  {Colors.GRAY}리스닝 포트 없음{Colors.END}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_project_detail(name):
    projects = find_ai_projects()
    found = None
    for p in projects:
        if p["name"].lower() == name.lower():
            found = p
            break

    if not found:
        print(f"{Colors.RED}프로젝트 '{name}'을(를) 찾을 수 없습니다.{Colors.END}")
        print(f"\n감지된 프로젝트:")
        for p in projects:
            print(f"  {p['name']}")
        return

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}  {found['name']} — 프로젝트 상세{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")

    print(f"\n  경로: {found['path']}")
    print(f"  감지: {', '.join(found['signatures'])}")

    if found["claude_md"]:
        print(f"\n  {Colors.BOLD}CLAUDE.md{Colors.END}: {found['claude_md']} lines")
    if found["agents_md"]:
        print(f"  {Colors.BOLD}AGENTS.md{Colors.END}: {found['agents_md']} lines")

    if found["skills"]:
        print(f"\n  {Colors.BOLD}Skills:{Colors.END}")
        for s in found["skills"]:
            print(f"    {s}")

    if found["has_local_mcp"]:
        print(f"\n  {Colors.BOLD}MCP Servers:{Colors.END}")
        for s in found["mcp_servers"]:
            print(f"    {s}")
    else:
        print(f"\n  {Colors.BOLD}MCP:{Colors.END} {Colors.GRAY}global inherited{Colors.END}")

    if found["sessions"]:
        print(f"\n  {Colors.BOLD}Recent Sessions:{Colors.END} ({found['session_count']}개)")
        for s in found["sessions"]:
            ago = _relative_time(s["time"])
            topic = s["topic"] or ""
            if topic:
                topic = f' — "{topic[:60]}"'
            print(f"    {ago:12}{topic}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_json():
    setup = get_global_setup()
    projects = find_ai_projects()
    active = get_active_sessions()
    ports = get_listening_ports()

    data = {
        "global": setup,
        "projects": projects,
        "active_sessions": active,
        "ports": ports,
    }
    print(json.dumps(data, indent=2, ensure_ascii=False))


# ─── 메인 ────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]

    if not args:
        display_full_report()
        return

    if args[0] in ['-h', '--help', 'help']:
        print(__doc__)
        return

    if args[0] == '--json':
        display_json()
        return

    if args[0] == '--skills':
        display_skills()
        return

    if args[0] == '--mcp':
        display_mcp()
        return

    if args[0] == '--sessions':
        display_sessions()
        return

    if args[0] == '--ports':
        display_ports()
        return

    if args[0] == '--project' and len(args) > 1:
        display_project_detail(args[1])
        return

    print(f"{Colors.RED}잘못된 옵션: {args[0]}{Colors.END}")
    print(__doc__)
    sys.exit(1)


if __name__ == '__main__':
    main()
