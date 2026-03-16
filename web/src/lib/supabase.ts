import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

const LEADERBOARD_BASE = `${SUPABASE_URL}/functions/v1/leaderboard`;

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export type LeaderboardType = "realtime" | "daily" | "weekly" | "monthly" | "total" | "ranking" | "search";

export interface RankEntry {
  rank: number;
  nickname: string;
  daily_coins?: number;
  period_coins?: number;
  total_coins?: number;
  vanguard_tier?: string;
  vanguard_division?: number;
  claude_tokens?: number;
  codex_tokens?: number;
  days_active?: number;
  best_tier?: string;
  last_tier?: string;
  last_division?: number;
  streak?: number;
  total_tokens?: number;
  total_claude_tokens?: number;
  total_codex_tokens?: number;
  total_days_active?: number;
  member_since?: string;
  current_streak?: number;
}

export interface TierDistEntry {
  tier: string;
  user_count: number;
}

export interface SearchResult {
  nickname: string;
  total_coins: number;
  last_tier: string;
  last_division: number | null;
  total_tokens: number;
  total_days_active: number;
  member_since: string;
}

export interface LeaderboardResponse {
  ok: boolean;
  type: string;
  date?: string;
  label?: string;
  start_date?: string;
  end_date?: string;
  page: number;
  total_pages: number;
  total_users: number;
  rankings: RankEntry[];
  tier_distribution?: TierDistEntry[];
  results?: SearchResult[];
  error?: string;
}

export interface UserProfile {
  nickname: string;
  rank: number;
  total_users: number;
  total_coins: number;
  total_tokens: number;
  last_tier: string;
  last_division: number | null;
  member_since: string;
  streak: number;
  weekly: PeriodStats;
  monthly: PeriodStats;
  history: DayRecord[];
}

interface PeriodStats {
  coins: number;
  claude_tokens: number;
  codex_tokens: number;
  days_active: number;
}

interface DayRecord {
  date: string;
  daily_coins: number;
  vanguard_tier: string;
  vanguard_division: number | null;
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
  const searchParams = new URLSearchParams({ type, page: String(page), _t: String(Date.now()), ...params });
  const res = await fetch(`${LEADERBOARD_BASE}?${searchParams}`, {
    cache: "no-store",
  });
  if (!res.ok) {
    return { ok: false, type, page, total_pages: 0, total_users: 0, rankings: [], error: `HTTP ${res.status}` };
  }
  return res.json();
}

export async function fetchSearch(query: string): Promise<{ ok: boolean; results: SearchResult[] }> {
  const res = await fetch(`${LEADERBOARD_BASE}?type=search&q=${encodeURIComponent(query)}&_t=${Date.now()}`, {
    cache: "no-store",
  });
  if (!res.ok) {
    return { ok: false, results: [] };
  }
  return res.json();
}

