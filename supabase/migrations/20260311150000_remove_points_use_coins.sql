-- 포인트 제거: daily_points, total_points 컬럼 삭제
-- 코인이 직접 tier/division에서 계산됨 (포인트 중간 단계 제거)

-- 1. 의존 RPC 함수 삭제
DROP FUNCTION IF EXISTS leaderboard_period(DATE, DATE, INT, INT);
DROP FUNCTION IF EXISTS leaderboard_weekly_enhanced(DATE, DATE, INT, INT);
DROP FUNCTION IF EXISTS leaderboard_monthly_enhanced(DATE, DATE, INT, INT);
DROP FUNCTION IF EXISTS leaderboard_total_enhanced(INT, INT);
DROP FUNCTION IF EXISTS leaderboard_daily_by_tokens(DATE, INT, INT);
DROP FUNCTION IF EXISTS leaderboard_by_tokens(INT, INT);
DROP FUNCTION IF EXISTS search_users(TEXT, INT);

-- 2. 컬럼 삭제
ALTER TABLE daily_records DROP COLUMN IF EXISTS daily_points;
ALTER TABLE users DROP COLUMN IF EXISTS total_points;

-- 3. 필요한 함수 재생성 (코인 기반)

-- 라이브/데일리 리더보드: 토큰 합계 기준 정렬
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
  codex_tokens BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.nickname,
    dr.daily_coins,
    dr.vanguard_tier,
    dr.vanguard_division,
    dr.claude_tokens,
    dr.codex_tokens
  FROM daily_records dr
  JOIN users u ON u.id = dr.user_id
  WHERE dr.date = p_date
  ORDER BY (dr.claude_tokens + dr.codex_tokens) DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- 글로벌 토큰 랭킹
CREATE OR REPLACE FUNCTION leaderboard_by_tokens(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  nickname TEXT,
  total_tokens BIGINT,
  total_claude_tokens BIGINT,
  total_codex_tokens BIGINT,
  total_coins INT,
  last_tier TEXT,
  last_division INT,
  total_days_active BIGINT,
  member_since TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.nickname,
    COALESCE(SUM(dr.claude_tokens + dr.codex_tokens), 0)::BIGINT AS total_tokens,
    COALESCE(SUM(dr.claude_tokens), 0)::BIGINT AS total_claude_tokens,
    COALESCE(SUM(dr.codex_tokens), 0)::BIGINT AS total_codex_tokens,
    u.total_coins,
    u.last_tier,
    u.last_division,
    COUNT(dr.id)::BIGINT AS total_days_active,
    u.created_at AS member_since
  FROM users u
  LEFT JOIN daily_records dr ON dr.user_id = u.id
  GROUP BY u.id, u.nickname, u.total_coins, u.last_tier, u.last_division, u.created_at
  ORDER BY total_tokens DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- 유저 검색
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
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.nickname,
    u.total_coins,
    u.last_tier,
    u.last_division,
    COALESCE(SUM(dr.claude_tokens + dr.codex_tokens), 0)::BIGINT AS total_tokens,
    COUNT(dr.id)::BIGINT AS total_days_active,
    u.created_at AS member_since
  FROM users u
  LEFT JOIN daily_records dr ON dr.user_id = u.id
  WHERE u.nickname ILIKE '%' || p_query || '%'
  GROUP BY u.id, u.nickname, u.total_coins, u.last_tier, u.last_division, u.created_at
  ORDER BY total_tokens DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
