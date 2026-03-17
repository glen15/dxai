-- 더미 유저 + 테스트 유저 삭제
-- daily_records는 ON DELETE CASCADE로 자동 삭제
DELETE FROM users WHERE device_uuid LIKE 'dummy-%';
DELETE FROM users WHERE nickname = 'testverify';
