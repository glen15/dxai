const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

const LEADERBOARD_BASE = `${SUPABASE_URL}/functions/v1/leaderboard`;

export type LeaderboardType = "realtime" | "daily" | "weekly" | "monthly" | "total";

export interface RankEntry {
  rank: number;
  nickname: string;
  daily_points?: number;
  period_points?: number;
  total_points?: number;
  total_coins?: number;
  pioneer_tier?: string;
  pioneer_division?: number;
  claude_tokens?: number;
  codex_tokens?: number;
  days_active?: number;
  best_tier?: string;
  last_tier?: string;
  last_division?: number;
}

export interface LeaderboardResponse {
  ok: boolean;
  type: string;
  date?: string;
  label?: string;
  page: number;
  total_pages: number;
  total_users: number;
  rankings: RankEntry[];
  error?: string;
}

export interface UserProfile {
  nickname: string;
  rank: number;
  total_users: number;
  total_points: number;
  total_coins: number;
  last_tier: string;
  last_division: number | null;
  member_since: string;
  streak: number;
  weekly: PeriodStats;
  monthly: PeriodStats;
  history: DayRecord[];
}

interface PeriodStats {
  points: number;
  coins: number;
  claude_tokens: number;
  codex_tokens: number;
  days_active: number;
}

interface DayRecord {
  date: string;
  daily_points: number;
  pioneer_tier: string;
  pioneer_division: number | null;
  claude_tokens: number;
  codex_tokens: number;
}

export interface ProfileResponse {
  ok: boolean;
  profile?: UserProfile;
  error?: string;
}

export async function fetchLeaderboard(
  type: LeaderboardType,
  params: Record<string, string> = {},
  page = 1
): Promise<LeaderboardResponse> {
  const searchParams = new URLSearchParams({ type, page: String(page), ...params });
  const res = await fetch(`${LEADERBOARD_BASE}?${searchParams}`, {
    next: { revalidate: type === "realtime" ? 30 : 60 },
  });
  return res.json();
}

export async function fetchUserProfile(nickname: string): Promise<ProfileResponse> {
  const res = await fetch(`${LEADERBOARD_BASE}?user=${encodeURIComponent(nickname)}`, {
    next: { revalidate: 60 },
  });
  return res.json();
}

export function tierColor(tier: string): string {
  const colors: Record<string, string> = {
    Bronze: "text-amber-700",
    Silver: "text-gray-400",
    Gold: "text-yellow-400",
    Platinum: "text-cyan-300",
    Diamond: "text-blue-400",
    Master: "text-purple-400",
    Grandmaster: "text-red-400",
    Challenger: "text-orange-400",
  };
  return colors[tier] ?? "text-gray-300";
}

export function tierEmoji(tier: string): string {
  const emojis: Record<string, string> = {
    Bronze: "\u{1F949}",
    Silver: "\u{1F948}",
    Gold: "\u{1F947}",
    Platinum: "\u{1F4A0}",
    Diamond: "\u{1F48E}",
    Master: "\u{1F3C6}",
    Grandmaster: "\u{1F451}",
    Challenger: "\u{26A1}",
  };
  return emojis[tier] ?? "";
}

export function formatTokens(n: number): string {
  if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(1)}B`;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
  return String(n);
}

export function formatNumber(n: number): string {
  return n.toLocaleString();
}
