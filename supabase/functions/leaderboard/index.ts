import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const PAGE_SIZE = 50;
const LIVE_PAGE_SIZE = 20;

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
    Deno.env.get("SUPABASE_ANON_KEY")!
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
      return await weeklyLeaderboard(supabase, url.searchParams.get("week"), page);
    case "monthly":
      return await monthlyLeaderboard(supabase, url.searchParams.get("month"), page);
    case "total":
      return await totalLeaderboard(supabase, page);
    case "ranking":
      return await tokenRanking(supabase, page);
    case "search":
      return await searchUsers(supabase, url.searchParams.get("q") ?? "");
    default:
      return json({ ok: false, error: "invalid_type" }, 400);
  }
});

// ── Realtime: today's token ranking ──

async function realtimeLeaderboard(supabase: any, page: number) {
  const today = todayDateString();

  const { data, error } = await supabase.rpc("leaderboard_daily_by_tokens", {
    p_date: today,
    p_limit: LIVE_PAGE_SIZE,
    p_offset: (page - 1) * LIVE_PAGE_SIZE,
  });

  if (error) return json({ ok: false, error: "internal_error" }, 500);

  const { count } = await supabase
    .from("daily_records")
    .select("id", { count: "exact", head: true })
    .eq("date", today);

  return json({
    ok: true,
    type: "realtime",
    date: today,
    page,
    total_pages: Math.ceil((count ?? 0) / LIVE_PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * LIVE_PAGE_SIZE + i + 1,
      nickname: r.nickname,
      daily_coins: r.daily_coins,
      vanguard_tier: r.vanguard_tier,
      vanguard_division: r.vanguard_division,
      claude_tokens: r.claude_tokens,
      codex_tokens: r.codex_tokens,
      total_tokens: r.total_tokens,
    })),
  });
}

// ── Daily: specific date ranking ──

async function dailyLeaderboard(supabase: any, dateParam: string | null, page: number) {
  const date = dateParam ?? todayDateString();

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return json({ ok: false, error: "invalid_date_format" }, 400);
  }

  const { data, error } = await supabase.rpc("leaderboard_daily_by_tokens", {
    p_date: date,
    p_limit: LIVE_PAGE_SIZE,
    p_offset: (page - 1) * LIVE_PAGE_SIZE,
  });

  if (error) return json({ ok: false, error: "internal_error" }, 500);

  const { count } = await supabase
    .from("daily_records")
    .select("id", { count: "exact", head: true })
    .eq("date", date);

  return json({
    ok: true,
    type: "daily",
    date,
    page,
    total_pages: Math.ceil((count ?? 0) / LIVE_PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * LIVE_PAGE_SIZE + i + 1,
      nickname: r.nickname,
      daily_coins: r.daily_coins,
      vanguard_tier: r.vanguard_tier,
      vanguard_division: r.vanguard_division,
      claude_tokens: r.claude_tokens,
      codex_tokens: r.codex_tokens,
      total_tokens: r.total_tokens,
    })),
  });
}

// ── Weekly: enhanced with streak, prev_week, daily_breakdown ──

async function weeklyLeaderboard(supabase: any, param: string | null, page: number) {
  const { startDate, endDate, label } = parsePeriod("weekly", param);

  if (!startDate) {
    return json({ ok: false, error: "invalid_weekly_format" }, 400);
  }

  const { data, error } = await supabase.rpc("leaderboard_weekly_enhanced", {
    p_start_date: startDate,
    p_end_date: endDate,
    p_limit: PAGE_SIZE,
    p_offset: (page - 1) * PAGE_SIZE,
  });

  if (error) return json({ ok: false, error: "internal_error" }, 500);

  const { count } = await supabase.rpc("leaderboard_period_count", {
    start_date: startDate,
    end_date: endDate,
  });

  return json({
    ok: true,
    type: "weekly",
    label,
    start_date: startDate,
    end_date: endDate,
    page,
    total_pages: Math.ceil((count ?? 0) / PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * PAGE_SIZE + i + 1,
      nickname: r.nickname,
      period_coins: r.period_coins,
      days_active: r.days_active,
      claude_tokens: r.claude_tokens,
      codex_tokens: r.codex_tokens,
      best_tier: r.best_tier,
      streak: r.streak,
      prev_week_points: r.prev_week_points,
      daily_breakdown: r.daily_breakdown,
    })),
  });
}

