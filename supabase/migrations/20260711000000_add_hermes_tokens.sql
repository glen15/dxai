BEGIN;

-- Existing rows cannot be split reliably because older clients submitted
-- Codex and Hermes as one codex_tokens value. Keep those totals intact and
-- start recording Hermes separately for new clients.
ALTER TABLE daily_records
  ADD COLUMN IF NOT EXISTS hermes_tokens BIGINT NOT NULL DEFAULT 0
  CHECK (hermes_tokens >= 0);

DROP FUNCTION IF EXISTS leaderboard_daily_by_tokens(DATE, INT, INT);
DROP FUNCTION IF EXISTS leaderboard_weekly_enhanced(DATE, DATE, INT, INT);
DROP FUNCTION IF EXISTS leaderboard_monthly_enhanced(DATE, DATE, INT, INT);
DROP FUNCTION IF EXISTS leaderboard_total_enhanced(INT, INT);
DROP FUNCTION IF EXISTS leaderboard_by_tokens(INT, INT);

CREATE FUNCTION leaderboard_daily_by_tokens(
  p_date DATE,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  daily_coins INT,
  vanguard_tier TEXT,
  vanguard_division INT,
  claude_tokens BIGINT,
  codex_tokens BIGINT,
  hermes_tokens BIGINT,
  total_tokens BIGINT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    dr.daily_coins,
    dr.vanguard_tier,
    dr.vanguard_division,
    dr.claude_tokens,
    dr.codex_tokens,
    dr.hermes_tokens,
    COALESCE((
      SELECT SUM(dr2.claude_tokens + dr2.codex_tokens + dr2.hermes_tokens)
      FROM daily_records dr2
      WHERE dr2.user_id = dr.user_id
    ), 0)::BIGINT AS total_tokens
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date = p_date
  ORDER BY (dr.claude_tokens + dr.codex_tokens + dr.hermes_tokens) DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

CREATE FUNCTION leaderboard_weekly_enhanced(
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
  hermes_tokens BIGINT,
  best_tier TEXT,
  streak INT,
  prev_week_points BIGINT,
  daily_breakdown JSONB
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    SUM(dr.daily_coins)::BIGINT AS period_points,
    SUM(dr.daily_coins)::BIGINT AS period_coins,
    COUNT(dr.id)::BIGINT AS days_active,
    SUM(dr.claude_tokens)::BIGINT AS claude_tokens,
    SUM(dr.codex_tokens)::BIGINT AS codex_tokens,
    SUM(dr.hermes_tokens)::BIGINT AS hermes_tokens,
    (
      SELECT dr2.vanguard_tier
      FROM daily_records dr2
      WHERE dr2.user_id = u.id
        AND dr2.date BETWEEN p_start_date AND p_end_date
      ORDER BY dr2.daily_coins DESC, dr2.date DESC
      LIMIT 1
    ) AS best_tier,
    (
      SELECT COALESCE(MAX(run_len), 0)::INT
      FROM (
        SELECT COUNT(*)::INT AS run_len
        FROM (
          SELECT d.date,
                 d.date - (ROW_NUMBER() OVER (ORDER BY d.date))::INT AS grp
          FROM daily_records d
          WHERE d.user_id = u.id
            AND d.date BETWEEN p_start_date AND p_end_date
        ) active_days
        GROUP BY grp
      ) runs
    ) AS streak,
    (
      SELECT COALESCE(SUM(previous.daily_coins), 0)::BIGINT
      FROM daily_records previous
      WHERE previous.user_id = u.id
        AND previous.date BETWEEN (p_start_date - 7) AND (p_start_date - 1)
    ) AS prev_week_points,
    (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object('date', daily.date::TEXT, 'points', daily.daily_coins)
          ORDER BY daily.date
        ),
        '[]'::JSONB
      )
      FROM daily_records daily
      WHERE daily.user_id = u.id
        AND daily.date BETWEEN p_start_date AND p_end_date
    ) AS daily_breakdown
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date BETWEEN p_start_date AND p_end_date
  GROUP BY u.id, u.nickname
  ORDER BY SUM(dr.daily_coins) DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

