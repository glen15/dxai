import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const PAGE_SIZE = 50;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (req.method !== "GET") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const url = new URL(req.url);
  const type = url.searchParams.get("type") ?? "realtime";
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1"));
  const nickname = url.searchParams.get("user");

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // --- Personal profile ---
  if (nickname) {
    return await getUserProfile(supabase, nickname);
  }

  // --- Leaderboard ---
  switch (type) {
    case "realtime":
      return await realtimeLeaderboard(supabase, page);
    case "daily":
      return await dailyLeaderboard(supabase, url.searchParams.get("date"), page);
    case "weekly":
      return await periodLeaderboard(supabase, "weekly", url.searchParams.get("week"), page);
    case "monthly":
      return await periodLeaderboard(supabase, "monthly", url.searchParams.get("month"), page);
    case "total":
      return await totalLeaderboard(supabase, page);
    default:
      return json({ ok: false, error: "invalid_type" }, 400);
  }
});

// ── Realtime: today's points ranking ──

async function realtimeLeaderboard(supabase: any, page: number) {
  const today = todayDateString();

  const { data, error } = await supabase
    .from("daily_records")
    .select("daily_points, pioneer_tier, pioneer_division, claude_tokens, codex_tokens, user_id, users!inner(nickname, total_points)")
    .eq("date", today)
    .order("daily_points", { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

  if (error) return json({ ok: false, error: error.message }, 500);

  const { count } = await supabase
    .from("daily_records")
    .select("id", { count: "exact", head: true })
    .eq("date", today);

  return json({
    ok: true,
    type: "realtime",
    date: today,
    page,
    total_pages: Math.ceil((count ?? 0) / PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * PAGE_SIZE + i + 1,
      nickname: r.users.nickname,
      daily_points: r.daily_points,
      pioneer_tier: r.pioneer_tier,
      pioneer_division: r.pioneer_division,
      total_points: r.users.total_points,
      claude_tokens: r.claude_tokens,
      codex_tokens: r.codex_tokens,
    })),
  });
}

// ── Daily: specific date ranking ──

async function dailyLeaderboard(supabase: any, dateParam: string | null, page: number) {
  const date = dateParam ?? todayDateString();

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return json({ ok: false, error: "invalid_date_format" }, 400);
  }

  const { data, error } = await supabase
    .from("daily_records")
    .select("daily_points, pioneer_tier, pioneer_division, claude_tokens, codex_tokens, users!inner(nickname)")
    .eq("date", date)
    .order("daily_points", { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

  if (error) return json({ ok: false, error: error.message }, 500);

  const { count } = await supabase
    .from("daily_records")
    .select("id", { count: "exact", head: true })
    .eq("date", date);

  return json({
    ok: true,
    type: "daily",
    date,
    page,
    total_pages: Math.ceil((count ?? 0) / PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * PAGE_SIZE + i + 1,
      nickname: r.users.nickname,
      daily_points: r.daily_points,
      pioneer_tier: r.pioneer_tier,
      pioneer_division: r.pioneer_division,
      claude_tokens: r.claude_tokens,
      codex_tokens: r.codex_tokens,
    })),
  });
}

// ── Weekly / Monthly: aggregated period ranking ──

async function periodLeaderboard(supabase: any, period: "weekly" | "monthly", param: string | null, page: number) {
  const { startDate, endDate, label } = parsePeriod(period, param);

  if (!startDate) {
    return json({ ok: false, error: `invalid_${period}_format` }, 400);
  }

  // Use RPC or raw query to aggregate daily_records by user for the period
  const { data, error } = await supabase.rpc("leaderboard_period", {
    start_date: startDate,
    end_date: endDate,
    page_size: PAGE_SIZE,
    page_offset: (page - 1) * PAGE_SIZE,
  });

  if (error) return json({ ok: false, error: error.message }, 500);

  const { count } = await supabase.rpc("leaderboard_period_count", {
    start_date: startDate,
    end_date: endDate,
  });

  return json({
    ok: true,
    type: period,
    label,
    start_date: startDate,
    end_date: endDate,
    page,
    total_pages: Math.ceil((count ?? 0) / PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * PAGE_SIZE + i + 1,
      nickname: r.nickname,
      period_points: r.period_points,
      period_coins: r.period_coins,
      days_active: r.days_active,
      claude_tokens: r.claude_tokens,
      codex_tokens: r.codex_tokens,
      best_tier: r.best_tier,
    })),
  });
}

