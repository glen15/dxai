-- 자정 경계 버그로 전일 토큰값이 오늘 row로 복사된 케이스 탐지용 VIEW
-- 사용: SELECT * FROM suspicious_duplicates;
-- 조건: (user_id, date) row의 claude/codex tokens가 직전일과 정확히 동일하고 0이 아님

CREATE OR REPLACE VIEW suspicious_duplicates AS
SELECT
  u.nickname,
  t.user_id,
  t.date,
  t.claude_tokens,
  t.codex_tokens,
  t.daily_coins,
  t.vanguard_tier,
  t.vanguard_division,
  t.created_at
FROM daily_records t
JOIN daily_records y
  ON y.user_id = t.user_id
 AND y.date = (t.date - INTERVAL '1 day')::date
JOIN users u ON u.id = t.user_id
WHERE t.claude_tokens = y.claude_tokens
  AND t.codex_tokens = y.codex_tokens
  AND (t.claude_tokens + t.codex_tokens) > 0
ORDER BY t.date DESC, u.nickname;

COMMENT ON VIEW suspicious_duplicates IS
  '전일 토큰값과 정확히 동일한 daily_records row (자정 경계 버그 의심). submit-daily에서 reject하지만 배포 이전 생성 row를 사후 감시하기 위함.';