export async function fetchUserProfile(nickname: string): Promise<ProfileResponse> {
  const res = await fetch(`${LEADERBOARD_BASE}?user=${encodeURIComponent(nickname)}`, {
    next: { revalidate: 60 },
  });
  if (!res.ok) {
    return { ok: false, error: `HTTP ${res.status}` };
  }
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

export type Lang = "ko" | "en";

const UI_STRINGS: Record<string, [string, string]> = {
  // [ko, en]
  "vanguards_competing": ["명의 Vanguard가 AI 시대의 길을 여는 중", "vanguards pioneering the AI era"],
  "connecting": ["연결 중...", "Connecting..."],
  "loading": ["불러오는 중...", "Loading..."],
  "no_data": ["데이터 없음", "No data yet"],
  "search": ["검색...", "Search..."],
  "pts": ["점", "pts"],
  "prev": ["이전", "Prev"],
  "next": ["다음", "Next"],
  // Profile
  "back": ["뱅가드", "Vanguard"],
  "member_since": ["가입일", "Member since"],
  "day_streak": ["일 연속", "day streak"],
  "total_coins": ["총 코인", "Total Coins"],
  "weekly_tokens": ["주간 토큰", "Weekly Tokens"],
  "monthly_tokens": ["월간 토큰", "Monthly Tokens"],
  "history_30d": ["30일 기록", "30-Day History"],
  "no_history": ["기록 없음", "No history"],
  "date": ["날짜", "Date"],
  "tier": ["등급", "Tier"],
  "points": ["포인트", "Points"],
  "d_active": ["일 활동", "d active"],
  "of_vanguards": ["명 중", "of"],
  "user_not_found": ["사용자를 찾을 수 없습니다", "User not found"],
  // Enhanced leaderboard
  "streak": ["연속", "streak"],
  "vs_last_week": ["전주 대비", "vs last week"],
  "daily_avg": ["일 평균", "daily avg"],
  "activity_rate": ["활동률", "activity rate"],
  "tier_distribution": ["등급 분포", "Tier Distribution"],
  "monthly_mvp": ["이달의 MVP", "Monthly MVP"],
  "hall_of_fame": ["명예의 전당", "Hall of Fame"],
  "legend": ["레전드", "Legend"],
  "total_tokens": ["총 토큰", "Total Tokens"],
  "days_active_total": ["총 활동일", "Days Active"],
  "since": ["가입", "Since"],
  "next_tier": ["다음 등급", "Next Tier"],
  "no_change": ["변동 없음", "No change"],
  "up": ["상승", "up"],
  "down": ["하락", "down"],
  "active_days": ["활동일", "active days"],
};

export function t(key: string, lang: Lang): string {
  const pair = UI_STRINGS[key];
  return pair ? pair[lang === "ko" ? 0 : 1] : key;
}

const VANGUARD_MESSAGES: Record<string, [string, string]> = {
  "Bronze.5":      ["AI와의 첫 대화, 시작이 반입니다",           "First chat with AI"],
  "Bronze.4":      ["호기심이 이끄는 대로",                     "Curiosity leads the way"],
  "Bronze.3":      ["AI가 당신을 기억하기 시작합니다",            "AI is starting to remember you"],
  "Bronze.2":      ["AI 없던 시절이 가물가물...",               "Life before AI? Barely remember..."],
  "Bronze.1":      ["Bronze 졸업이 코앞입니다",                 "Ready to graduate from Bronze"],
  "Silver.5":      ["AI 활용에 익숙해지고 있군요",               "Getting comfortable with AI"],
  "Silver.4":      ["토큰 밀리어네어의 탄생!",                   "Token millionaire is born!"],
  "Silver.3":      ["이제 AI 없이는 좀 불편하죠?",              "Life without AI? Uncomfortable now"],
  "Silver.2":      ["이쯤 되면 AI가 동료입니다",                "AI is your colleague now"],
  "Silver.1":      ["Silver 마스터리 달성 직전!",               "Silver mastery almost complete!"],
  "Gold.5":        ["AI 시대의 뱅가드",                        "Vanguard of the AI era"],
  "Gold.4":        ["Context Window가 당신을 환영합니다",        "Context Window welcomes you"],
  "Gold.3":        ["슬슬 API가 긴장하기 시작합니다",            "The API is getting nervous"],
  "Gold.2":        ["AI와의 시너지가 폭발하고 있어요",            "AI synergy is off the charts"],
  "Gold.1":        ["Gold의 끝이 보입니다... 그 너머엔?",        "End of Gold... what lies beyond?"],
  "Platinum.5":    ["AI와 하나가 되어가고 있습니다",              "Becoming one with AI"],
  "Platinum.4":    ["Rate Limit이 슬슬 당신을 주시합니다",       "Rate Limit is watching you"],
  "Platinum.3":    ["1억 토큰! 멈출 수가 없다",                 "100M tokens! Can't stop"],
  "Platinum.2":    ["Anthropic 서버실에 당신의 이름이...",        "Your name echoes in Anthropic's servers"],
  "Platinum.1":    ["Platinum 정상이 코앞입니다",               "Almost at the Platinum summit"],
  "Diamond.5":     ["진정한 AI 네이티브의 영역",                 "True AI native territory"],
  "Diamond.4":     ["당신의 토큰이 GDP에 잡힐 수도...",          "Your tokens might show up in GDP"],
  "Diamond.3":     ["AI가 당신을 학습하고 있을지도?",             "AI might be learning from you"],
  "Diamond.2":     ["데이터센터에서 경보가 울립니다",              "Alarms going off at the datacenter"],
  "Diamond.1":     ["Diamond의 빛이 점점 강렬해집니다",          "Diamond's brilliance intensifies"],
  "Master.5":      ["AI 마스터의 경지에 진입",                   "Entering AI Master realm"],
  "Master.4":      ["Ctrl+C? 그게 뭐죠?",                     "Ctrl+C? What's that?"],
  "Master.3":      ["Sam Altman이 당신을 주목합니다",            "Sam Altman has noticed you"],
  "Master.2":      ["10억 토큰! 인류의 한계를 시험 중",           "1B tokens! Testing human limits"],
  "Master.1":      ["Master의 끝... 전설이 시작됩니다",          "Legend begins here"],
  "Grandmaster.5": ["전설의 영역에 진입",                       "Entering legendary territory"],
  "Grandmaster.4": ["Dario Amodei가 직접 연락할 수도...",       "Dario Amodei might call you"],
  "Grandmaster.3": ["항복은 없다. 오직 전진뿐",                 "No surrender. Only forward"],
  "Grandmaster.2": ["당신이 곧 벤치마크입니다",                  "You ARE the benchmark"],
  "Grandmaster.1": ["AGI까지 얼마 남지 않았습니다",              "AGI is within reach"],
  "Challenger":    ["당신이 곧 AI 시대입니다",                   "You ARE the AI era"],
};

export function vanguardMessage(tier: string, division: number | null, lang: Lang = "en"): string {
  const key = division != null ? `${tier}.${division}` : tier;
  const pair = VANGUARD_MESSAGES[key];
  return pair ? pair[lang === "ko" ? 0 : 1] : "";
}

const MILESTONES: [number, string, string][] = [
  [500_000_000, "5억 토큰! 당신이 곧 AGI입니다",                              "500M tokens! You ARE the AGI"],
  [200_000_000, "2억 토큰! OpenAI / Anthropic 양대 진영의 러브콜!",            "200M tokens! Both OpenAI & Anthropic want you!"],
  [100_000_000, "1억 토큰! 이정도면 Anthropic 직원 아닌가요?",                  "100M tokens! Aren't you an Anthropic employee?"],
  [50_000_000,  "5000만 토큰! VICTORY! GG WP",                              "50M tokens! VICTORY! GG WP"],
  [30_000_000,  "3000만 토큰! 항복은 없다. Ctrl+C도 없다",                     "30M tokens! No surrender. No Ctrl+C"],
  [20_000_000,  "2000만 토큰! Context Window가 경의를 표합니다",               "20M tokens! Context Window bows to you"],
  [15_000_000,  "1500만 토큰! AI가 당신을 학습하고 있습니다",                    "15M tokens! AI is learning from you"],
  [10_000_000,  "1000만 토큰! 당신의 토큰이 GDP에 잡힙니다",                    "10M tokens! Your tokens show up in GDP"],
  [7_000_000,   "700만 토큰! Anthropic 서버실에 경보 발령",                     "7M tokens! Alert in Anthropic's server room"],
  [5_000_000,   "500만 토큰! Rate Limit이 두려워합니다",                       "5M tokens! Rate Limit fears you"],
  [3_000_000,   "300만 토큰! 멈출 수가 없다",                                 "3M tokens! Can't stop won't stop"],
  [2_500_000,   "250만 토큰! Claude가 당신을 기억합니다",                       "2.5M tokens! Claude remembers you"],
  [2_000_000,   "200만 토큰! 도저히 막을 수 없습니다",                          "2M tokens! Absolutely unstoppable"],
  [1_500_000,   "150만 토큰! 거침없는 프롬프트",                               "1.5M tokens! Unstoppable prompting"],
  [1_000_000,   "100만 토큰! API가 비명을 지릅니다",                            "1M tokens! The API is screaming"],
  [500_000,     "50만 토큰 돌파! 워밍업 완료",                                 "500K tokens! Warm-up complete"],
];

export function tokenMilestone(totalTokens: number, lang: Lang = "en"): string {
  for (const [threshold, ko, en] of MILESTONES) {
    if (totalTokens >= threshold) return lang === "ko" ? ko : en;
  }
  return "";
}

export function formatTokens(n: number): string {
  if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(1)}B`;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
  return String(n);
}

/** 히어로 넘버: 억/만 or M/B */
export function formatHeroTokens(n: number, lang: Lang): string {
  if (lang === "ko") {
    if (n >= 100_000_000) {
      const eok = Math.floor(n / 100_000_000);
      const man = Math.floor((n % 100_000_000) / 10_000);
      return man > 0 ? `${eok}억 ${man.toLocaleString()}만` : `${eok}억`;
    }
    if (n >= 10_000) return `${Math.floor(n / 10_000).toLocaleString()}만`;
    return n.toLocaleString();
  }
  if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(2)}B`;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
  return String(n);
}

