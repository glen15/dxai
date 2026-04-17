import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const COIN_TABLE: Record<string, { base: number; bonus: number }> = {
  Bronze:      { base: 10,   bonus: 2 },
  Silver:      { base: 25,   bonus: 5 },
  Gold:        { base: 60,   bonus: 12 },
  Platinum:    { base: 150,  bonus: 30 },
  Diamond:     { base: 350,  bonus: 70 },
  Master:      { base: 800,  bonus: 160 },
  Grandmaster: { base: 1800, bonus: 360 },
};

const VALID_TIERS = [...Object.keys(COIN_TABLE), "Challenger"];
const CHALLENGER_COINS = 5000;
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_REQUESTS = 10;
const DAY_MS = 86_400_000;

function calculateCoins(tier: string, division: number | null): number {
  if (tier === "Challenger") return CHALLENGER_COINS;
  const entry = COIN_TABLE[tier];
  if (!entry || division === null || division < 1 || division > 5) return 0;
  return entry.base + entry.bonus * (5 - division);
}

// Simple in-memory rate limit (per device_uuid, resets on cold start)
const rateLimits = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(deviceUUID: string): boolean {
  const now = Date.now();
  const entry = rateLimits.get(deviceUUID);
  if (!entry || now > entry.resetAt) {
    rateLimits.set(deviceUUID, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return true;
  }
  entry.count++;
  return entry.count <= RATE_LIMIT_MAX_REQUESTS;
}

const ALLOWED_ORIGINS = new Set([
  "https://vanguard.dx-ai.cloud",
  "http://localhost:3000",
]);

function getCorsOrigin(req: Request): string {
  const origin = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.has(origin) ? origin : "";
}

serve(async (req: Request) => {
  const corsOrigin = getCorsOrigin(req);
  const respond = (data: any, status = 200) => json(data, status, corsOrigin);

  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": corsOrigin,
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-API-Key",
      },
    });
  }

  if (req.method !== "POST") {
    return respond({ ok: false, error: "method_not_allowed" }, 405);
  }

  // #5: API key 검증
  const apiKey = req.headers.get("x-api-key") ?? "";
  const expectedKey = Deno.env.get("SUBMIT_API_KEY") ?? "";
  if (!expectedKey || apiKey !== expectedKey) {
    return respond({ ok: false, error: "unauthorized" }, 401);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return respond({ ok: false, error: "invalid_json" }, 400);
  }

  const {
    device_uuid,
    nickname,
    date,
    daily_coins: clientCoins,
    // backward compat: accept daily_points from old app versions
    daily_points: legacyPoints,
    claude_tokens,
    codex_tokens,
    vanguard_tier,
    vanguard_division,
    secret_token: clientSecretToken,
  } = body;

  // Use daily_coins if present, fall back to daily_points for old clients
  const daily_coins = clientCoins ?? legacyPoints;

  // --- Validation ---

  if (!device_uuid || typeof device_uuid !== "string") {
    return respond({ ok: false, error: "invalid_device_uuid" }, 400);
  }

  if (!nickname || !/^[a-zA-Z0-9_]{2,16}$/.test(nickname)) {
    return respond({ ok: false, error: "invalid_nickname" }, 400);
  }

  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return respond({ ok: false, error: "invalid_date" }, 400);
  }

  // Reject future dates or dates older than 30 days
  const submittedDate = new Date(date + "T00:00:00Z");
  const now = new Date();
  const daysDiff = (now.getTime() - submittedDate.getTime()) / DAY_MS;
  if (daysDiff < -1 || daysDiff > 30) {
    return respond({ ok: false, error: "date_out_of_range" }, 400);
  }

  if (typeof daily_coins !== "number" || daily_coins < 0 || daily_coins > CHALLENGER_COINS) {
    return respond({ ok: false, error: "invalid_daily_coins" }, 400);
  }

  if (!VALID_TIERS.includes(vanguard_tier)) {
    return respond({ ok: false, error: "invalid_tier" }, 400);
  }

  if (vanguard_tier !== "Challenger") {
    if (typeof vanguard_division !== "number" || vanguard_division < 1 || vanguard_division > 5) {
      return respond({ ok: false, error: "invalid_division" }, 400);
    }
  }

  // Coins-tier matching verification
  const expectedCoins = calculateCoins(vanguard_tier, vanguard_division ?? null);
  if (daily_coins !== expectedCoins) {
    return respond({ ok: false, error: "coins_mismatch" }, 400);
  }

  if (typeof claude_tokens !== "number" || claude_tokens < 0) {
    return respond({ ok: false, error: "invalid_claude_tokens" }, 400);
  }
  if (typeof codex_tokens !== "number" || codex_tokens < 0) {
    return respond({ ok: false, error: "invalid_codex_tokens" }, 400);
  }

  // Rate limit
  if (!checkRateLimit(device_uuid)) {
    return respond({ ok: false, error: "rate_limited" }, 429);
  }

  // --- DB Operations ---

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Upsert user
  const { data: existingUser } = await supabase
    .from("users")
    .select("id, nickname, secret_token, created_at")
    .eq("device_uuid", device_uuid)
    .single();

  let userId: string;
  let secretToken: string | null = null;

  if (existingUser) {
    userId = existingUser.id;
    secretToken = existingUser.secret_token;

    // secret_token 검증 (클라이언트가 토큰을 보낸 경우에만, 구버전 호환)
    if (clientSecretToken && clientSecretToken !== existingUser.secret_token) {
      return respond({ ok: false, error: "invalid_secret_token" }, 403);
    }

    if (existingUser.nickname !== nickname) {
      const { error: nickErr } = await supabase
        .from("users")
        .update({ nickname, last_tier: vanguard_tier, last_division: vanguard_division, updated_at: new Date().toISOString() })
        .eq("id", userId);
      if (nickErr?.code === "23505") {
        return respond({ ok: false, error: "nickname_taken" }, 409);
      }
    } else {
      await supabase
        .from("users")
        .update({ last_tier: vanguard_tier, last_division: vanguard_division, updated_at: new Date().toISOString() })
        .eq("id", userId);
    }
  } else {
    const { data: newUser, error: insertErr } = await supabase
      .from("users")
      .insert({ device_uuid, nickname, last_tier: vanguard_tier, last_division: vanguard_division })
      .select("id, secret_token")
      .single();
    if (insertErr?.code === "23505") {
      return respond({ ok: false, error: "nickname_taken" }, 409);
    }
    if (insertErr || !newUser) {
      return respond({ ok: false, error: "user_creation_failed" }, 500);
    }
    userId = newUser.id;
    secretToken = newUser.secret_token;
  }

  // Upsert daily record (only update if higher coins or changed tokens)
  const { data: existingRecord } = await supabase
    .from("daily_records")
    .select("id, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division")
    .eq("user_id", userId)
    .eq("date", date)
    .single();

  if (existingRecord) {
    const shouldUpdate =
      daily_coins > existingRecord.daily_coins ||
      claude_tokens !== existingRecord.claude_tokens ||
      codex_tokens !== existingRecord.codex_tokens;
    if (shouldUpdate) {
      const newCoins = Math.max(daily_coins, existingRecord.daily_coins);
      await supabase
        .from("daily_records")
        .update({
          daily_coins: newCoins,
          claude_tokens,
          codex_tokens,
          vanguard_tier: daily_coins >= existingRecord.daily_coins ? vanguard_tier : existingRecord.vanguard_tier,
          vanguard_division: daily_coins >= existingRecord.daily_coins ? vanguard_division : existingRecord.vanguard_division,
        })
        .eq("id", existingRecord.id);
    }
  } else {
    // 전일 토큰값과 완전히 동일하면 자정 경계 버그 의심 → reject
    // (앱이 새 date 첫 submit에서 전일 누적값을 그대로 올리는 케이스 방어)
    const prevDateObj = new Date(date + "T00:00:00Z");
    prevDateObj.setUTCDate(prevDateObj.getUTCDate() - 1);
    const prevDateStr = prevDateObj.toISOString().slice(0, 10);
    const { data: prevRecord } = await supabase
      .from("daily_records")
      .select("claude_tokens, codex_tokens")
      .eq("user_id", userId)
      .eq("date", prevDateStr)
      .single();
    if (
      prevRecord &&
      (claude_tokens + codex_tokens) > 0 &&
      prevRecord.claude_tokens === claude_tokens &&
      prevRecord.codex_tokens === codex_tokens
    ) {
      return respond({ ok: false, error: "duplicate_of_previous_day" }, 400);
    }

    await supabase
      .from("daily_records")
      .insert({
        user_id: userId,
        date,
        daily_coins,
        claude_tokens,
        codex_tokens,
        vanguard_tier,
        vanguard_division,
      });
  }

  // Recalculate total_coins and total_tokens from daily_records
  const { data: sums } = await supabase
    .from("daily_records")
    .select("daily_coins, claude_tokens, codex_tokens")
    .eq("user_id", userId);

  const totalCoins = sums?.reduce((s: any, r: any) => s + r.daily_coins, 0) ?? 0;
  const totalTokens = sums?.reduce(
    (s: any, r: any) => s + (r.claude_tokens ?? 0) + (r.codex_tokens ?? 0), 0
  ) ?? 0;

  await supabase
    .from("users")
    .update({ total_coins: totalCoins })
    .eq("id", userId);

  // Get rank (by total_coins)
  const { count } = await supabase
    .from("users")
    .select("id", { count: "exact", head: true })
    .gt("total_coins", totalCoins);

  const rank = (count ?? 0) + 1;

  // Live rank: 오늘 토큰 기준 순위
  const todayTotalTokens = claude_tokens + codex_tokens;
  const { data: todayRecords } = await supabase
    .from("daily_records")
    .select("claude_tokens, codex_tokens")
    .eq("date", date);

  const liveRank = (todayRecords ?? []).filter(
    (r: any) => (r.claude_tokens + r.codex_tokens) > todayTotalTokens
  ).length + 1;

  // ── Achievement judgment ──
  const newAchievements = await judgeAchievements(supabase, userId, {
    totalTokens,
    totalCoins,
    vanguard_tier,
    claude_tokens,
    codex_tokens,
    date,
    rank,
    createdAt: existingUser?.created_at,
  });

  return respond({
    ok: true,
    total_coins: totalCoins,
    total_tokens: totalTokens,
    rank,
    live_rank: liveRank,
    secret_token: secretToken,
    ...(newAchievements.length > 0 ? { new_achievements: newAchievements } : {}),
  });
});

