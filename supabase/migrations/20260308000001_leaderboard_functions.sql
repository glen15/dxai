-- 주간/월간 리더보드 집계 함수

-- 기간별 리더보드 (주간, 월간)
CREATE OR REPLACE FUNCTION leaderboard_period(
  start_date DATE,
  end_date DATE,
  page_size INT DEFAULT 50,
  page_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  period_points BIGINT,
  period_coins BIGINT,
  days_active BIGINT,
  claude_tokens BIGINT,
  codex_tokens BIGINT,
  best_tier TEXT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    SUM(dr.daily_points)::BIGINT AS period_points,
    SUM(dr.daily_coins)::BIGINT AS period_coins,
    COUNT(dr.id)::BIGINT AS days_active,
    SUM(dr.claude_tokens)::BIGINT AS claude_tokens,
    SUM(dr.codex_tokens)::BIGINT AS codex_tokens,
    (
      SELECT dr2.pioneer_tier
      FROM daily_records dr2
      WHERE dr2.user_id = u.id
        AND dr2.date BETWEEN start_date AND end_date
      ORDER BY dr2.daily_points DESC
      LIMIT 1
    ) AS best_tier
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date BETWEEN start_date AND end_date
  GROUP BY u.id, u.nickname
  ORDER BY 2 DESC
  LIMIT page_size
  OFFSET page_offset;
$$;

-- 기간별 참여자 수 카운트
CREATE OR REPLACE FUNCTION leaderboard_period_count(
  start_date DATE,
  end_date DATE
)
RETURNS BIGINT
LANGUAGE sql STABLE
AS $$
  SELECT COUNT(DISTINCT user_id)::BIGINT
  FROM daily_records
  WHERE date BETWEEN start_date AND end_date;
$$;