// ── Monthly: enhanced with best_division, period_days, tier_distribution ──

async function monthlyLeaderboard(supabase: any, param: string | null, page: number) {
  const { startDate, endDate, label } = parsePeriod("monthly", param);

  if (!startDate) {
    return json({ ok: false, error: "invalid_monthly_format" }, 400);
  }

  const [mainResult, distResult, countResult] = await Promise.all([
    supabase.rpc("leaderboard_monthly_enhanced", {
      p_start_date: startDate,
      p_end_date: endDate,
      p_limit: PAGE_SIZE,
      p_offset: (page - 1) * PAGE_SIZE,
    }),
    supabase.rpc("tier_distribution", {
      p_start_date: startDate,
      p_end_date: endDate,
    }),
    supabase.rpc("leaderboard_period_count", {
      start_date: startDate,
      end_date: endDate,
    }),
  ]);

  if (mainResult.error) return json({ ok: false, error: "internal_error" }, 500);

  const data = mainResult.data ?? [];
  const tierDist = distResult.data ?? [];
  const count = countResult.count ?? countResult.data ?? 0;

  return json({
    ok: true,
    type: "monthly",
    label,
    start_date: startDate,
    end_date: endDate,
    page,
    total_pages: Math.ceil((typeof count === "number" ? count : 0) / PAGE_SIZE),
    total_users: typeof count === "number" ? count : 0,
    tier_distribution: tierDist.map((r: any) => ({
      tier: r.tier,
      user_count: r.user_count,
    })),
    rankings: data.map((r: any, i: number) => ({
      rank: (page - 1) * PAGE_SIZE + i + 1,
      nickname: r.nickname,
      period_coins: r.period_coins,
      days_active: r.days_active,
      claude_tokens: r.claude_tokens,
      codex_tokens: r.codex_tokens,
      best_tier: r.best_tier,
      best_division: r.best_division,
      period_days: r.period_days,
      daily_breakdown: r.daily_breakdown,
    })),
  });
}

// ── Total: enhanced with token breakdown, days_active, member_since, streak ──

async function totalLeaderboard(supabase: any, page: number) {
  const { data, error } = await supabase.rpc("leaderboard_total_enhanced", {
    p_limit: PAGE_SIZE,
    p_offset: (page - 1) * PAGE_SIZE,
  });

  if (error) return json({ ok: false, error: "internal_error" }, 500);

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
      total_coins: r.total_coins,
      last_tier: r.last_tier,
      last_division: r.last_division,
      total_claude_tokens: r.total_claude_tokens,
      total_codex_tokens: r.total_codex_tokens,
      total_days_active: r.total_days_active,
      member_since: r.member_since,
      current_streak: r.current_streak,
    })),
  });
}

// ── Token-based global ranking ──

async function tokenRanking(supabase: any, page: number) {
  const { data, error } = await supabase.rpc("leaderboard_by_tokens", {
    p_limit: PAGE_SIZE,
    p_offset: (page - 1) * PAGE_SIZE,
  });

  if (error) return json({ ok: false, error: "internal_error" }, 500);

  const { count } = await supabase
    .from("users")
    .select("id", { count: "exact", head: true });

  return json({
    ok: true,
    type: "ranking",
    page,
    total_pages: Math.ceil((count ?? 0) / PAGE_SIZE),
    total_users: count ?? 0,
    rankings: (data ?? []).map((r: any, i: number) => ({
      rank: (page - 1) * PAGE_SIZE + i + 1,
      nickname: r.nickname,
      total_tokens: r.total_tokens,
      total_claude_tokens: r.total_claude_tokens,
      total_codex_tokens: r.total_codex_tokens,
      total_coins: r.total_coins,
      last_tier: r.last_tier,
      last_division: r.last_division,
      total_days_active: r.total_days_active,
      member_since: r.member_since,
    })),
  });
}