CREATE FUNCTION leaderboard_monthly_enhanced(
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
  hermes_tokens BIGINT,
  best_tier TEXT,
  best_division INT,
  period_days INT,
  daily_breakdown JSONB
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    SUM(dr.daily_coins)::BIGINT AS period_points,
    SUM(dr.daily_coins)::BIGINT AS period_coins,
    COUNT(dr.id)::BIGINT AS days_active,
    SUM(dr.claude_tokens)::BIGINT AS claude_tokens,
    SUM(dr.codex_tokens)::BIGINT AS codex_tokens,
    SUM(dr.hermes_tokens)::BIGINT AS hermes_tokens,
    best.vanguard_tier AS best_tier,
    best.vanguard_division AS best_division,
    (p_end_date - p_start_date + 1)::INT AS period_days,
    (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object('date', daily.date::TEXT, 'points', daily.daily_coins)
          ORDER BY daily.date
        ),
        '[]'::JSONB
      )
      FROM daily_records daily
      WHERE daily.user_id = u.id
        AND daily.date BETWEEN p_start_date AND p_end_date
    ) AS daily_breakdown
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  CROSS JOIN LATERAL (
    SELECT dr2.vanguard_tier, dr2.vanguard_division
    FROM daily_records dr2
    WHERE dr2.user_id = u.id
      AND dr2.date BETWEEN p_start_date AND p_end_date
    ORDER BY dr2.daily_coins DESC, dr2.date DESC
    LIMIT 1
  ) best
  WHERE dr.date BETWEEN p_start_date AND p_end_date
  GROUP BY u.id, u.nickname, best.vanguard_tier, best.vanguard_division
  ORDER BY SUM(dr.daily_coins) DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

