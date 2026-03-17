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

  // Reject future dates or dates older than 7 days
  const submittedDate = new Date(date + "T00:00:00Z");
  const now = new Date();
  const daysDiff = (now.getTime() - submittedDate.getTime()) / DAY_MS;
  if (daysDiff < -1 || daysDiff > 7) {
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
    .select("id, nickname, secret_token")
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

  return respond({ ok: true, total_coins: totalCoins, total_tokens: totalTokens, rank, live_rank: liveRank, secret_token: secretToken });
});

function json(data: any, status = 200, origin = "") {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...(origin ? { "Access-Control-Allow-Origin": origin } : {}),
    },
  });
}
