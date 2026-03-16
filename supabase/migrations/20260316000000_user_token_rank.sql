-- 개인 프로필에서 토큰 기반 순위를 효율적으로 계산하는 RPC
-- 기존: 1000행 전체 조회 후 findIndex → 비효율적
-- 변경: RANK() OVER 윈도우 함수로 DB에서 직접 계산

CREATE OR REPLACE FUNCTION user_token_rank(p_nickname TEXT)
RETURNS TABLE (rank BIGINT, total_tokens BIGINT)
LANGUAGE sql STABLE
AS $$
  WITH ranked AS (
    SELECT
      u.nickname,
      COALESCE(SUM(dr.claude_tokens + dr.codex_tokens), 0) AS total_tokens,
      RANK() OVER (ORDER BY COALESCE(SUM(dr.claude_tokens + dr.codex_tokens), 0) DESC) AS rank
    FROM users u
    LEFT JOIN daily_records dr ON dr.user_id = u.id
    GROUP BY u.id, u.nickname
  )
  SELECT ranked.rank, ranked.total_tokens
  FROM ranked
  WHERE ranked.nickname = p_nickname;
$$;