// ── Total: all-time cumulative ranking ──

async function totalLeaderboard(supabase: any, page: number) {
  const { data, error } = await supabase
    .from("users")
    .select("nickname, total_points, total_coins, last_tier, last_division")
    .order("total_points", { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

  if (error) return json({ ok: false, error: error.message }, 500);

  const { count } = await supabase
    .from("users")
    .select("id", { count: "exact", head: true });

  return json({
    ok: true,
    type: "total",
    page,
    total_pages: Math.ceil((count ?? 0) / PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * PAGE_SIZE + i + 1,
      nickname: r.nickname,
      total_points: r.total_points,
      total_coins: r.total_coins,
      last_tier: r.last_tier,
      last_division: r.last_division,
    })),
  });
}

// ── User profile ──

async function getUserProfile(supabase: any, nickname: string) {
  const { data: user, error } = await supabase
    .from("users")
    .select("id, nickname, total_points, total_coins, last_tier, last_division, created_at")
    .eq("nickname", nickname)
    .single();

  if (error || !user) {
    return json({ ok: false, error: "user_not_found" }, 404);
  }

  // Global rank
  const { count: rankAbove } = await supabase
    .from("users")
    .select("id", { count: "exact", head: true })
    .gt("total_points", user.total_points);

  const rank = (rankAbove ?? 0) + 1;

  // Last 30 days history
  const thirtyDaysAgo = dateOffset(-30);
  const { data: history } = await supabase
    .from("daily_records")
    .select("date, daily_points, daily_coins, pioneer_tier, pioneer_division, claude_tokens, codex_tokens")
    .eq("user_id", user.id)
    .gte("date", thirtyDaysAgo)
    .order("date", { ascending: false });

  // Weekly stats (last 7 days)
  const sevenDaysAgo = dateOffset(-7);
  const weekRecords = (history ?? []).filter((r: any) => r.date >= sevenDaysAgo);
  const weeklyPoints = weekRecords.reduce((s: number, r: any) => s + r.daily_points, 0);
  const weeklyCoins = weekRecords.reduce((s: number, r: any) => s + r.daily_coins, 0);
  const weeklyClaudeTokens = weekRecords.reduce((s: number, r: any) => s + r.claude_tokens, 0);
  const weeklyCodexTokens = weekRecords.reduce((s: number, r: any) => s + r.codex_tokens, 0);

  // Monthly stats (last 30 days)
  const monthlyPoints = (history ?? []).reduce((s: number, r: any) => s + r.daily_points, 0);
  const monthlyCoins = (history ?? []).reduce((s: number, r: any) => s + r.daily_coins, 0);
  const monthlyClaudeTokens = (history ?? []).reduce((s: number, r: any) => s + r.claude_tokens, 0);
  const monthlyCodexTokens = (history ?? []).reduce((s: number, r: any) => s + r.codex_tokens, 0);

  // Active streak
  const streak = calculateStreak(history ?? []);

  // Total users count
  const { count: totalUsers } = await supabase
    .from("users")
    .select("id", { count: "exact", head: true });

  return json({
    ok: true,
    profile: {
      nickname: user.nickname,
      rank,
      total_users: totalUsers ?? 0,
      total_points: user.total_points,
      total_coins: user.total_coins,
      last_tier: user.last_tier,
      last_division: user.last_division,
      member_since: user.created_at,
      streak,
      weekly: {
        points: weeklyPoints,
        coins: weeklyCoins,
        claude_tokens: weeklyClaudeTokens,
        codex_tokens: weeklyCodexTokens,
        days_active: weekRecords.length,
      },
      monthly: {
        points: monthlyPoints,
        coins: monthlyCoins,
        claude_tokens: monthlyClaudeTokens,
        codex_tokens: monthlyCodexTokens,
        days_active: (history ?? []).length,
      },
      history: (history ?? []).map((r: any) => ({
        date: r.date,
        daily_points: r.daily_points,
        pioneer_tier: r.pioneer_tier,
        pioneer_division: r.pioneer_division,
        claude_tokens: r.claude_tokens,
        codex_tokens: r.codex_tokens,
      })),
    },
  });
}

