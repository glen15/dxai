-- 50 dummy users for UI testing (레벨 분포 테스트)
-- 삭제: DELETE FROM users WHERE device_uuid LIKE 'dummy-%';

DO $$
DECLARE
  v_uid UUID;
  v_names TEXT[] := ARRAY[
    'SkyRunner','CodeNinja','PixelWitch','DataDragon','NeonByte',
    'CloudSurfer','BitWizard','CyberFox','DevStorm','AlphaWolf',
    'ZeroDay','HashKing','StackOverflow','MetaNode','DeepMind',
    'QuantumBit','ByteForge','RustLord','TypeKing','NodeMaster',
    'GoCoder','PythonQueen','SwiftHero','KotlinAce','CarbonDev',
    'NeuralNet','TensorFlow','GPUKnight','CacheHit','MemLeak',
    'ServerPing','DockerWhale','K8sCaptain','GitRebase','BranchKing',
    'MergeConflict','HotFixer','LintMaster','CICDPro','TestPilot',
    'DebugHero','CompileKing','RefactorGod','APILord','WebSocket',
    'FirewallX','SSLGuard','DNSWizard','LoadBalancer','MicroSvc'
  ];
  v_tiers TEXT[] := ARRAY['Bronze','Bronze','Silver','Silver','Gold','Gold','Platinum','Platinum','Diamond','Diamond','Master','Challenger'];
  v_divs  INT[]  := ARRAY[5,3,4,2,3,1,3,1,3,1,2,1];
  -- Token ranges per "bucket" to create level spread
  v_token_min BIGINT[] := ARRAY[
    100000,200000,500000,800000,1200000,          -- Lv.1 (5 users)
    1500000,1700000,1900000,2200000,2500000,      -- Lv.2 (5 users)
    2800000,3200000,3500000,3800000,4500000,      -- Lv.3 (5 users)
    5000000,5500000,6500000,7000000,7800000,      -- Lv.4 (5 users)
    9000000,10000000,12000000,14000000,15500000,  -- Lv.5 (5 users)
    18000000,22000000,25000000,28000000,31000000, -- Lv.6 (5 users)
    35000000,40000000,45000000,52000000,60000000, -- Lv.7 (5 users)
    70000000,80000000,95000000,110000000,125000000, -- Lv.8 (5 users)
    140000000,180000000,220000000,                -- Lv.9 (3 users)
    280000000,350000000,450000000,                -- Lv.10 (3 users)
    600000000,800000000,                          -- Lv.11 (2 users)
    1200000000,2500000000                         -- Lv.12-13 (2 users)
  ];
  v_points INT;
  v_coins INT;
  v_tier TEXT;
  v_div INT;
  v_tokens BIGINT;
  v_claude BIGINT;
  v_codex BIGINT;
  v_days INT;
  v_d DATE;
  v_day_tokens BIGINT;
  v_day_claude BIGINT;
  v_day_codex BIGINT;
  v_tier_idx INT;
BEGIN
  FOR i IN 1..50 LOOP
    v_tokens := v_token_min[i];
    -- Assign tier based on token level
    v_tier_idx := LEAST(GREATEST(1, (i / 5) + 1), 12);
    v_tier := v_tiers[v_tier_idx];
    v_div := v_divs[v_tier_idx];
    v_claude := (v_tokens * 65 / 100); -- 65% Claude
    v_codex := v_tokens - v_claude;     -- 35% Codex
    v_days := GREATEST(1, LEAST(i, 30));
    v_points := (v_tokens / 100000)::INT;
    v_coins := (v_points * 40 / 100);

    INSERT INTO users (device_uuid, nickname, total_points, total_coins, last_tier, last_division)
    VALUES ('dummy-' || i, v_names[i], v_points, v_coins, v_tier, v_div)
    RETURNING id INTO v_uid;

    -- Create daily_records spread over last v_days days
    FOR d IN 1..v_days LOOP
      v_d := CURRENT_DATE - (v_days - d);
      v_day_tokens := v_tokens / v_days;
      v_day_claude := v_day_tokens * 65 / 100;
      v_day_codex := v_day_tokens - v_day_claude;

      INSERT INTO daily_records (user_id, date, daily_points, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division)
      VALUES (
        v_uid, v_d,
        LEAST(5000, (v_day_tokens / 100000)::INT + (d * 10)),
        LEAST(5000, (v_day_tokens / 200000)::INT + (d * 5)),
        v_day_claude + (d * 50000),
        v_day_codex + (d * 20000),
        v_tier, v_div
      );
    END LOOP;
  END LOOP;
END $$;