/** 계정 레벨: 누적 토큰 = 경험치, 무한 레벨 */
const LEVEL_BASE = 1_000_000; // Lv.2 = 1M tokens

export function levelThreshold(level: number): number {
  if (level <= 1) return 0;
  return LEVEL_BASE * Math.pow(2, level - 2);
}

export function calculateLevel(totalTokens: number): {
  level: number;
  currentXP: number;
  nextXP: number;
  progress: number;
} {
  if (totalTokens < LEVEL_BASE) {
    return { level: 1, currentXP: totalTokens, nextXP: LEVEL_BASE, progress: totalTokens / LEVEL_BASE };
  }
  let level = 2;
  while (levelThreshold(level + 1) <= totalTokens) {
    level++;
  }
  const current = levelThreshold(level);
  const next = levelThreshold(level + 1);
  return {
    level,
    currentXP: totalTokens - current,
    nextXP: next - current,
    progress: (totalTokens - current) / (next - current),
  };
}

/** 데일리 티어 진행 정보 */
export const TIER_THRESHOLDS = [
  { tier: "B", label: "Bronze", min: 10_000 },
  { tier: "S", label: "Silver", min: 500_000 },
  { tier: "G", label: "Gold", min: 8_000_000 },
  { tier: "P", label: "Platinum", min: 50_000_000 },
  { tier: "D", label: "Diamond", min: 220_000_000 },
  { tier: "M", label: "Master", min: 620_000_000 },
  { tier: "GM", label: "Grandmaster", min: 1_500_000_000 },
  { tier: "C", label: "Challenger", min: 5_000_000_000 },
] as const;

