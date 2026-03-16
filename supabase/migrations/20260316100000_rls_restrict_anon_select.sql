-- #6: anon의 직접 테이블 SELECT 접근 제거
-- Edge Functions (service_role)만 테이블에 직접 접근
-- 클라이언트는 Edge Function API를 통해서만 데이터 조회

-- 기존 anon SELECT 정책 제거
DROP POLICY IF EXISTS "users_public_read" ON users;
DROP POLICY IF EXISTS "daily_records_public_read" ON daily_records;
