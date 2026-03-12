-- 더미 유저 20명 시드 (오늘 날짜 기준)
-- 닉네임: 한/영 혼합, 다양한 티어 분포
-- today's tier ≠ account level (total_coins로 누적 이력 반영)

DO $$
DECLARE
  _today DATE := (NOW() AT TIME ZONE 'Asia/Seoul')::DATE;
  _uid UUID;
BEGIN

  -- 1. 클로드장인 — Master 2, 오랜 유저
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-01', '클로드장인', 14200, 'Master', 2) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 1440, 428000000, 95000000, 'Master', 2);

  -- 2. TokenKing — Diamond 1
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-02', 'TokenKing', 8900, 'Diamond', 1) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 630, 365000000, 132000000, 'Diamond', 1);

  -- 3. 새벽코딩 — Diamond 3
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-03', '새벽코딩', 6800, 'Diamond', 3) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 490, 287000000, 48000000, 'Diamond', 3);

  -- 4. NeuralNomad — Platinum 1
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-04', 'NeuralNomad', 5200, 'Platinum', 1) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 270, 195000000, 72000000, 'Platinum', 1);

  -- 5. 프롬프트요리사 — Platinum 2
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-05', '프롬프트요리사', 4100, 'Platinum', 2) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 240, 178000000, 41000000, 'Platinum', 2);

  -- 6. ByteHunter — Platinum 3
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-06', 'ByteHunter', 3500, 'Platinum', 3) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 210, 152000000, 58000000, 'Platinum', 3);

  -- 7. 야근의신 — Gold 1, 꾸준한 유저
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-07', '야근의신', 2900, 'Gold', 1) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 108, 98000000, 22000000, 'Gold', 1);

  -- 8. CodexRider — Gold 2, Codex 위주
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-08', 'CodexRider', 2300, 'Gold', 2) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 96, 35000000, 78000000, 'Gold', 2);

  -- 9. 토큰부자 — Gold 3
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-09', '토큰부자', 1800, 'Gold', 3) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 84, 72000000, 18000000, 'Gold', 3);

  -- 10. SilentCoder — Gold 4
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-10', 'SilentCoder', 1400, 'Gold', 4) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 72, 58000000, 12000000, 'Gold', 4);

  -- 11. 맥북전사 — Gold 5
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-11', '맥북전사', 1100, 'Gold', 5) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 60, 45000000, 9500000, 'Gold', 5);

  -- 12. QuantumLeap — Silver 1
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-12', 'QuantumLeap', 850, 'Silver', 1) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 45, 32000000, 7500000, 'Silver', 1);

  -- 13. 에러사냥꾼 — Silver 2
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-13', '에러사냥꾼', 620, 'Silver', 2) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 40, 25000000, 6000000, 'Silver', 2);

  -- 14. DawnDev — Silver 3
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-14', 'DawnDev', 480, 'Silver', 3) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 35, 18000000, 4200000, 'Silver', 3);

  -- 15. 커피머신 — Silver 4
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-15', '커피머신', 320, 'Silver', 4) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 30, 14000000, 3000000, 'Silver', 4);

  -- 16. StackPilot — Silver 5
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-16', 'StackPilot', 220, 'Silver', 5) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 25, 10000000, 2500000, 'Silver', 5);

  -- 17. 깃마스터 — Bronze 1
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-17', '깃마스터', 150, 'Bronze', 1) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 18, 6500000, 1800000, 'Bronze', 1);

  -- 18. NightOwlAI — Bronze 2
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-18', 'NightOwlAI', 95, 'Bronze', 2) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 16, 4200000, 1200000, 'Bronze', 2);

  -- 19. 삽질왕 — Bronze 3
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-19', '삽질왕', 55, 'Bronze', 3) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 14, 2800000, 700000, 'Bronze', 3);

  -- 20. ZeroBugLife — Bronze 4
  INSERT INTO users (device_uuid, nickname, total_coins, last_tier, last_division)
  VALUES ('dummy-20', 'ZeroBugLife', 30, 'Bronze', 4) RETURNING id INTO _uid;
  INSERT INTO daily_records (user_id, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
  VALUES (_uid, _today, 12, 1500000, 400000, 'Bronze', 4);

END $$;
