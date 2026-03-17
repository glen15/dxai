-- Critical: anon key로 users 테이블 직접 SELECT 시 secret_token/device_uuid 노출 방지
-- Realtime 구독은 daily_records만 사용하므로 users anon SELECT는 불필요

-- 기존 anon SELECT 정책 모두 제거
DROP POLICY IF EXISTS "users_public_read" ON users;
DROP POLICY IF EXISTS "users_anon_read" ON users;

-- secret_token 전체 로테이션 (기존 토큰이 노출되었을 가능성)
UPDATE users SET secret_token = gen_random_uuid();