// ── Achievement definitions ──

const TOKEN_THRESHOLDS = [
  { id: "token_first", min: 1 },
  { id: "token_100k", min: 100_000 },
  { id: "token_1m", min: 1_000_000 },
  { id: "token_10m", min: 10_000_000 },
  { id: "token_50m", min: 50_000_000 },
  { id: "token_100m", min: 100_000_000 },
  { id: "token_500m", min: 500_000_000 },
  { id: "token_1b", min: 1_000_000_000 },
];

const TIER_ORDER = ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Master", "Grandmaster", "Challenger"];
const TIER_ACHIEVEMENTS: Record<string, string> = {
  Silver: "tier_silver",
  Gold: "tier_gold",
  Platinum: "tier_platinum",
  Diamond: "tier_diamond",
  Master: "tier_master",
  Grandmaster: "tier_grandmaster",
  Challenger: "tier_challenger",
};

const STREAK_THRESHOLDS = [
  { id: "streak_3", min: 3 },
  { id: "streak_7", min: 7 },
  { id: "streak_14", min: 14 },
  { id: "streak_30", min: 30 },
  { id: "streak_60", min: 60 },
  { id: "streak_100", min: 100 },
];

const DAYS_THRESHOLDS = [
  { id: "days_7", min: 7 },
  { id: "days_30", min: 30 },
  { id: "days_60", min: 60 },
  { id: "days_100", min: 100 },
  { id: "days_365", min: 365 },
];

