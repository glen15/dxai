import importlib.util
import sqlite3
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "bin" / "ai.py"
SPEC = importlib.util.spec_from_file_location("dxai_ai", MODULE_PATH)
AI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AI)


class HermesTokenStatsTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "state.db"
        self.period_start = datetime(2026, 7, 11, tzinfo=timezone.utc)
        self.original_db_iterator = AI.iter_hermes_state_dbs
        self.original_period_start = AI.get_period_start
        self.original_codex_files = AI.iter_codex_jsonl_files
        self.original_codex_floor = AI._apply_codex_state_floor
        self._create_db()

        AI.iter_hermes_state_dbs = lambda: iter([self.db_path])
        AI.get_period_start = lambda _period: self.period_start

    def tearDown(self):
        AI.iter_hermes_state_dbs = self.original_db_iterator
        AI.get_period_start = self.original_period_start
        AI.iter_codex_jsonl_files = self.original_codex_files
        AI._apply_codex_state_floor = self.original_codex_floor
        self.temp_dir.cleanup()

    def _create_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE sessions (
                    id TEXT PRIMARY KEY,
                    started_at REAL NOT NULL,
                    billing_provider TEXT,
                    input_tokens INTEGER DEFAULT 0,
                    output_tokens INTEGER DEFAULT 0,
                    cache_read_tokens INTEGER DEFAULT 0,
                    cache_write_tokens INTEGER DEFAULT 0,
                    reasoning_tokens INTEGER DEFAULT 0
                )
                """
            )
            start = int(self.period_start.timestamp())
            conn.executemany(
                "INSERT INTO sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    ("codex", start + 1, "openai-codex", 10, 20, 30, 40, 50),
                    ("api", start + 2, "openai-api", 1, 2, 3, 4, 5),
                    ("empty", start + 3, None, 0, 0, 0, 0, 0),
                    ("old", start - 1, "openai-codex", 100, 0, 0, 0, 0),
                ],
            )

    def test_aggregates_all_hermes_providers_and_excludes_empty_sessions(self):
        stats = AI.get_hermes_token_stats("today")

        self.assertEqual(stats["input_tokens"], 55)
        self.assertEqual(stats["output_tokens"], 77)
        self.assertEqual(stats["cache_read_tokens"], 33)
        self.assertEqual(stats["cache_creation_tokens"], 44)
        self.assertEqual(stats["reasoning_output_tokens"], 55)
        self.assertEqual(stats["total_tokens"], 165)
        self.assertEqual(stats["requests"], 2)

    def test_codex_stats_do_not_include_hermes(self):
        AI.iter_codex_jsonl_files = lambda: iter([])
        AI._apply_codex_state_floor = lambda _stats, _period: None

        stats = AI.get_codex_token_stats("today")

        self.assertEqual(stats["total_tokens"], 0)
        self.assertNotIn("hermes_codex_tokens", stats)


if __name__ == "__main__":
    unittest.main()
