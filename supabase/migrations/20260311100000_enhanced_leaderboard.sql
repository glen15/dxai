-- Enhanced leaderboard functions for Weekly/Monthly/All-Time tab differentiation

-- 1. Weekly enhanced: streak, prev_week_points, daily_breakdown
CREATE OR REPLACE FUNCTION leaderboard_weekly_enhanced(
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
  streak INT,
  prev_week_points BIGINT,
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
    -- streak: max consecutive active days within this week
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
        ) sub
        GROUP BY grp
      ) runs
    ) AS streak,
    -- prev_week_points: same user's points in the 7 days before p_start_date
    (
      SELECT COALESCE(SUM(pw.daily_points), 0)::BIGINT
      FROM daily_records pw
      WHERE pw.user_id = u.id
        AND pw.date BETWEEN (p_start_date - 7) AND (p_start_date - 1)
    ) AS prev_week_points,
    -- daily_breakdown: [{date, points}] for each day in the week
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

-- 2. Monthly enhanced: best_division, period_days
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
  period_days INT
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
    (p_end_date - p_start_date + 1)::INT AS period_days
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date BETWEEN p_start_date AND p_end_date
  GROUP BY u.id, u.nickname
  ORDER BY period_points DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- 3. Total enhanced: token breakdown, days_active, member_since, current_streak
CREATE OR REPLACE FUNCTION leaderboard_total_enhanced(
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
  total_days_active BIGINT,
  member_since DATE,
  current_streak INT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    u.total_points,
    u.total_coins,
    u.last_tier,
    u.last_division,
    COALESCE((SELECT SUM(dr.claude_tokens) FROM daily_records dr WHERE dr.user_id = u.id), 0)::BIGINT
      AS total_claude_tokens,
    COALESCE((SELECT SUM(dr.codex_tokens) FROM daily_records dr WHERE dr.user_id = u.id), 0)::BIGINT
      AS total_codex_tokens,
    COALESCE((SELECT COUNT(DISTINCT dr.date) FROM daily_records dr WHERE dr.user_id = u.id), 0)::BIGINT
      AS total_days_active,
    u.created_at::DATE AS member_since,
    -- current_streak: consecutive days ending at today (or yesterday)
    (
      SELECT COALESCE(MAX(run_len), 0)::INT
      FROM (
        SELECT COUNT(*)::INT AS run_len
        FROM (
          SELECT d.date,
                 d.date - (ROW_NUMBER() OVER (ORDER BY d.date DESC))::INT AS grp
          FROM daily_records d
          WHERE d.user_id = u.id
            AND d.date >= CURRENT_DATE - 60
          ORDER BY d.date DESC
        ) sub
        WHERE grp = (
          SELECT d2.date - 1::INT
          FROM daily_records d2
          WHERE d2.user_id = u.id
          ORDER BY d2.date DESC
          LIMIT 1
        ) OR sub.date >= CURRENT_DATE - 1
        GROUP BY grp
        ORDER BY MAX(sub.date) DESC
        LIMIT 1
      ) runs
    ) AS current_streak
  FROM users u
  ORDER BY u.total_points DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- 4. Tier distribution for a period
CREATE OR REPLACE FUNCTION tier_distribution(
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE (
  tier TEXT,
  user_count BIGINT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    best.tier,
    COUNT(*)::BIGINT AS user_count
  FROM (
    SELECT DISTINCT ON (dr.user_id)
      dr.vanguard_tier AS tier
    FROM daily_records dr
    WHERE dr.date BETWEEN p_start_date AND p_end_date
    ORDER BY dr.user_id, dr.daily_points DESC
  ) best
  GROUP BY best.tier
  ORDER BY
    CASE best.tier
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
