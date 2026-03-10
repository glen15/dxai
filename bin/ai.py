#!/usr/bin/env python3
"""
dxai ai - AI 서비스 통합 사용량 대시보드

사용법:
    dxai ai              # 전체 요약 (Claude + Codex)
    dxai ai claude       # Claude 상세
    dxai ai codex        # Codex 상세
    dxai ai tokens       # 전체 토큰 요약 (Claude + Codex)
    dxai ai today        # Claude 오늘 토큰 사용량
    dxai ai week         # Claude 최근 7일
    dxai ai month        # Claude 최근 30일
    dxai ai watch        # 실시간 모니터링 (전체)
    dxai ai json         # JSON 출력
"""

import json
import base64
import subprocess
import time
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
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


# ─── Vanguard Alert ────────────────────────────────────────────

VANGUARD_LEVELS = [
    (5_000_000, "Diamond", Colors.CYAN,
     "전설의 5M... 당신이 곧 AI 시대입니다"),
    (1_000_000, "Gold", Colors.YELLOW,
     "1M 토큰! 오늘 정말 열심히 했네요"),
    (500_000, "Silver", Colors.BOLD,
     "당신은 AI 시대의 뱅가드입니다"),
    (50_000, "Bronze", Colors.GREEN,
     "AI와 함께하는 하루를 시작했군요!"),
]


def get_vanguard_alert(total_today_tokens):
    for threshold, level, color, message in VANGUARD_LEVELS:
        if total_today_tokens >= threshold:
            return level, color, message
    return None, None, None


def show_vanguard_alert(total_today_tokens):
    level, color, message = get_vanguard_alert(total_today_tokens)
    if level:
        badge = f"{color}[Vanguard {level}]{Colors.END}"
        print(f"\n  {badge} {color}{message}{Colors.END}")


# ─── 공통 유틸리티 ───────────────────────────────────────────

def format_number(num):
    if num >= 1_000_000:
        return f"{num / 1_000_000:.1f}M"
    if num >= 1_000:
        return f"{num / 1_000:.1f}K"
    return str(num)


def format_seconds_remaining(seconds):
    if seconds is None or seconds <= 0:
        return "곧 리셋"
    days = seconds // 86400
    hours = (seconds % 86400) // 3600
    minutes = (seconds % 3600) // 60
    if days > 0:
        return f"{days}d {hours}h"
    if hours > 0:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def format_time_remaining(reset_iso):
    if not reset_iso:
        return "?"
    try:
        reset_time = datetime.fromisoformat(reset_iso.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        total_seconds = int((reset_time - now).total_seconds())
        return format_seconds_remaining(total_seconds)
    except Exception:
        return "?"


def make_bar(percentage, width=30, color=Colors.CYAN):
    percentage = max(0, min(100, percentage))
    filled = int(width * percentage / 100)
    bar = '\u2588' * filled + '\u2591' * (width - filled)
    return f"{color}{bar}{Colors.END}"


def usage_color(percentage):
    if percentage >= 80:
        return Colors.RED
    if percentage >= 50:
        return Colors.YELLOW
    return Colors.GREEN


def clear_screen():
    os.system('clear' if os.name != 'nt' else 'cls')


def print_header(title):
    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}{title}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")


def print_separator():
    print(f"{Colors.DIM}{'-' * 60}{Colors.END}")


def parse_iso_utc(value):
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def get_period_start(period):
    now_utc = datetime.now(timezone.utc)
    today = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)
    if period == 'today':
        return today
    if period == 'week':
        return today - timedelta(days=7)
    if period == 'month':
        return today - timedelta(days=30)
    return datetime.min.replace(tzinfo=timezone.utc)


def empty_token_stats(extra_keys=None):
    stats = {
        'input_tokens': 0,
        'output_tokens': 0,
        'cache_read_tokens': 0,
        'cache_creation_tokens': 0,
        'total_tokens': 0,
        'requests': 0,
    }
    if extra_keys:
        for key in extra_keys:
            stats[key] = 0
    return stats


# ─── Claude 데이터 수집 ──────────────────────────────────────

def find_claude_dir():
    home = Path.home()
    for path in [home / ".claude", home / "Library" / "Application Support" / "Claude"]:
        if path.exists() and (path / "projects").exists():
            return path
    return None


