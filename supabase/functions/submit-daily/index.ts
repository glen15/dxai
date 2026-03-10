import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const POINT_TABLE: Record<string, { base: number; bonus: number }> = {
  Bronze:      { base: 10,   bonus: 2 },
  Silver:      { base: 25,   bonus: 5 },
  Gold:        { base: 60,   bonus: 12 },
  Platinum:    { base: 150,  bonus: 30 },
  Diamond:     { base: 350,  bonus: 70 },
  Master:      { base: 800,  bonus: 160 },
  Grandmaster: { base: 1800, bonus: 360 },
};

const VALID_TIERS = [...Object.keys(POINT_TABLE), "Challenger"];

function calculatePoints(tier: string, division: number | null): number {
  if (tier === "Challenger") return 5000;
  const entry = POINT_TABLE[tier];
  if (!entry || division === null || division < 1 || division > 5) return 0;
  return entry.base + entry.bonus * (5 - division);
}

// Simple in-memory rate limit (per device_uuid, resets on cold start)
const rateLimits = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(deviceUUID: string): boolean {
  const now = Date.now();
  const entry = rateLimits.get(deviceUUID);
  if (!entry || now > entry.resetAt) {
    rateLimits.set(deviceUUID, { count: 1, resetAt: now + 60_000 });
    return true;
  }
  entry.count++;
  return entry.count <= 10;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const {
    device_uuid,
    nickname,
    date,
    daily_points,
    total_points,
    claude_tokens,
    codex_tokens,
    pioneer_tier,
    pioneer_division,
  } = body;

  // --- Validation ---

  if (!device_uuid || typeof device_uuid !== "string") {
    return json({ ok: false, error: "invalid_device_uuid" }, 400);
  }

  if (!nickname || !/^[a-zA-Z0-9_]{2,16}$/.test(nickname)) {
    return json({ ok: false, error: "invalid_nickname" }, 400);
  }

  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return json({ ok: false, error: "invalid_date" }, 400);
  }

  // Reject future dates or dates older than 7 days
  const submittedDate = new Date(date + "T00:00:00Z");
  const now = new Date();
  const daysDiff = (now.getTime() - submittedDate.getTime()) / 86_400_000;
  if (daysDiff < -1 || daysDiff > 7) {
    return json({ ok: false, error: "date_out_of_range" }, 400);
  }

  if (typeof daily_points !== "number" || daily_points < 0 || daily_points > 5000) {
    return json({ ok: false, error: "invalid_daily_points" }, 400);
  }

  if (!VALID_TIERS.includes(pioneer_tier)) {
    return json({ ok: false, error: "invalid_tier" }, 400);
  }

  if (pioneer_tier !== "Challenger") {
    if (typeof pioneer_division !== "number" || pioneer_division < 1 || pioneer_division > 5) {
      return json({ ok: false, error: "invalid_division" }, 400);
    }
  }

  // Points-tier matching verification
  const expectedPoints = calculatePoints(pioneer_tier, pioneer_division ?? null);
  if (daily_points !== expectedPoints) {
    return json({ ok: false, error: "points_mismatch" }, 400);
  }

  if (typeof claude_tokens !== "number" || claude_tokens < 0) {
    return json({ ok: false, error: "invalid_claude_tokens" }, 400);
  }
  if (typeof codex_tokens !== "number" || codex_tokens < 0) {
    return json({ ok: false, error: "invalid_codex_tokens" }, 400);
  }

  // Rate limit
  if (!checkRateLimit(device_uuid)) {
    return json({ ok: false, error: "rate_limited" }, 429);
  }

  // --- DB Operations ---

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Upsert user
  const { data: existingUser } = await supabase
    .from("users")
    .select("id, nickname")
    .eq("device_uuid", device_uuid)
    .single();

  let userId: string;

  if (existingUser) {
    userId = existingUser.id;
    // Update nickname if changed (check uniqueness)
    if (existingUser.nickname !== nickname) {
      const { error: nickErr } = await supabase
        .from("users")
        .update({ nickname, last_tier: pioneer_tier, last_division: pioneer_division, updated_at: new Date().toISOString() })
        .eq("id", userId);
      if (nickErr?.code === "23505") {
        return json({ ok: false, error: "nickname_taken" }, 409);
      }
    } else {
      await supabase
        .from("users")
        .update({ last_tier: pioneer_tier, last_division: pioneer_division, updated_at: new Date().toISOString() })
        .eq("id", userId);
    }
  } else {
    // New user
    const { data: newUser, error: insertErr } = await supabase
      .from("users")
      .insert({ device_uuid, nickname, last_tier: pioneer_tier, last_division: pioneer_division })
      .select("id")
      .single();
    if (insertErr?.code === "23505") {
      return json({ ok: false, error: "nickname_taken" }, 409);
    }
    if (insertErr || !newUser) {
      return json({ ok: false, error: "user_creation_failed" }, 500);
    }
    userId = newUser.id;
  }

  // Upsert daily record (only update if higher points)
  const { data: existingRecord } = await supabase
    .from("daily_records")
    .select("id, daily_points, claude_tokens, codex_tokens, pioneer_tier, pioneer_division")
    .eq("user_id", userId)
    .eq("date", date)
    .single();

  if (existingRecord) {
    const shouldUpdate =
      daily_points > existingRecord.daily_points ||
      claude_tokens !== existingRecord.claude_tokens ||
      codex_tokens !== existingRecord.codex_tokens;
    if (shouldUpdate) {
      const newPoints = Math.max(daily_points, existingRecord.daily_points);
      await supabase
        .from("daily_records")
        .update({
          daily_points: newPoints,
          daily_coins: newPoints,
          claude_tokens,
          codex_tokens,
          pioneer_tier: daily_points >= existingRecord.daily_points ? pioneer_tier : existingRecord.pioneer_tier,
          pioneer_division: daily_points >= existingRecord.daily_points ? pioneer_division : existingRecord.pioneer_division,
        })
        .eq("id", existingRecord.id);
    }
  } else {
    await supabase
      .from("daily_records")
      .insert({
        user_id: userId,
        date,
        daily_points,
        daily_coins: daily_points,
        claude_tokens,
        codex_tokens,
        pioneer_tier,
        pioneer_division,
      });
  }

  // Recalculate total_points and total_coins from daily_records
  const { data: sums } = await supabase
    .from("daily_records")
    .select("daily_points, daily_coins")
    .eq("user_id", userId);

  const totalPts = sums?.reduce((s, r) => s + r.daily_points, 0) ?? 0;
  const totalCoins = sums?.reduce((s, r) => s + r.daily_coins, 0) ?? 0;

  await supabase
    .from("users")
    .update({ total_points: totalPts, total_coins: totalCoins })
    .eq("id", userId);

  // Get rank
  const { count } = await supabase
    .from("users")
    .select("id", { count: "exact", head: true })
    .gt("total_points", totalPts);

  const rank = (count ?? 0) + 1;

  return json({ ok: true, total_points: totalPts, total_coins: totalCoins, rank });
});

function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
