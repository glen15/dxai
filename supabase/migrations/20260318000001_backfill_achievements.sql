-- Phase 4: 기존 데이터로 업적 소급 부여 (backfill)
-- 이미 달성 조건을 충족한 유저에게 업적을 자동 부여

-- ── Token 업적: 누적 토큰 기준 ──

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_first', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) > 0
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_100k', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) >= 100000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_1m', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) >= 1000000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_10m', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) >= 10000000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_50m', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) >= 50000000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_100m', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) >= 100000000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_500m', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) >= 500000000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT u.id, 'token_1b', u.created_at
FROM users u
JOIN daily_records dr ON dr.user_id = u.id
GROUP BY u.id, u.created_at
HAVING SUM(dr.claude_tokens + dr.codex_tokens) >= 1000000000
ON CONFLICT DO NOTHING;

-- ── Tier 업적: daily_records에 해당 티어 기록이 있으면 부여 ──

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'tier_silver', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier IN ('Silver', 'Gold', 'Platinum', 'Diamond', 'Master', 'Grandmaster', 'Challenger')
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'tier_gold', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier IN ('Gold', 'Platinum', 'Diamond', 'Master', 'Grandmaster', 'Challenger')
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'tier_platinum', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier IN ('Platinum', 'Diamond', 'Master', 'Grandmaster', 'Challenger')
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'tier_diamond', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier IN ('Diamond', 'Master', 'Grandmaster', 'Challenger')
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'tier_master', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier IN ('Master', 'Grandmaster', 'Challenger')
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'tier_grandmaster', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier IN ('Grandmaster', 'Challenger')
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'tier_challenger', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier = 'Challenger'
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

-- ── Days 업적: 총 활동일 수 기준 ──

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT dr.user_id, 'days_7', now()
FROM daily_records dr
GROUP BY dr.user_id
HAVING COUNT(DISTINCT dr.date) >= 7
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT dr.user_id, 'days_30', now()
FROM daily_records dr
GROUP BY dr.user_id
HAVING COUNT(DISTINCT dr.date) >= 30
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT dr.user_id, 'days_60', now()
FROM daily_records dr
GROUP BY dr.user_id
HAVING COUNT(DISTINCT dr.date) >= 60
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT dr.user_id, 'days_100', now()
FROM daily_records dr
GROUP BY dr.user_id
HAVING COUNT(DISTINCT dr.date) >= 100
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT dr.user_id, 'days_365', now()
FROM daily_records dr
GROUP BY dr.user_id
HAVING COUNT(DISTINCT dr.date) >= 365
ON CONFLICT DO NOTHING;

-- ── Coins 업적: 누적 코인 기준 ──

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT id, 'coins_1k', now()
FROM users WHERE total_coins >= 1000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT id, 'coins_10k', now()
FROM users WHERE total_coins >= 10000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT id, 'coins_50k', now()
FROM users WHERE total_coins >= 50000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT id, 'coins_100k', now()
FROM users WHERE total_coins >= 100000
ON CONFLICT DO NOTHING;

INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT id, 'coins_500k', now()
FROM users WHERE total_coins >= 500000
ON CONFLICT DO NOTHING;

-- ── Special 업적 ──

-- Early Adopter: 2026년 3월 가입
INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT id, 'early_adopter', created_at
FROM users
WHERE created_at >= '2026-03-01'::timestamptz
  AND created_at < '2026-04-01'::timestamptz
ON CONFLICT DO NOTHING;

-- Dual Wielder: Claude + Codex 동시 사용일
INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'dual_wielder', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.claude_tokens > 0 AND dr.codex_tokens > 0
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

-- Weekend Warrior: 주말 활동
INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'weekend_warrior', MIN(dr.created_at)
FROM daily_records dr
WHERE EXTRACT(DOW FROM dr.date) IN (0, 6)  -- 0=Sunday, 6=Saturday
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

-- Perfectionist: Challenger 달성 (tier_challenger와 동일 조건이지만 Special 카테고리)
INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT DISTINCT dr.user_id, 'perfectionist', MIN(dr.created_at)
FROM daily_records dr
WHERE dr.vanguard_tier = 'Challenger'
GROUP BY dr.user_id
ON CONFLICT DO NOTHING;

-- Top Ranker: 현재 Top 3 (전체 토큰 기준)
INSERT INTO user_achievements (user_id, achievement_id, achieved_at)
SELECT sub.user_id, 'top_ranker', now()
FROM (
  SELECT u.id AS user_id,
         RANK() OVER (ORDER BY COALESCE(SUM(dr.claude_tokens + dr.codex_tokens), 0) DESC) AS rnk
  FROM users u
  LEFT JOIN daily_records dr ON dr.user_id = u.id
  GROUP BY u.id
) sub
WHERE sub.rnk <= 3
ON CONFLICT DO NOTHING;

-- ── Streak 업적은 backfill 생략 (연속일 계산이 복잡하고, submit-daily에서 실시간 판정) ──
-- streak 업적은 앞으로의 submit-daily 호출 시 실시간으로 판정됩니다.
