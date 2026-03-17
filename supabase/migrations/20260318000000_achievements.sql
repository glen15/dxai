-- Phase 4: 업적/배지 시스템
-- achievements 정의 테이블 + user_achievements 관계 테이블 + RPC 함수 + 시드 데이터

-- ── 1. 업적 정의 테이블 ──

CREATE TABLE achievements (
  id          TEXT PRIMARY KEY,
  category    TEXT NOT NULL CHECK (category IN ('token', 'tier', 'streak', 'days', 'coins', 'special')),
  name_ko     TEXT NOT NULL,
  name_en     TEXT NOT NULL,
  desc_ko     TEXT NOT NULL,
  desc_en     TEXT NOT NULL,
  rarity      TEXT NOT NULL CHECK (rarity IN ('common', 'uncommon', 'rare', 'legendary')),
  icon        TEXT NOT NULL,
  sort_order  INT NOT NULL DEFAULT 0
);

-- ── 2. 유저-업적 관계 테이블 ──

CREATE TABLE user_achievements (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
  achieved_at    TIMESTAMPTZ DEFAULT now(),

  UNIQUE(user_id, achievement_id)
);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_achievement ON user_achievements(achievement_id);

-- ── 3. RLS ──

ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "achievements_public_read" ON achievements
  FOR SELECT TO anon USING (true);

CREATE POLICY "achievements_service_write" ON achievements
  FOR ALL TO service_role USING (true);

ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_achievements_public_read" ON user_achievements
  FOR SELECT TO anon USING (true);

CREATE POLICY "user_achievements_service_write" ON user_achievements
  FOR ALL TO service_role USING (true);

-- ── 4. 시드 데이터: 36개 업적 ──

INSERT INTO achievements (id, category, name_ko, name_en, desc_ko, desc_en, rarity, icon, sort_order) VALUES
-- Token (8)
('token_first',  'token', '첫 발걸음',       'First Steps',        '첫 토큰을 기록하다',           'Record your first token',           'common',    '👣', 100),
('token_100k',   'token', '10만 토큰',        '100K Tokens',        '누적 토큰 10만 돌파',          'Reach 100K total tokens',           'common',    '🔢', 101),
('token_1m',     'token', '토큰 밀리어네어',  'Token Millionaire',   '누적 토큰 100만 돌파',         'Reach 1M total tokens',             'common',    '💰', 102),
('token_10m',    'token', '천만 클럽',        '10M Club',            '누적 토큰 1000만 돌파',        'Reach 10M total tokens',            'uncommon',  '🏅', 103),
('token_50m',    'token', '오천만 돌파',      '50M Breakthrough',    '누적 토큰 5000만 돌파',        'Reach 50M total tokens',            'uncommon',  '🚀', 104),
('token_100m',   'token', '1억 토큰',         '100M Tokens',         '누적 토큰 1억 돌파',           'Reach 100M total tokens',           'rare',      '💎', 105),
('token_500m',   'token', '5억 토큰',         '500M Tokens',         '누적 토큰 5억 돌파',           'Reach 500M total tokens',           'rare',      '🌟', 106),
('token_1b',     'token', '10억의 벽',        'Billion Wall',        '누적 토큰 10억 돌파',          'Reach 1B total tokens',             'legendary', '👑', 107),

-- Tier (7)
('tier_silver',      'tier', 'Silver 진입',      'Silver Entry',       '일일 Silver 티어 달성',        'Reach Silver tier in a day',        'common',    '🥈', 200),
('tier_gold',        'tier', 'Gold 진입',        'Gold Entry',         '일일 Gold 티어 달성',          'Reach Gold tier in a day',          'common',    '🥇', 201),
('tier_platinum',    'tier', 'Platinum 진입',    'Platinum Entry',     '일일 Platinum 티어 달성',      'Reach Platinum tier in a day',      'uncommon',  '💠', 202),
('tier_diamond',     'tier', 'Diamond 진입',     'Diamond Entry',      '일일 Diamond 티어 달성',       'Reach Diamond tier in a day',       'uncommon',  '💎', 203),
('tier_master',      'tier', 'Master 진입',      'Master Entry',       '일일 Master 티어 달성',        'Reach Master tier in a day',        'rare',      '🔮', 204),
('tier_grandmaster', 'tier', 'Grandmaster 진입', 'Grandmaster Entry',  '일일 Grandmaster 티어 달성',   'Reach Grandmaster tier in a day',   'rare',      '⚡', 205),
('tier_challenger',  'tier', 'Challenger 진입',  'Challenger Entry',   '일일 Challenger 티어 달성',    'Reach Challenger tier in a day',    'legendary', '🏆', 206),

