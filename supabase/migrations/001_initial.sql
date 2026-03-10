-- DXAI Ranking Service - Initial Schema

-- users: 사용자 프로필 (device별 유니크)
CREATE TABLE users (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  device_uuid   TEXT NOT NULL UNIQUE,
  nickname      TEXT NOT NULL UNIQUE,
  total_points  INT NOT NULL DEFAULT 0,
  total_coins   INT NOT NULL DEFAULT 0,
  last_tier     TEXT,
  last_division INT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_users_nickname ON users(nickname);
CREATE INDEX idx_users_total_points ON users(total_points DESC);

-- daily_records: 일일 포인트/코인 기록
CREATE TABLE daily_records (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date             DATE NOT NULL,
  daily_points     INT NOT NULL CHECK (daily_points >= 0 AND daily_points <= 5000),
  daily_coins      INT NOT NULL CHECK (daily_coins >= 0 AND daily_coins <= 5000),
  claude_tokens    BIGINT NOT NULL DEFAULT 0,
  codex_tokens     BIGINT NOT NULL DEFAULT 0,
  pioneer_tier     TEXT NOT NULL,
  pioneer_division INT,
  created_at       TIMESTAMPTZ DEFAULT now(),

  UNIQUE(user_id, date)
);

CREATE INDEX idx_daily_records_date ON daily_records(date DESC);
CREATE INDEX idx_daily_records_user_date ON daily_records(user_id, date DESC);

-- RLS: anon = 읽기만, 쓰기는 service_role(Edge Function)만
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_public_read" ON users
  FOR SELECT TO anon USING (true);

CREATE POLICY "users_service_write" ON users
  FOR ALL TO service_role USING (true);

ALTER TABLE daily_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_records_public_read" ON daily_records
  FOR SELECT TO anon USING (true);

CREATE POLICY "daily_records_service_write" ON daily_records
  FOR ALL TO service_role USING (true);
