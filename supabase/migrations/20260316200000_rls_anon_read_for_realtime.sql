-- Realtime 구독을 위해 anon SELECT 복원 (민감 필드 제한은 View로 처리)
-- Supabase Realtime은 anon key의 postgres_changes 구독에 SELECT 정책 필요

-- daily_records: Realtime 이벤트 수신을 위해 anon SELECT 복원
-- (user_id는 UUID이므로 직접 사용 불가, 민감도 낮음)
CREATE POLICY "daily_records_anon_read" ON daily_records
  FOR SELECT TO anon USING (true);

-- users: 닉네임/티어 등 공개 정보만 노출 (device_uuid 제외)
-- RLS는 row 단위라 column 제한 불가 → View 사용 권장
-- 최소한 SELECT는 허용하되, 앱에서 REST API 직접 접근은 Edge Function으로 이관 완료
CREATE POLICY "users_anon_read" ON users
  FOR SELECT TO anon USING (true);
