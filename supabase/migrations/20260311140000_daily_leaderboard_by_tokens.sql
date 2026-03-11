-- 라이브/데일리 리더보드: 토큰 합계 기준 정렬 (daily_points → tokens)
CREATE OR REPLACE FUNCTION leaderboard_daily_by_tokens(
  p_date DATE,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  daily_points INT,
  vanguard_tier TEXT,
  vanguard_division INT,
  claude_tokens BIGINT,
  codex_tokens BIGINT,
  total_points INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.nickname,
    dr.daily_points,
    dr.vanguard_tier,
    dr.vanguard_division,
    dr.claude_tokens,
    dr.codex_tokens,
    u.total_points
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date = p_date
  ORDER BY (dr.claude_tokens + dr.codex_tokens) DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