def get_claude_quota():
    cache_path = Path.home() / ".claude" / "plugins" / "claude-hud" / ".usage-cache.json"

    if cache_path.exists():
        try:
            raw = json.loads(cache_path.read_text(encoding="utf-8"))
            ts = raw.get("timestamp", 0) / 1000
            if time.time() - ts <= 600:
                data = raw.get("data", {})
                return {
                    "plan": data.get("planName", "?"),
                    "five_hour": data.get("fiveHour", 0),
                    "seven_day": data.get("sevenDay", 0),
                    "five_hour_reset": data.get("fiveHourResetAt"),
                    "seven_day_reset": data.get("sevenDayResetAt"),
                }
        except Exception:
            pass

    token = _get_claude_token()
    if token:
        try:
            req = urllib.request.Request(
                "https://api.anthropic.com/api/oauth/usage",
                headers={
                    "Authorization": f"Bearer {token}",
                    "anthropic-beta": "oauth-2025-04-20",
                },
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            five_hour = data.get("five_hour", {})
            seven_day = data.get("seven_day", {})
            return {
                "plan": data.get("plan_name", "?"),
                "five_hour": five_hour.get("utilization", 0),
                "seven_day": seven_day.get("utilization", 0),
                "five_hour_reset": five_hour.get("resets_at"),
                "seven_day_reset": seven_day.get("resets_at"),
            }
        except Exception:
            pass
    return None


def _get_claude_token():
    cred_path = Path.home() / ".claude" / ".credentials.json"
    if cred_path.exists():
        try:
            cred = json.loads(cred_path.read_text(encoding="utf-8"))
            token = cred.get("claudeAiOauth", {}).get("accessToken")
            if token:
                return token
        except Exception:
            pass
    try:
        result = subprocess.run(
            ["/usr/bin/security", "find-generic-password",
             "-s", "Claude Code-credentials", "-g"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            import re
            m = re.search(r'^password: "(.*)"$', result.stderr, re.MULTILINE | re.DOTALL)
            if m:
                cred = json.loads(m.group(1))
                token = cred.get("claudeAiOauth", {}).get("accessToken")
                if token:
                    return token
    except Exception:
        pass
    return None


def get_claude_token_stats(period='today'):
    claude_dir = find_claude_dir()
    if not claude_dir:
        return None

    projects_dir = claude_dir / "projects"
    jsonl_files = list(projects_dir.glob("**/*.jsonl"))

    if not jsonl_files:
        return empty_token_stats()

    start_time = get_period_start(period)
    stats = empty_token_stats()

    for filepath in jsonl_files:
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                for line in f:
                    if not line.strip():
                        continue
                    try:
                        entry = json.loads(line)
                        if entry.get('type') != 'assistant' or 'message' not in entry:
                            continue
                        message = entry['message']
                        if 'usage' not in message:
                            continue
                        dt = parse_iso_utc(entry.get('timestamp', ''))
                        if not dt or dt < start_time:
                            continue
                        usage = message['usage']
                        stats['input_tokens'] += usage.get('input_tokens', 0)
                        stats['output_tokens'] += usage.get('output_tokens', 0)
                        stats['cache_read_tokens'] += usage.get('cache_read_input_tokens', 0)
                        stats['cache_creation_tokens'] += usage.get('cache_creation_input_tokens', 0)
                        stats['total_tokens'] += (
                            usage.get('input_tokens', 0)
                            + usage.get('output_tokens', 0)
                            + usage.get('cache_read_input_tokens', 0)
                        )
                        stats['requests'] += 1
                    except (json.JSONDecodeError, ValueError):
                        continue
        except Exception:
            continue

    return stats


# ─── Codex 데이터 수집 ───────────────────────────────────────

def get_codex_usage():
    auth_path = Path.home() / ".codex" / "auth.json"
    tokens = {}
    auth_meta = {
        "plan": "?",
        "email": None,
        "subscription_start": None,
        "subscription_until": None,
    }
    if auth_path.exists():
        try:
            auth = json.loads(auth_path.read_text(encoding="utf-8"))
            tokens = auth.get("tokens", {})
            auth_meta = _get_codex_auth_metadata(tokens)
        except Exception:
            tokens = {}

    access_token = tokens.get("access_token")
    if access_token:
        try:
            req = urllib.request.Request(
                "https://chatgpt.com/backend-api/wham/usage",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "User-Agent": "dxai",
                    "Accept": "application/json",
                },
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            rate = data.get("rate_limit", {})
            primary = rate.get("primary_window", {})
            secondary = rate.get("secondary_window", {})
            credits = data.get("credits", {})

            return {
                "plan": data.get("plan_type") or auth_meta.get("plan", "?"),
                "email": data.get("email") or auth_meta.get("email"),
                "five_hour": primary.get("used_percent", 0),
                "five_hour_reset_seconds": primary.get("reset_after_seconds"),
                "seven_day": secondary.get("used_percent", 0) if secondary else 0,
                "seven_day_reset_seconds": secondary.get("reset_after_seconds") if secondary else None,
                "credits_balance": credits.get("balance", "0"),
                "credits_unlimited": credits.get("unlimited", False),
                "subscription_start": auth_meta.get("subscription_start"),
                "subscription_until": auth_meta.get("subscription_until"),
                "source": "oauth_feed",
            }
        except Exception:
            pass

    return _get_codex_usage_from_local_sessions(auth_meta)


def _get_codex_auth_metadata(tokens):
    meta = {
        "plan": "?",
        "email": None,
        "subscription_start": None,
        "subscription_until": None,
    }
    payload = _decode_jwt_payload(tokens.get("id_token", ""))
    if not payload:
        return meta

    meta["email"] = payload.get("email")
    auth_info = payload.get("https://api.openai.com/auth", {})
    plan = auth_info.get("chatgpt_plan_type")
    if plan:
        meta["plan"] = plan
    meta["subscription_start"] = _format_date(auth_info.get("chatgpt_subscription_active_start"))
    meta["subscription_until"] = _format_date(auth_info.get("chatgpt_subscription_active_until"))
    return meta


def _seconds_until(epoch_seconds):
    if epoch_seconds is None:
        return None
    try:
        return max(0, int(epoch_seconds) - int(time.time()))
    except Exception:
        return None


def _get_codex_usage_from_local_sessions(auth_meta=None):
    sessions_dir = Path.home() / ".codex" / "sessions"
    if not sessions_dir.exists():
        return None

    jsonl_files = sorted(
        sessions_dir.glob("**/*.jsonl"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not jsonl_files:
        return None

    auth_meta = auth_meta or {}
    for filepath in jsonl_files:
        try:
            lines = filepath.read_text(encoding="utf-8").splitlines()
        except Exception:
            continue

        for line in reversed(lines):
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            if entry.get("type") != "event_msg":
                continue
            payload = entry.get("payload") or {}
            if payload.get("type") != "token_count":
                continue

            rate = payload.get("rate_limits") or {}
            if rate.get("limit_id") != "codex":
                continue

            primary = rate.get("primary") or {}
            secondary = rate.get("secondary") or {}
            credits = rate.get("credits") or {}
            balance = credits.get("balance")

            return {
                "plan": rate.get("plan_type") or auth_meta.get("plan", "?"),
                "email": auth_meta.get("email"),
                "five_hour": primary.get("used_percent", 0),
                "five_hour_reset_seconds": _seconds_until(primary.get("resets_at")),
                "seven_day": secondary.get("used_percent", 0) if secondary else 0,
                "seven_day_reset_seconds": _seconds_until(secondary.get("resets_at")) if secondary else None,
                "credits_balance": "0" if balance is None else str(balance),
                "credits_unlimited": bool(credits.get("unlimited", False)),
                "subscription_start": auth_meta.get("subscription_start"),
                "subscription_until": auth_meta.get("subscription_until"),
                "source": "session_rate_limits",
            }

    return None


def _decode_jwt_payload(token):
    try:
        parts = token.split(".")
        if len(parts) < 2:
            return None
        payload_b64 = parts[1]
        padding = 4 - len(payload_b64) % 4
        if padding != 4:
            payload_b64 += "=" * padding
        return json.loads(base64.urlsafe_b64decode(payload_b64))
    except Exception:
        return None


def _format_date(iso_str):
    if not iso_str:
        return None
    return iso_str[:10]


def get_codex_token_stats(period='today'):
    sessions_dir = Path.home() / ".codex" / "sessions"
    if not sessions_dir.exists():
        return None

    jsonl_files = list(sessions_dir.glob("**/*.jsonl"))
    if not jsonl_files:
        return empty_token_stats(extra_keys=['reasoning_output_tokens'])

    start_time = get_period_start(period)
    stats = empty_token_stats(extra_keys=['reasoning_output_tokens'])

    for filepath in jsonl_files:
        prev_totals = None
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                for line in f:
                    if not line.strip():
                        continue
                    try:
                        entry = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    if entry.get("type") != "event_msg":
                        continue
                    payload = entry.get("payload", {})
                    if payload.get("type") != "token_count":
                        continue

                    info = payload.get("info") or {}
                    total_usage = info.get("total_token_usage", {})
                    if not total_usage:
                        continue

                    current_totals = {
                        "input_tokens": int(total_usage.get("input_tokens", 0) or 0),
                        "cache_read_tokens": int(total_usage.get("cached_input_tokens", 0) or 0),
                        "output_tokens": int(total_usage.get("output_tokens", 0) or 0),
                        "reasoning_output_tokens": int(total_usage.get("reasoning_output_tokens", 0) or 0),
                        "total_tokens": int(total_usage.get("total_tokens", 0) or 0),
                    }

                    last_usage = info.get("last_token_usage", {})
                    if prev_totals is None:
                        delta = {
                            "input_tokens": int(last_usage.get("input_tokens", 0) or 0),
                            "cache_read_tokens": int(last_usage.get("cached_input_tokens", 0) or 0),
                            "output_tokens": int(last_usage.get("output_tokens", 0) or 0),
                            "reasoning_output_tokens": int(last_usage.get("reasoning_output_tokens", 0) or 0),
                            "total_tokens": int(last_usage.get("total_tokens", 0) or 0),
                        }
                    else:
                        delta = {
                            "input_tokens": max(0, current_totals["input_tokens"] - prev_totals["input_tokens"]),
                            "cache_read_tokens": max(0, current_totals["cache_read_tokens"] - prev_totals["cache_read_tokens"]),
                            "output_tokens": max(0, current_totals["output_tokens"] - prev_totals["output_tokens"]),
                            "reasoning_output_tokens": max(0, current_totals["reasoning_output_tokens"] - prev_totals["reasoning_output_tokens"]),
                            "total_tokens": max(0, current_totals["total_tokens"] - prev_totals["total_tokens"]),
                        }

                    prev_totals = current_totals

                    if delta["total_tokens"] <= 0:
                        continue

                    dt = parse_iso_utc(entry.get("timestamp"))
                    if not dt or dt < start_time:
                        continue

                    stats["input_tokens"] += delta["input_tokens"]
                    stats["cache_read_tokens"] += delta["cache_read_tokens"]
                    stats["output_tokens"] += delta["output_tokens"]
                    stats["reasoning_output_tokens"] += delta["reasoning_output_tokens"]
                    stats["total_tokens"] += delta["total_tokens"]
                    stats["requests"] += 1
        except Exception:
            continue

    return stats


# ─── 표시 함수 ───────────────────────────────────────────────

def _get_total_today_tokens():
    claude = get_claude_token_stats('today') or empty_token_stats()
    codex = get_codex_token_stats('today') or empty_token_stats()
    return claude['total_tokens'] + codex['total_tokens']


def display_summary():
    print_header("  dxai - AI 서비스 사용량 요약")

    # Claude
    quota = get_claude_quota()
    print(f"\n{Colors.BOLD} Claude{Colors.END}", end="")
    if quota:
        plan = quota["plan"]
        five = quota.get("five_hour")
        seven = quota.get("seven_day")
        print(f" {Colors.GRAY}({plan}){Colors.END}")

        if five is not None and seven is not None:
            five_c = usage_color(five)
            seven_c = usage_color(seven)
            five_reset = format_time_remaining(quota.get("five_hour_reset"))
            seven_reset = format_time_remaining(quota.get("seven_day_reset"))
            print(f"  세션 (5h)  {make_bar(five, 25, five_c)} {five_c}{five}%{Colors.END} | 리셋 {five_reset}")
            print(f"  주간 (7d)  {make_bar(seven, 25, seven_c)} {seven_c}{seven}%{Colors.END} | 리셋 {seven_reset}")
        else:
            print(f"  {Colors.YELLOW}할당량 API 일시 중단{Colors.END}")
    else:
        print()

    claude_today = get_claude_token_stats('today')
    if claude_today and claude_today['total_tokens'] > 0:
        print(
            f"  오늘 {Colors.GREEN}{format_number(claude_today['total_tokens'])}{Colors.END} tokens"
            f" · {claude_today['requests']} req"
        )
    elif not quota:
        print(f"  {Colors.RED}데이터 없음{Colors.END}")

    print_separator()

    # Codex
    codex = get_codex_usage()
    print(f"\n{Colors.BOLD} Codex{Colors.END}", end="")
    if codex:
        plan_label = (codex.get("plan") or "?").capitalize()
        five = codex["five_hour"]
        seven = codex["seven_day"]
        five_c = usage_color(five)
        seven_c = usage_color(seven)
        five_reset = format_seconds_remaining(codex.get("five_hour_reset_seconds"))
        seven_reset = format_seconds_remaining(codex.get("seven_day_reset_seconds"))

        print(f" {Colors.GRAY}({plan_label}){Colors.END}")
        if codex.get("source") == "session_rate_limits":
            print(f"  {Colors.YELLOW}OAuth 할당량: 로컬 세션 피드{Colors.END}")
        print(f"  세션 (5h)  {make_bar(five, 25, five_c)} {five_c}{five}%{Colors.END} | 리셋 {five_reset}")
        print(f"  주간 (7d)  {make_bar(seven, 25, seven_c)} {seven_c}{seven}%{Colors.END} | 리셋 {seven_reset}")
    else:
        codex_today = get_codex_token_stats('today') or empty_token_stats()
        codex_week = get_codex_token_stats('week') or empty_token_stats()
        if codex_today['total_tokens'] > 0 or codex_week['total_tokens'] > 0:
            print(f" {Colors.YELLOW}(OAuth 할당량 미연결 · 로컬 토큰){Colors.END}")
            print(
                f"  오늘 {format_number(codex_today['total_tokens'])}"
                f" | 7일 {format_number(codex_week['total_tokens'])}"
                f" | 요청 {codex_today['requests']}"
            )
        else:
            print(f" {Colors.RED}(데이터 없음){Colors.END}")

    # Vanguard Alert
    total_today = _get_total_today_tokens()
    show_vanguard_alert(total_today)

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_claude_detail():
    print_header("  Claude 상세 정보")

    quota = get_claude_quota()
    if quota:
        plan = quota.get("plan", "?")
        five = quota.get("five_hour") or 0
        seven = quota.get("seven_day") or 0
        five_c = usage_color(five)
        seven_c = usage_color(seven)
        five_reset = format_time_remaining(quota.get("five_hour_reset"))
        seven_reset = format_time_remaining(quota.get("seven_day_reset"))

        print(f"\n{Colors.BOLD}플랜:{Colors.END} {plan}")
        print(f"\n{Colors.BOLD}세션 할당량 (5시간):{Colors.END}")
        print(f"  {make_bar(five, 30, five_c)} {five_c}{five}%{Colors.END}")
        print(f"  리셋까지: {five_reset}")
        print(f"\n{Colors.BOLD}주간 할당량 (7일):{Colors.END}")
        print(f"  {make_bar(seven, 30, seven_c)} {seven_c}{seven}%{Colors.END}")
        print(f"  리셋까지: {seven_reset}")
    else:
        print(f"\n{Colors.RED}할당량 데이터를 가져올 수 없습니다{Colors.END}")

    stats = get_claude_token_stats('today')
    if stats and stats['total_tokens'] > 0:
        print(f"\n{Colors.BOLD}오늘 토큰 사용량:{Colors.END}")
        print(f"  총 토큰    {Colors.GREEN}{format_number(stats['total_tokens'])}{Colors.END}")
        print(f"  요청 수    {Colors.YELLOW}{stats['requests']}{Colors.END}")
        total = stats['total_tokens']
        print(f"\n{Colors.BOLD}상세:{Colors.END}")
        _print_bar("입력 토큰", stats['input_tokens'], total, Colors.BLUE)
        _print_bar("출력 토큰", stats['output_tokens'], total, Colors.GREEN)
        _print_bar("캐시 읽기", stats['cache_read_tokens'], total, Colors.CYAN)

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_codex_detail():
    print_header("  Codex 상세 정보")

    codex = get_codex_usage()
    if not codex:
        print(f"\n{Colors.YELLOW}Codex OAuth 계정 할당량 데이터를 가져오지 못했습니다.{Colors.END}")
        print("로컬 세션 토큰 통계는 계속 표시합니다.")
    else:
        plan_label = (codex.get("plan") or "?").capitalize()
        five = codex["five_hour"]
        seven = codex["seven_day"]
        five_c = usage_color(five)
        seven_c = usage_color(seven)
        five_reset = format_seconds_remaining(codex.get("five_hour_reset_seconds"))
        seven_reset = format_seconds_remaining(codex.get("seven_day_reset_seconds"))

        print(f"\n{Colors.BOLD}플랜:{Colors.END} ChatGPT {plan_label}")
        if codex.get("source") == "session_rate_limits":
            print(f"{Colors.YELLOW}OAuth 할당량을 로컬 세션 피드에서 복원했습니다.{Colors.END}")
        if codex.get("email"):
            print(f"{Colors.BOLD}계정:{Colors.END} {codex['email']}")
        if codex.get("subscription_start") and codex.get("subscription_until"):
            print(f"{Colors.BOLD}구독 기간:{Colors.END} {codex['subscription_start']} ~ {codex['subscription_until']}")

        print(f"\n{Colors.BOLD}세션 할당량 (5시간):{Colors.END}")
        print(f"  {make_bar(five, 30, five_c)} {five_c}{five}%{Colors.END}")
        print(f"  리셋까지: {five_reset}")
        print(f"\n{Colors.BOLD}주간 할당량 (7일):{Colors.END}")
        print(f"  {make_bar(seven, 30, seven_c)} {seven_c}{seven}%{Colors.END}")
        print(f"  리셋까지: {seven_reset}")

        if codex.get("credits_unlimited"):
            print(f"\n{Colors.BOLD}크레딧:{Colors.END} 무제한")
        elif codex.get("credits_balance") and codex["credits_balance"] != "0":
            print(f"\n{Colors.BOLD}크레딧:{Colors.END} ${codex['credits_balance']}")

    today = get_codex_token_stats('today')
    week = get_codex_token_stats('week')
    month = get_codex_token_stats('month')

    if today:
        print(f"\n{Colors.BOLD}토큰 사용량:{Colors.END}")
        print(
            f"  오늘 {format_number(today['total_tokens'])}"
            f" | 7일 {format_number(week['total_tokens'])}"
            f" | 30일 {format_number(month['total_tokens'])}"
        )
        if today['total_tokens'] > 0:
            total = today['total_tokens']
            print(f"\n{Colors.BOLD}오늘 상세:{Colors.END}")
            _print_bar("입력 토큰", today['input_tokens'], total, Colors.BLUE)
            _print_bar("출력 토큰", today['output_tokens'], total, Colors.GREEN)
            _print_bar("캐시 읽기", today['cache_read_tokens'], total, Colors.CYAN)
            _print_bar("추론 토큰", today['reasoning_output_tokens'], total, Colors.YELLOW)
            print(f"  요청 수      {today['requests']}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_claude_period(period):
    period_names = {
        'today': '오늘',
        'week': '최근 7일',
        'month': '최근 30일',
        'all': '전체',
    }
    period_name = period_names.get(period, period)

    print_header(f"  Claude 토큰 사용량 - {period_name}")

    stats = get_claude_token_stats(period)
    if stats is None:
        print(f"\n{Colors.RED}Claude 디렉토리를 찾을 수 없습니다{Colors.END}")
        print("Claude Code를 먼저 실행해주세요.")
        return

    print(f"\n{Colors.BOLD}총 토큰:{Colors.END} {Colors.GREEN}{format_number(stats['total_tokens'])}{Colors.END}")
    print(f"{Colors.BOLD}요청 수:{Colors.END} {Colors.YELLOW}{stats['requests']}{Colors.END}\n")

    total = stats['total_tokens']
    print(f"{Colors.BOLD}상세 분석:{Colors.END}")
    _print_bar("입력 토큰", stats['input_tokens'], total, Colors.BLUE)
    _print_bar("출력 토큰", stats['output_tokens'], total, Colors.GREEN)
    _print_bar("캐시 읽기", stats['cache_read_tokens'], total, Colors.CYAN)

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def display_token_overview():
    print_header("  통합 토큰 사용량 요약")

    claude_today = get_claude_token_stats('today') or empty_token_stats()
    claude_week = get_claude_token_stats('week') or empty_token_stats()
    claude_month = get_claude_token_stats('month') or empty_token_stats()

    codex_today = get_codex_token_stats('today') or empty_token_stats()
    codex_week = get_codex_token_stats('week') or empty_token_stats()
    codex_month = get_codex_token_stats('month') or empty_token_stats()

    print(f"\n{Colors.BOLD}Claude{Colors.END}")
    print(
        f"  오늘 {format_number(claude_today['total_tokens'])}"
        f" | 7일 {format_number(claude_week['total_tokens'])}"
        f" | 30일 {format_number(claude_month['total_tokens'])}"
    )

    print(f"\n{Colors.BOLD}Codex{Colors.END}")
    print(
        f"  오늘 {format_number(codex_today['total_tokens'])}"
        f" | 7일 {format_number(codex_week['total_tokens'])}"
        f" | 30일 {format_number(codex_month['total_tokens'])}"
    )

    # Vanguard Alert
    total_today = (
        claude_today['total_tokens']
        + codex_today['total_tokens']
    )
    show_vanguard_alert(total_today)

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


def _print_bar(label, value, max_value, color):
    percentage = min(100, (value / max_value * 100)) if max_value > 0 else 0
    bar = make_bar(percentage, 25, color)
    print(f"  {label:12} {bar} {format_number(value)} ({percentage:.1f}%)")


def watch_mode():
    try:
        while True:
            clear_screen()
            display_summary()
            print(f"{Colors.YELLOW}[실시간 모니터링 중... Ctrl+C로 종료]{Colors.END}")
            time.sleep(5)
    except KeyboardInterrupt:
        print(f"\n{Colors.GREEN}모니터링 종료{Colors.END}\n")


# ─── DB 수집 & 인사이트 ──────────────────────────────────────

def _get_db_module():
    script_dir = Path(__file__).resolve().parent.parent
    db_path = script_dir / "lib" / "ai" / "db.py"
    if not db_path.exists():
        print(f"{Colors.RED}DB 모듈을 찾을 수 없습니다: {db_path}{Colors.END}")
        sys.exit(1)
    import importlib.util
    spec = importlib.util.spec_from_file_location("db", str(db_path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def collect_to_db():
    db = _get_db_module()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"{Colors.BOLD}데이터 수집 중...{Colors.END}")

    claude = get_claude_token_stats('today')
    if claude and claude['total_tokens'] > 0:
        db.upsert_daily(today, 'claude', claude)
        print(f"  Claude: {format_number(claude['total_tokens'])} tokens")

    codex = get_codex_token_stats('today')
    if codex and codex['total_tokens'] > 0:
        db.upsert_daily(today, 'codex', codex)
        print(f"  Codex:  {format_number(codex['total_tokens'])} tokens")

    # 할당량 스냅샷 저장
    quota = get_claude_quota()
    if quota:
        db.save_snapshot('claude_quota', quota)

    codex_quota = get_codex_usage()
    if codex_quota:
        db.save_snapshot('codex_quota', codex_quota)

    print(f"\n{Colors.GREEN}수집 완료{Colors.END} → {db.DB_PATH}")


def display_insights():
    db = _get_db_module()

    total = db.get_total_by_period(30)
    if not total or not total.get('total_tokens'):
        print(f"\n{Colors.YELLOW}DB에 데이터가 없습니다.{Colors.END}")
        print(f"먼저 'dxai ai collect'를 실행하세요.")
        print(f"매일 실행하면 트렌드를 확인할 수 있습니다.")
        return

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}  dxai Insights (최근 30일){Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}")

    # 트렌드
    trend = db.get_trend(30)
    print(f"\n{Colors.BOLD}{Colors.BLUE}[트렌드]{Colors.END}")
    first_avg = format_number(trend['first_half_avg'])
    second_avg = format_number(trend['second_half_avg'])
    change = trend['change_pct']
    if change > 0:
        arrow = f"{Colors.GREEN}+{change}%{Colors.END}"
    elif change < 0:
        arrow = f"{Colors.RED}{change}%{Colors.END}"
    else:
        arrow = f"{Colors.GRAY}0%{Colors.END}"
    print(f"  일평균 토큰       {first_avg} → {second_avg}  ({arrow})")

    cache = db.get_cache_efficiency(30)
    print(f"  캐시 히트율        {Colors.CYAN}{cache['cache_hit_rate']}%{Colors.END}")

    # 도구별 분포
    breakdown = db.get_tool_breakdown(30)
    print(f"\n{Colors.BOLD}{Colors.BLUE}[도구별 사용량]{Colors.END}")
    grand_total = total['total_tokens'] or 1
    for row in breakdown:
        pct = (row['total_tokens'] / grand_total) * 100
        tokens = format_number(row['total_tokens'])
        bar_len = int(pct / 5)
        bar = f"{Colors.CYAN}{'█' * bar_len}{'░' * (20 - bar_len)}{Colors.END}"
        print(f"  {row['tool']:8} {bar} {tokens:>8} ({pct:.0f}%)")

    # 활동 패턴
    print(f"\n{Colors.BOLD}{Colors.BLUE}[패턴]{Colors.END}")
    print(f"  활동일 수          {total['days_active']}일 / 30일")
    print(f"  총 요청            {format_number(total['requests'])}")
    daily_avg = total['total_tokens'] / max(1, total['days_active'])
    print(f"  일평균 토큰        {format_number(int(daily_avg))}")

    # 가장 바쁜 날
    busiest = db.get_busiest_days(30, 3)
    if busiest:
        print(f"\n{Colors.BOLD}{Colors.BLUE}[가장 바쁜 날]{Colors.END}")
        for row in busiest:
            print(f"  {row['date']}    {format_number(row['tokens'])}")

    # Vanguard 등급 판정 (일평균 기준)
    level, color, message = get_vanguard_alert(int(daily_avg))
    if level:
        print(f"\n  {color}[Vanguard {level}]{Colors.END} {color}일평균 기준: {message}{Colors.END}")

    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 60}{Colors.END}\n")


# ─── 메인 ────────────────────────────────────────────────────

def main():
    args = sys.argv[1:] if len(sys.argv) > 1 else []
    command = args[0].lower() if args else ''

    if command in ['-h', '--help', 'help']:
        print(__doc__)
        sys.exit(0)

    if command == 'watch':
        watch_mode()
        return

    if command == 'json':
        data = {
            "claude_quota": get_claude_quota(),
            "claude_tokens": {
                "today": get_claude_token_stats('today'),
                "week": get_claude_token_stats('week'),
                "month": get_claude_token_stats('month'),
            },
            "codex_quota": get_codex_usage(),
            "codex_tokens": {
                "today": get_codex_token_stats('today'),
                "week": get_codex_token_stats('week'),
                "month": get_codex_token_stats('month'),
            },
            "vanguard": None,
        }
        total_today = (
            (data["claude_tokens"]["today"] or {}).get("total_tokens", 0)
            + (data["codex_tokens"]["today"] or {}).get("total_tokens", 0)
        )
        level, _, message = get_vanguard_alert(total_today)
        if level:
            data["vanguard"] = {"level": level, "message": message, "total_today": total_today}
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return

    if command == 'claude':
        display_claude_detail()
        return

    if command == 'codex':
        display_codex_detail()
        return

    if command == 'tokens':
        display_token_overview()
        return

    if command in ['today', 'week', 'month', 'all']:
        display_claude_period(command)
        return

    if command == 'collect':
        collect_to_db()
        return

    if command == 'insights':
        display_insights()
        return

    valid_commands = ['', 'today', 'week', 'month', 'all',
                      'claude', 'codex', 'tokens', 'watch', 'json',
                      'collect', 'insights']
    if command and command not in valid_commands:
        print(f"{Colors.RED}잘못된 명령어: {command}{Colors.END}")
        print("\n사용 가능한 명령어:")
        print("  (없음)     전체 요약")
        print("  claude     Claude 상세")
        print("  codex      Codex 상세")
        print("  tokens     통합 토큰 요약")
        print("  today      Claude 오늘 토큰")
        print("  week       Claude 최근 7일")
        print("  month      Claude 최근 30일")
        print("  watch      실시간 모니터링")
        print("  json       JSON 출력")
        print("  collect    DB에 오늘 데이터 수집")
        print("  insights   트렌드/패턴 분석 (DB 필요)")
        sys.exit(1)

    display_summary()


if __name__ == '__main__':
    main()