-- Streak (6)
('streak_3',   'streak', '3일 연속',     '3-Day Streak',    '3일 연속 활동',             '3 consecutive days of activity',     'common',    '🔥', 300),
('streak_7',   'streak', '7일 연속',     '7-Day Streak',    '7일 연속 활동',             '7 consecutive days of activity',     'common',    '🔥', 301),
('streak_14',  'streak', '2주 연속',     '14-Day Streak',   '14일 연속 활동',            '14 consecutive days of activity',    'uncommon',  '🔥', 302),
('streak_30',  'streak', '30일 연속',    '30-Day Streak',   '30일 연속 활동',            '30 consecutive days of activity',    'rare',      '🔥', 303),
('streak_60',  'streak', '60일 연속',    '60-Day Streak',   '60일 연속 활동',            '60 consecutive days of activity',    'rare',      '🔥', 304),
('streak_100', 'streak', '100일 연속',   '100-Day Streak',  '100일 연속 활동',           '100 consecutive days of activity',   'legendary', '🔥', 305),

-- Days (5)
('days_7',   'days', '1주차 선봉대',    'Week One Vanguard',  '총 7일 활동',              '7 total days of activity',           'common',    '📅', 400),
('days_30',  'days', '한 달의 여정',    'Month Journey',       '총 30일 활동',             '30 total days of activity',          'common',    '📅', 401),
('days_60',  'days', '60일 베테랑',     '60-Day Veteran',      '총 60일 활동',             '60 total days of activity',          'uncommon',  '📅', 402),
('days_100', 'days', '100일 마스터',    '100-Day Master',      '총 100일 활동',            '100 total days of activity',         'rare',      '📅', 403),
('days_365', 'days', '365일 레전드',    '365-Day Legend',      '총 365일 활동',            '365 total days of activity',         'legendary', '📅', 404),

-- Coins (5)
('coins_1k',   'coins', '1천 코인',       '1K Coins',        '누적 코인 1,000 달성',      'Earn 1,000 total coins',             'common',    '🪙', 500),
('coins_10k',  'coins', '1만 코인',       '10K Coins',       '누적 코인 10,000 달성',     'Earn 10,000 total coins',            'uncommon',  '🪙', 501),
('coins_50k',  'coins', '5만 코인',       '50K Coins',       '누적 코인 50,000 달성',     'Earn 50,000 total coins',            'uncommon',  '🪙', 502),
('coins_100k', 'coins', '10만 코인',      '100K Coins',      '누적 코인 100,000 달성',    'Earn 100,000 total coins',           'rare',      '🪙', 503),
('coins_500k', 'coins', '50만 코인',      '500K Coins',      '누적 코인 500,000 달성',    'Earn 500,000 total coins',           'legendary', '🪙', 504),

-- Special (5)
('early_adopter',   'special', '얼리 어답터',    'Early Adopter',      '2026년 3월에 가입',             'Joined in March 2026',              'uncommon',  '🌱', 600),
('dual_wielder',    'special', '이도류',          'Dual Wielder',       'Claude + Codex를 같은 날 사용',  'Use both Claude and Codex in a day','common',    '⚔️', 601),
('weekend_warrior', 'special', '주말 전사',       'Weekend Warrior',    '주말에 활동 기록',              'Record activity on a weekend',      'common',    '🛡️', 602),
('perfectionist',   'special', '완벽주의자',      'Perfectionist',      '일일 Challenger 달성',          'Reach Challenger in a single day',  'legendary', '✨', 603),
('top_ranker',      'special', 'Top 3',           'Top 3',              '전체 랭킹 Top 3 진입',          'Reach Top 3 in global ranking',     'rare',      '🏅', 604);

-- ── 5. RPC: 유저 업적 조회 ──

CREATE OR REPLACE FUNCTION get_user_achievements(p_user_id UUID)
RETURNS TABLE (
  achievement_id TEXT,
  category       TEXT,
  name_ko        TEXT,
  name_en        TEXT,
  desc_ko        TEXT,
  desc_en        TEXT,
  rarity         TEXT,
  icon           TEXT,
  sort_order     INT,
  achieved_at    TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.category,
    a.name_ko,
    a.name_en,
    a.desc_ko,
    a.desc_en,
    a.rarity,
    a.icon,
    a.sort_order,
    ua.achieved_at
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  WHERE ua.user_id = p_user_id
  ORDER BY ua.achieved_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ── 6. RPC: 업적 통계 (전체 업적별 달성자 수) ──

CREATE OR REPLACE FUNCTION achievement_stats()
RETURNS TABLE (
  achievement_id TEXT,
  category       TEXT,
  name_ko        TEXT,
  name_en        TEXT,
  desc_ko        TEXT,
  desc_en        TEXT,
  rarity         TEXT,
  icon           TEXT,
  sort_order     INT,
  achieved_count BIGINT,
  total_users    BIGINT
) AS $$
DECLARE
  v_total BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_total FROM users;

  RETURN QUERY
  SELECT
    a.id,
    a.category,
    a.name_ko,
    a.name_en,
    a.desc_ko,
    a.desc_en,
    a.rarity,
    a.icon,
    a.sort_order,
    COUNT(ua.id)::BIGINT AS achieved_count,
    v_total AS total_users
  FROM achievements a
  LEFT JOIN user_achievements ua ON ua.achievement_id = a.id
  GROUP BY a.id, a.category, a.name_ko, a.name_en, a.desc_ko, a.desc_en, a.rarity, a.icon, a.sort_order
  ORDER BY a.sort_order;
END;
$$ LANGUAGE plpgsql;
