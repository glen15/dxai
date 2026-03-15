-- leaderboard_daily_by_tokens에 누적 토큰 추가 (레벨은 항상 누적 기준)
DROP FUNCTION IF EXISTS leaderboard_daily_by_tokens(DATE, INT, INT);

CREATE OR REPLACE FUNCTION leaderboard_daily_by_tokens(
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
  total_tokens BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.nickname,
    dr.daily_coins,
    dr.vanguard_tier,
    dr.vanguard_division,
    dr.claude_tokens,
    dr.codex_tokens,
    COALESCE((
      SELECT SUM(dr2.claude_tokens + dr2.codex_tokens)
      FROM daily_records dr2
      WHERE dr2.user_id = dr.user_id
    ), 0)::BIGINT AS total_tokens
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date = p_date
  ORDER BY (dr.claude_tokens + dr.codex_tokens) DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
