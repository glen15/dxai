-- 코인 인증용 secret_token 추가
-- 향후 웹 게임 등 외부 서비스에서 코인 조회/소비 시 인증에 사용
ALTER TABLE users ADD COLUMN secret_token UUID DEFAULT gen_random_uuid();

-- 기존 유저에게도 토큰 부여
UPDATE users SET secret_token = gen_random_uuid() WHERE secret_token IS NULL;

-- NOT NULL 제약 추가
ALTER TABLE users ALTER COLUMN secret_token SET NOT NULL;

-- 토큰 검색용 인덱스
CREATE UNIQUE INDEX idx_users_secret_token ON users(secret_token);

-- anon에게 secret_token 노출 방지: anon SELECT 정책을 제한적으로 재구성
-- (현재 anon은 전체 row SELECT 가능 → secret_token도 읽힘)
-- RLS는 row 단위라 column 제한 불가 → View로 해결
CREATE OR REPLACE VIEW public_users AS
  SELECT id, nickname, total_coins, last_tier, last_division, created_at
  FROM users;

-- anon은 View만 접근하도록 (기존 테이블 직접 SELECT 정책은 Realtime용으로 유지)
GRANT SELECT ON public_users TO anon;