CREATE FUNCTION leaderboard_total_enhanced(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  total_points INT,
  total_coins INT,
  last_tier TEXT,
  last_division INT,
  total_claude_tokens BIGINT,
  total_codex_tokens BIGINT,
  total_hermes_tokens BIGINT,
  total_days_active BIGINT,
  member_since DATE,
  current_streak INT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    u.total_coins AS total_points,
    u.total_coins,
    u.last_tier,
    u.last_division,
    COALESCE(stats.total_claude_tokens, 0)::BIGINT,
    COALESCE(stats.total_codex_tokens, 0)::BIGINT,
    COALESCE(stats.total_hermes_tokens, 0)::BIGINT,
    COALESCE(stats.total_days_active, 0)::BIGINT,
    u.created_at::DATE AS member_since,
    COALESCE(stats.current_streak, 0)::INT
  FROM users u
  LEFT JOIN LATERAL (
    SELECT
      SUM(dr.claude_tokens) AS total_claude_tokens,
      SUM(dr.codex_tokens) AS total_codex_tokens,
      SUM(dr.hermes_tokens) AS total_hermes_tokens,
      COUNT(DISTINCT dr.date) AS total_days_active,
      (
        SELECT CASE
          WHEN MAX(streak_days.date) < CURRENT_DATE - 1 THEN 0
          ELSE COUNT(*)::INT
        END
        FROM (
          SELECT active.date,
                 active.date + (ROW_NUMBER() OVER (ORDER BY active.date DESC))::INT AS grp
          FROM daily_records active
          WHERE active.user_id = u.id
        ) streak_days
        WHERE streak_days.grp = (
          SELECT latest.date + 1
          FROM daily_records latest
          WHERE latest.user_id = u.id
          ORDER BY latest.date DESC
          LIMIT 1
        )
      ) AS current_streak
    FROM daily_records dr
    WHERE dr.user_id = u.id
  ) stats ON TRUE
  ORDER BY u.total_coins DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

CREATE FUNCTION leaderboard_by_tokens(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  total_tokens BIGINT,
  total_claude_tokens BIGINT,
  total_codex_tokens BIGINT,
  total_hermes_tokens BIGINT,
  total_coins INT,
  last_tier TEXT,
  last_division INT,
  total_days_active BIGINT,
  member_since TIMESTAMPTZ
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    COALESCE(SUM(dr.claude_tokens + dr.codex_tokens + dr.hermes_tokens), 0)::BIGINT,
    COALESCE(SUM(dr.claude_tokens), 0)::BIGINT,
    COALESCE(SUM(dr.codex_tokens), 0)::BIGINT,
    COALESCE(SUM(dr.hermes_tokens), 0)::BIGINT,
    u.total_coins,
    u.last_tier,
    u.last_division,
    COUNT(dr.id)::BIGINT,
    u.created_at
  FROM users u
  LEFT JOIN daily_records dr ON dr.user_id = u.id
  GROUP BY u.id, u.nickname, u.total_coins, u.last_tier, u.last_division, u.created_at
  ORDER BY COALESCE(SUM(dr.claude_tokens + dr.codex_tokens + dr.hermes_tokens), 0) DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

CREATE OR REPLACE FUNCTION search_users(
  p_query TEXT,
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  nickname TEXT,
  total_coins INT,
  last_tier TEXT,
  last_division INT,
  total_tokens BIGINT,
  total_days_active BIGINT,
  member_since TIMESTAMPTZ
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    u.total_coins,
    u.last_tier,
    u.last_division,
    COALESCE(SUM(dr.claude_tokens + dr.codex_tokens + dr.hermes_tokens), 0)::BIGINT,
    COUNT(dr.id)::BIGINT,
    u.created_at
  FROM users u
  LEFT JOIN daily_records dr ON dr.user_id = u.id
  WHERE u.nickname ILIKE '%' || p_query || '%'
  GROUP BY u.id, u.nickname, u.total_coins, u.last_tier, u.last_division, u.created_at
  ORDER BY COALESCE(SUM(dr.claude_tokens + dr.codex_tokens + dr.hermes_tokens), 0) DESC
  LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION user_token_rank(p_nickname TEXT)
RETURNS TABLE (rank BIGINT, total_tokens BIGINT)
LANGUAGE sql STABLE
AS $$
  WITH ranked AS (
    SELECT
      u.nickname,
      COALESCE(SUM(dr.claude_tokens + dr.codex_tokens + dr.hermes_tokens), 0)::BIGINT AS total_tokens,
      RANK() OVER (
        ORDER BY COALESCE(SUM(dr.claude_tokens + dr.codex_tokens + dr.hermes_tokens), 0) DESC
      ) AS rank
    FROM users u
    LEFT JOIN daily_records dr ON dr.user_id = u.id
    GROUP BY u.id, u.nickname
  )
  SELECT ranked.rank, ranked.total_tokens
  FROM ranked
  WHERE ranked.nickname = p_nickname;
$$;

CREATE OR REPLACE FUNCTION tier_distribution(
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE (tier TEXT, user_count BIGINT)
LANGUAGE sql STABLE
AS $$
  SELECT best.tier, COUNT(*)::BIGINT
  FROM (
    SELECT DISTINCT ON (dr.user_id) dr.vanguard_tier AS tier
    FROM daily_records dr
    WHERE dr.date BETWEEN p_start_date AND p_end_date
    ORDER BY dr.user_id, dr.daily_coins DESC, dr.date DESC
  ) best
  GROUP BY best.tier
  ORDER BY CASE best.tier
    WHEN 'Challenger' THEN 1
    WHEN 'Grandmaster' THEN 2
    WHEN 'Master' THEN 3
    WHEN 'Diamond' THEN 4
    WHEN 'Platinum' THEN 5
    WHEN 'Gold' THEN 6
    WHEN 'Silver' THEN 7
    WHEN 'Bronze' THEN 8
  END;
$$;

DROP VIEW IF EXISTS suspicious_duplicates;
CREATE VIEW suspicious_duplicates AS
SELECT
  u.nickname,
  today.user_id,
  today.date,
  today.claude_tokens,
  today.codex_tokens,
  today.hermes_tokens,
  today.daily_coins,
  today.vanguard_tier,
  today.vanguard_division,
  today.created_at
FROM daily_records today
JOIN daily_records previous
  ON previous.user_id = today.user_id
 AND previous.date = (today.date - INTERVAL '1 day')::DATE
JOIN users u ON u.id = today.user_id
WHERE today.claude_tokens = previous.claude_tokens
  AND today.codex_tokens = previous.codex_tokens
  AND today.hermes_tokens = previous.hermes_tokens
  AND (today.claude_tokens + today.codex_tokens + today.hermes_tokens) > 0
ORDER BY today.date DESC, u.nickname;

COMMENT ON VIEW suspicious_duplicates IS
  '전일 Claude/Codex/Hermes 토큰값과 정확히 동일한 daily_records row. 자정 경계 복제 기록 감시용.';

COMMIT;