// ── Helpers ──

/** KST (UTC+9) 기준 현재 시각 */
function nowKST(): Date {
  return new Date(Date.now() + 9 * 60 * 60 * 1000);
}

function todayDateString(): string {
  return nowKST().toISOString().slice(0, 10);
}

function dateOffset(days: number): string {
  const kst = nowKST();
  kst.setDate(kst.getDate() + days);
  return kst.toISOString().slice(0, 10);
}

function parsePeriod(period: "weekly" | "monthly", param: string | null) {
  if (period === "weekly") {
    // Format: YYYY-Wxx or auto (current week, KST)
    if (!param) {
      const now = nowKST();
      const dayOfWeek = now.getUTCDay(); // KST를 UTC로 변환했으므로 getUTCDay 사용
      const monday = new Date(now);
      monday.setUTCDate(now.getUTCDate() - ((dayOfWeek + 6) % 7));
      const sunday = new Date(monday);
      sunday.setUTCDate(monday.getUTCDate() + 6);
      return {
        startDate: monday.toISOString().slice(0, 10),
        endDate: sunday.toISOString().slice(0, 10),
        label: `${monday.toISOString().slice(0, 10)} ~ ${sunday.toISOString().slice(0, 10)}`,
      };
    }
    const match = param.match(/^(\d{4})-W(\d{2})$/);
    if (!match) return { startDate: null, endDate: null, label: null };
    const year = parseInt(match[1]);
    const week = parseInt(match[2]);
    const jan4 = new Date(Date.UTC(year, 0, 4));
    const dayOfWeek = jan4.getUTCDay() || 7;
    const monday = new Date(jan4);
    monday.setUTCDate(jan4.getUTCDate() - dayOfWeek + 1 + (week - 1) * 7);
    const sunday = new Date(monday);
    sunday.setUTCDate(monday.getUTCDate() + 6);
    return {
      startDate: monday.toISOString().slice(0, 10),
      endDate: sunday.toISOString().slice(0, 10),
      label: `${year}-W${String(week).padStart(2, "0")}`,
    };
  }

  // Monthly: YYYY-MM (KST)
  if (!param) {
    const now = nowKST();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const lastDay = new Date(Date.UTC(year, now.getUTCMonth() + 1, 0)).getUTCDate();
    return {
      startDate: `${year}-${month}-01`,
      endDate: `${year}-${month}-${lastDay}`,
      label: `${year}-${month}`,
    };
  }
  const match = param.match(/^(\d{4})-(\d{2})$/);
  if (!match) return { startDate: null, endDate: null, label: null };
  const year = parseInt(match[1]);
  const month = parseInt(match[2]);
  const lastDay = new Date(year, month, 0).getDate();
  return {
    startDate: `${year}-${String(month).padStart(2, "0")}-01`,
    endDate: `${year}-${String(month).padStart(2, "0")}-${lastDay}`,
    label: param,
  };
}

function calculateStreak(history: any[]): number {
  if (history.length === 0) return 0;

  // history is sorted desc by date
  const sorted = [...history].sort((a, b) => b.date.localeCompare(a.date));
  const today = todayDateString();
  let streak = 0;
  let expectedDate = today;

  for (const record of sorted) {
    if (record.date === expectedDate) {
      streak++;
      const d = new Date(expectedDate + "T00:00:00Z");
      d.setDate(d.getDate() - 1);
      expectedDate = d.toISOString().slice(0, 10);
    } else if (record.date < expectedDate) {
      // Allow starting from yesterday if today has no record yet
      if (streak === 0 && record.date === dateOffset(-1).slice(0, 10)) {
        const d = new Date(record.date + "T00:00:00Z");
        streak = 1;
        d.setDate(d.getDate() - 1);
        expectedDate = d.toISOString().slice(0, 10);
      } else {
        break;
      }
    }
  }

  return streak;
}

function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}