const COINS_THRESHOLDS = [
  { id: "coins_1k", min: 1_000 },
  { id: "coins_10k", min: 10_000 },
  { id: "coins_50k", min: 50_000 },
  { id: "coins_100k", min: 100_000 },
  { id: "coins_500k", min: 500_000 },
];

interface JudgeContext {
  totalTokens: number;
  totalCoins: number;
  vanguard_tier: string;
  claude_tokens: number;
  codex_tokens: number;
  date: string;
  rank: number;
  createdAt?: string;
}

async function judgeAchievements(
  supabase: any,
  userId: string,
  ctx: JudgeContext,
): Promise<Array<{ id: string; name_ko: string; name_en: string; icon: string; rarity: string }>> {
  // 1. 기존 업적 조회
  const { data: existing } = await supabase
    .from("user_achievements")
    .select("achievement_id")
    .eq("user_id", userId);

  const earned = new Set((existing ?? []).map((r: any) => r.achievement_id));
  const candidates: string[] = [];

  // 2. Token 업적
  for (const t of TOKEN_THRESHOLDS) {
    if (!earned.has(t.id) && ctx.totalTokens >= t.min) candidates.push(t.id);
  }

  // 3. Tier 업적 (현재 티어 이하 모두 부여)
  const tierIdx = TIER_ORDER.indexOf(ctx.vanguard_tier);
  for (let i = 1; i <= tierIdx; i++) {
    const achId = TIER_ACHIEVEMENTS[TIER_ORDER[i]];
    if (achId && !earned.has(achId)) candidates.push(achId);
  }

  // 4. Days 업적 (총 활동일)
  const { count: daysActive } = await supabase
    .from("daily_records")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId);

  for (const d of DAYS_THRESHOLDS) {
    if (!earned.has(d.id) && (daysActive ?? 0) >= d.min) candidates.push(d.id);
  }

  // 5. Streak 업적 (연속 활동일)
  const { data: recentDates } = await supabase
    .from("daily_records")
    .select("date")
    .eq("user_id", userId)
    .order("date", { ascending: false })
    .limit(110);

  const streak = calcStreak(recentDates ?? []);
  for (const s of STREAK_THRESHOLDS) {
    if (!earned.has(s.id) && streak >= s.min) candidates.push(s.id);
  }

  // 6. Coins 업적
  for (const c of COINS_THRESHOLDS) {
    if (!earned.has(c.id) && ctx.totalCoins >= c.min) candidates.push(c.id);
  }

  // 7. Special 업적
  if (!earned.has("dual_wielder") && ctx.claude_tokens > 0 && ctx.codex_tokens > 0) {
    candidates.push("dual_wielder");
  }

  const submittedDate = new Date(ctx.date + "T00:00:00Z");
  const dow = submittedDate.getUTCDay();
  if (!earned.has("weekend_warrior") && (dow === 0 || dow === 6)) {
    candidates.push("weekend_warrior");
  }

  if (!earned.has("early_adopter") && ctx.createdAt) {
    const created = new Date(ctx.createdAt);
    if (created.getUTCFullYear() === 2026 && created.getUTCMonth() === 2) {
      candidates.push("early_adopter");
    }
  }

  if (!earned.has("perfectionist") && ctx.vanguard_tier === "Challenger") {
    candidates.push("perfectionist");
  }

  if (!earned.has("top_ranker") && ctx.rank <= 3) {
    candidates.push("top_ranker");
  }

  if (candidates.length === 0) return [];

  // 8. 새 업적 삽입 (ON CONFLICT DO NOTHING)
  const rows = candidates.map((id) => ({
    user_id: userId,
    achievement_id: id,
  }));

  await supabase
    .from("user_achievements")
    .upsert(rows, { onConflict: "user_id,achievement_id", ignoreDuplicates: true });

  // 9. 새 업적 메타데이터 반환
  const { data: meta } = await supabase
    .from("achievements")
    .select("id, name_ko, name_en, icon, rarity")
    .in("id", candidates);

  return (meta ?? []).map((a: any) => ({
    id: a.id,
    name_ko: a.name_ko,
    name_en: a.name_en,
    icon: a.icon,
    rarity: a.rarity,
  }));
}

function calcStreak(records: Array<{ date: string }>): number {
  if (records.length === 0) return 0;
  const sorted = [...records].sort((a, b) => b.date.localeCompare(a.date));

  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const today = kst.toISOString().slice(0, 10);
  let streak = 0;
  let expected = today;

  for (const r of sorted) {
    if (r.date === expected) {
      streak++;
      const d = new Date(expected + "T00:00:00Z");
      d.setDate(d.getDate() - 1);
      expected = d.toISOString().slice(0, 10);
    } else if (streak === 0) {
      // 오늘 기록이 없으면 어제부터 시작
      const yesterday = new Date(today + "T00:00:00Z");
      yesterday.setDate(yesterday.getDate() - 1);
      const yStr = yesterday.toISOString().slice(0, 10);
      if (r.date === yStr) {
        streak = 1;
        const d = new Date(yStr + "T00:00:00Z");
        d.setDate(d.getDate() - 1);
        expected = d.toISOString().slice(0, 10);
      } else {
        break;
      }
    } else {
      break;
    }
  }
  return streak;
}

function json(data: any, status = 200, origin = "") {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...(origin ? { "Access-Control-Allow-Origin": origin } : {}),
    },
  });
}
