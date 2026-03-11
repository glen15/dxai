-- Token-based global ranking + user search

-- 1. 토큰 기반 글로벌 랭킹 (기존 total_points 대신 총 토큰 사용량 기준)
CREATE OR REPLACE FUNCTION leaderboard_by_tokens(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  total_tokens BIGINT,
  total_claude_tokens BIGINT,
  total_codex_tokens BIGINT,
  total_points INT,
  last_tier TEXT,
  last_division INT,
  total_days_active BIGINT,
  member_since DATE
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    COALESCE(agg.total_tokens, 0)::BIGINT AS total_tokens,
    COALESCE(agg.claude_tokens, 0)::BIGINT AS total_claude_tokens,
    COALESCE(agg.codex_tokens, 0)::BIGINT AS total_codex_tokens,
    u.total_points,
    u.last_tier,
    u.last_division,
    COALESCE(agg.days_active, 0)::BIGINT AS total_days_active,
    u.created_at::DATE AS member_since
  FROM users u
  LEFT JOIN (
    SELECT
      user_id,
      SUM(claude_tokens + codex_tokens) AS total_tokens,
      SUM(claude_tokens) AS claude_tokens,
      SUM(codex_tokens) AS codex_tokens,
      COUNT(DISTINCT date) AS days_active
    FROM daily_records
    GROUP BY user_id
  ) agg ON agg.user_id = u.id
  ORDER BY total_tokens DESC NULLS LAST
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- 2. 유저 닉네임 검색
CREATE OR REPLACE FUNCTION search_users(
  p_query TEXT,
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  nickname TEXT,
  total_points INT,
  last_tier TEXT,
  last_division INT,
  total_tokens BIGINT,
  total_days_active BIGINT,
  member_since DATE
)
LANGUAGE sql STABLE
AS $$
  SELECT
    u.nickname,
    u.total_points,
    u.last_tier,
    u.last_division,
    COALESCE(agg.total_tokens, 0)::BIGINT AS total_tokens,
    COALESCE(agg.days_active, 0)::BIGINT AS total_days_active,
    u.created_at::DATE AS member_since
  FROM users u
  LEFT JOIN (
    SELECT
      user_id,
      SUM(claude_tokens + codex_tokens) AS total_tokens,
      COUNT(DISTINCT date) AS days_active
    FROM daily_records
    GROUP BY user_id
  ) agg ON agg.user_id = u.id
  WHERE u.nickname ILIKE '%' || p_query || '%'
  ORDER BY COALESCE(agg.total_tokens, 0) DESC
  LIMIT p_limit;
$$;