export function tierProgress(totalTokens: number): { index: number; fraction: number } {
  for (let i = TIER_THRESHOLDS.length - 1; i >= 0; i--) {
    if (totalTokens >= TIER_THRESHOLDS[i].min) {
      const next = TIER_THRESHOLDS[i + 1];
      if (!next) return { index: i, fraction: 1 };
      const range = next.min - TIER_THRESHOLDS[i].min;
      const progress = totalTokens - TIER_THRESHOLDS[i].min;
      return { index: i, fraction: Math.min(progress / range, 1) };
    }
  }
  if (totalTokens > 0) {
    return { index: -1, fraction: Math.min(totalTokens / TIER_THRESHOLDS[0].min, 1) };
  }
  return { index: -1, fraction: 0 };
}

export function formatNumber(n: number): string {
  return n.toLocaleString();
}

/** Delta display: "+12%" / "-5%" / "NEW" / "--" */
export function formatDelta(current: number, previous: number, lang: Lang): string {
  if (previous === 0 && current === 0) return "--";
  if (previous === 0) return lang === "ko" ? "NEW" : "NEW";

  const diff = current - previous;
  const pct = Math.round((diff / previous) * 100);

  if (pct === 0) return t("no_change", lang);
  const sign = pct > 0 ? "+" : "";
  return `${sign}${pct}%`;
}

/** Activity rate as percentage string */
export function activityRate(daysActive: number, periodDays: number): string {
  if (periodDays <= 0) return "0%";
  return `${Math.round((daysActive / periodDays) * 100)}%`;
}

/** Tier label with localization */
export function tierLabel(tier: string, lang: Lang): string {
  const labels: Record<string, [string, string]> = {
    Bronze: ["브론즈", "Bronze"],
    Silver: ["실버", "Silver"],
    Gold: ["골드", "Gold"],
    Platinum: ["플래티넘", "Platinum"],
    Diamond: ["다이아몬드", "Diamond"],
    Master: ["마스터", "Master"],
    Grandmaster: ["그랜드마스터", "Grandmaster"],
    Challenger: ["챌린저", "Challenger"],
  };
  const pair = labels[tier];
  return pair ? pair[lang === "ko" ? 0 : 1] : tier;
}

/** Delta direction indicator */
export function deltaDirection(current: number, previous: number): "up" | "down" | "same" {
  if (current > previous) return "up";
  if (current < previous) return "down";
  return "same";
}
