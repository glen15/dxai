#!/usr/bin/env python3
"""
dxai 데이터 레이어 - SQLite 로컬 DB

일별 토큰 사용량을 축적하여 인사이트를 제공한다.
저장 위치: ~/.config/dxai/dxai.db
"""

import json
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path


DB_PATH = Path.home() / ".config" / "dxai" / "dxai.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS daily_stats (
    date        TEXT NOT NULL,
    tool        TEXT NOT NULL,
    input_tokens       INTEGER DEFAULT 0,
    output_tokens      INTEGER DEFAULT 0,
    cache_read_tokens  INTEGER DEFAULT 0,
    total_tokens       INTEGER DEFAULT 0,
    requests           INTEGER DEFAULT 0,
    PRIMARY KEY (date, tool)
);

CREATE TABLE IF NOT EXISTS snapshots (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp   TEXT NOT NULL,
    tool        TEXT NOT NULL,
    data_json   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_daily_date ON daily_stats(date);
CREATE INDEX IF NOT EXISTS idx_snap_ts ON snapshots(timestamp);
"""


def get_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def upsert_daily(date_str, tool, stats):
    conn = get_db()
    try:
        conn.execute("""
            INSERT INTO daily_stats (date, tool, input_tokens, output_tokens,
                                     cache_read_tokens, total_tokens, requests)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(date, tool) DO UPDATE SET
                input_tokens = excluded.input_tokens,
                output_tokens = excluded.output_tokens,
                cache_read_tokens = excluded.cache_read_tokens,
                total_tokens = excluded.total_tokens,
                requests = excluded.requests
        """, (
            date_str, tool,
            stats.get('input_tokens', 0),
            stats.get('output_tokens', 0),
            stats.get('cache_read_tokens', 0),
            stats.get('total_tokens', 0),
            stats.get('requests', 0),
        ))
        conn.commit()
    finally:
        conn.close()


def save_snapshot(tool, data):
    conn = get_db()
    try:
        now = datetime.now(timezone.utc).isoformat()
        conn.execute(
            "INSERT INTO snapshots (timestamp, tool, data_json) VALUES (?, ?, ?)",
            (now, tool, json.dumps(data, ensure_ascii=False)),
        )
        conn.commit()
    finally:
        conn.close()


def get_daily_range(days=30):
    conn = get_db()
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        rows = conn.execute(
            "SELECT * FROM daily_stats WHERE date >= ? ORDER BY date",
            (cutoff,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_daily_by_tool(tool, days=30):
    conn = get_db()
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        rows = conn.execute(
            "SELECT * FROM daily_stats WHERE date >= ? AND tool = ? ORDER BY date",
            (cutoff, tool),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_total_by_period(days=30):
    conn = get_db()
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        row = conn.execute("""
            SELECT
                SUM(total_tokens) as total_tokens,
                SUM(input_tokens) as input_tokens,
                SUM(output_tokens) as output_tokens,
                SUM(cache_read_tokens) as cache_read_tokens,
                SUM(requests) as requests,
                COUNT(DISTINCT date) as days_active
            FROM daily_stats WHERE date >= ?
        """, (cutoff,)).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def get_tool_breakdown(days=30):
    conn = get_db()
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        rows = conn.execute("""
            SELECT tool,
                   SUM(total_tokens) as total_tokens,
                   SUM(requests) as requests,
                   COUNT(DISTINCT date) as days_active
            FROM daily_stats WHERE date >= ?
            GROUP BY tool ORDER BY total_tokens DESC
        """, (cutoff,)).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_trend(days=30):
    """전반기 vs 후반기 비교로 트렌드 계산"""
    conn = get_db()
    try:
        now = datetime.now(timezone.utc)
        mid = (now - timedelta(days=days // 2)).strftime("%Y-%m-%d")
        start = (now - timedelta(days=days)).strftime("%Y-%m-%d")

        first_half = conn.execute("""
            SELECT COALESCE(SUM(total_tokens), 0) as tokens,
                   COUNT(DISTINCT date) as days
            FROM daily_stats WHERE date >= ? AND date < ?
        """, (start, mid)).fetchone()

        second_half = conn.execute("""
            SELECT COALESCE(SUM(total_tokens), 0) as tokens,
                   COUNT(DISTINCT date) as days
            FROM daily_stats WHERE date >= ?
        """, (mid,)).fetchone()

        first_avg = first_half["tokens"] / max(1, first_half["days"])
        second_avg = second_half["tokens"] / max(1, second_half["days"])

        if first_avg > 0:
            change_pct = ((second_avg - first_avg) / first_avg) * 100
        else:
            change_pct = 0

        return {
            "first_half_avg": int(first_avg),
            "second_half_avg": int(second_avg),
            "change_pct": round(change_pct, 1),
        }
    finally:
        conn.close()


def get_cache_efficiency(days=30):
    conn = get_db()
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        row = conn.execute("""
            SELECT
                COALESCE(SUM(cache_read_tokens), 0) as cache_tokens,
                COALESCE(SUM(input_tokens), 0) as input_tokens,
                COALESCE(SUM(total_tokens), 0) as total_tokens
            FROM daily_stats WHERE date >= ?
        """, (cutoff,)).fetchone()

        total_input = row["input_tokens"] + row["cache_tokens"]
        if total_input > 0:
            cache_hit_rate = (row["cache_tokens"] / total_input) * 100
        else:
            cache_hit_rate = 0

        return {
            "cache_hit_rate": round(cache_hit_rate, 1),
            "cache_tokens": row["cache_tokens"],
            "total_tokens": row["total_tokens"],
        }
    finally:
        conn.close()


def get_busiest_days(days=30, limit=5):
    conn = get_db()
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        rows = conn.execute("""
            SELECT date, SUM(total_tokens) as tokens
            FROM daily_stats WHERE date >= ?
            GROUP BY date ORDER BY tokens DESC LIMIT ?
        """, (cutoff, limit)).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()