// ── User search ──

async function searchUsers(supabase: any, query: string) {
  if (!query || query.length < 1) {
    return json({ ok: true, type: "search", results: [] });
  }

  const { data, error } = await supabase.rpc("search_users", {
    p_query: query,
    p_limit: 20,
  });

  if (error) return json({ ok: false, error: "internal_error" }, 500);

  return json({
    ok: true,
    type: "search",
    results: (data ?? []).map((r: any) => ({
      nickname: r.nickname,
      total_coins: r.total_coins,
      last_tier: r.last_tier,
      last_division: r.last_division,
      total_tokens: r.total_tokens,
      total_days_active: r.total_days_active,
      member_since: r.member_since,
    })),
  });
}

// ── User profile ──

async function getUserProfile(supabase: any, nickname: string) {
  const { data: user, error } = await supabase
    .from("users")
    .select("id, nickname, total_coins, last_tier, last_division, created_at")
    .eq("nickname", nickname)
    .single();

  if (error || !user) {
    return json({ ok: false, error: "user_not_found" }, 404);
  }

  // Last 30 days history
  const thirtyDaysAgo = dateOffset(-30);
  const { data: history } = await supabase
    .from("daily_records")
    .select("date, daily_coins, vanguard_tier, vanguard_division, claude_tokens, codex_tokens")
    .eq("user_id", user.id)
    .gte("date", thirtyDaysAgo)
    .order("date", { ascending: false });

  // Weekly stats (last 7 days)
  const sevenDaysAgo = dateOffset(-7);
  const weekRecords = (history ?? []).filter((r: any) => r.date >= sevenDaysAgo);
  const weeklyCoins = weekRecords.reduce((s: number, r: any) => s + r.daily_coins, 0);
  const weeklyClaudeTokens = weekRecords.reduce((s: number, r: any) => s + r.claude_tokens, 0);
  const weeklyCodexTokens = weekRecords.reduce((s: number, r: any) => s + r.codex_tokens, 0);

  // Monthly stats (last 30 days)
  const monthlyCoins = (history ?? []).reduce((s: number, r: any) => s + r.daily_coins, 0);
  const monthlyClaudeTokens = (history ?? []).reduce((s: number, r: any) => s + r.claude_tokens, 0);
  const monthlyCodexTokens = (history ?? []).reduce((s: number, r: any) => s + r.codex_tokens, 0);

  // Global rank + total tokens — DB에서 RANK() OVER로 효율적 계산
  const { data: rankData } = await supabase.rpc("user_token_rank", {
    p_nickname: nickname,
  });
  const rank = rankData?.[0]?.rank ?? 1;
  const totalTokens = Number(rankData?.[0]?.total_tokens ?? 0);

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
      total_coins: user.total_coins,
      total_tokens: totalTokens,
      last_tier: user.last_tier,
      last_division: user.last_division,
      member_since: user.created_at,
      streak,
      weekly: {
        coins: weeklyCoins,
        claude_tokens: weeklyClaudeTokens,
        codex_tokens: weeklyCodexTokens,
        days_active: weekRecords.length,
      },
      monthly: {
        coins: monthlyCoins,
        claude_tokens: monthlyClaudeTokens,
        codex_tokens: monthlyCodexTokens,
        days_active: (history ?? []).length,
      },
      history: (history ?? []).map((r: any) => ({
        date: r.date,
        daily_coins: r.daily_coins,
        vanguard_tier: r.vanguard_tier,
        vanguard_division: r.vanguard_division,
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
