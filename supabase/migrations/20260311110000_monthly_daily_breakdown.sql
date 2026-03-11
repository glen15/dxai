-- Monthly enhanced: daily_breakdown 컬럼 추가 (주간 뷰와 동일 패턴)
-- DROP 필수: CREATE OR REPLACE는 리턴 타입 변경 불가

DROP FUNCTION IF EXISTS leaderboard_monthly_enhanced(DATE, DATE, INT, INT);

CREATE OR REPLACE FUNCTION leaderboard_monthly_enhanced(
  p_start_date DATE,
  p_end_date DATE,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  period_points BIGINT,
  period_coins BIGINT,
  days_active BIGINT,
  claude_tokens BIGINT,
  codex_tokens BIGINT,
  best_tier TEXT,
  best_division INT,
  period_days INT,
  daily_breakdown JSONB
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
      SELECT dr2.vanguard_tier
      FROM daily_records dr2
      WHERE dr2.user_id = u.id
        AND dr2.date BETWEEN p_start_date AND p_end_date
      ORDER BY dr2.daily_points DESC
      LIMIT 1
    ) AS best_tier,
    (
      SELECT dr2.vanguard_division
      FROM daily_records dr2
      WHERE dr2.user_id = u.id
        AND dr2.date BETWEEN p_start_date AND p_end_date
      ORDER BY dr2.daily_points DESC
      LIMIT 1
    ) AS best_division,
    (p_end_date - p_start_date + 1)::INT AS period_days,
    -- daily_breakdown: [{date, points}] for each day in the month
    (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object('date', db.date::TEXT, 'points', db.daily_points)
          ORDER BY db.date
        ),
        '[]'::JSONB
      )
      FROM daily_records db
      WHERE db.user_id = u.id
        AND db.date BETWEEN p_start_date AND p_end_date
    ) AS daily_breakdown
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date BETWEEN p_start_date AND p_end_date
  GROUP BY u.id, u.nickname
  ORDER BY period_points DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;
