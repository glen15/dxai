"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  fetchLeaderboard,
  supabase,
  type LeaderboardType,
  type LeaderboardResponse,
  type RankEntry,
  type Lang,
  tierColor,
  formatTokens,
  formatNumber,
  pioneerMessage,
  tokenMilestone,
} from "@/lib/supabase";

const TABS: { key: LeaderboardType; label: string }[] = [
  { key: "realtime", label: "Live" },
  { key: "daily", label: "Daily" },
  { key: "weekly", label: "Weekly" },
  { key: "monthly", label: "Monthly" },
  { key: "total", label: "All-time" },
];

// Tier badge colors for backgrounds
const TIER_BG: Record<string, string> = {
  Bronze: "bg-amber-900/20 text-amber-600 border-amber-800/30",
  Silver: "bg-slate-700/20 text-slate-300 border-slate-600/30",
  Gold: "bg-yellow-900/20 text-yellow-400 border-yellow-700/30",
  Platinum: "bg-cyan-900/20 text-cyan-300 border-cyan-700/30",
  Diamond: "bg-blue-900/20 text-blue-400 border-blue-700/30",
  Master: "bg-purple-900/20 text-purple-400 border-purple-700/30",
  Grandmaster: "bg-red-900/20 text-red-400 border-red-700/30",
  Challenger: "bg-orange-900/20 text-orange-400 border-orange-700/30",
};

function TierBadge({ tier, division }: { tier: string; division: number | null }) {
  const cls = TIER_BG[tier] ?? "bg-gray-800/20 text-gray-400 border-gray-700/30";
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium border ${cls}`}>
      {tier}{division != null && ` ${division}`}
    </span>
  );
}

// Countdown ring SVG
function CountdownRing({ seconds, total = 60 }: { seconds: number; total?: number }) {
  const r = 10;
  const circ = 2 * Math.PI * r;
  const offset = circ * (1 - seconds / total);
  return (
    <div className="flex items-center gap-2">
      <svg width="24" height="24" viewBox="0 0 24 24" className="countdown-ring">
        <circle cx="12" cy="12" r={r} fill="none" strokeWidth="2" className="countdown-track" />
        <circle
          cx="12" cy="12" r={r} fill="none" strokeWidth="2"
          className="countdown-fill"
          strokeDasharray={circ}
          strokeDashoffset={offset}
          strokeLinecap="round"
        />
      </svg>
      <span className="font-mono text-xs tabular-nums text-cyan-400/80">
        {seconds > 0 ? `${seconds}s` : "..."}
      </span>
    </div>
  );
}

// Top 3 podium card
function PodiumCard({ entry, lang, prev }: {
  entry: RankEntry;
  lang: Lang;
  prev?: { claude: number; codex: number };
}) {
  const tier = entry.pioneer_tier ?? entry.last_tier ?? "";
  const division = entry.pioneer_division ?? entry.last_division ?? null;
  const points = entry.daily_points ?? entry.period_points ?? entry.total_points ?? 0;
  const claude = entry.claude_tokens ?? 0;
  const codex = entry.codex_tokens ?? 0;
  const message = pioneerMessage(tier, division, lang);
  const milestone = tokenMilestone(claude + codex, lang);
  const claudeDiff = prev ? claude - prev.claude : 0;
  const codexDiff = prev ? codex - prev.codex : 0;

  const podiumClass =
    entry.rank === 1 ? "podium-card podium-gold" :
    entry.rank === 2 ? "podium-card podium-silver" :
    "podium-card podium-bronze";

  const rankColors = ["text-yellow-400", "text-slate-300", "text-amber-600"];
  const rankLabels = ["1st", "2nd", "3rd"];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: entry.rank * 0.1 }}
      className={podiumClass}
    >
      {/* Rank + Name */}
      <div className="flex items-start justify-between mb-3">
        <div>
          <span className={`font-mono text-2xl font-bold ${rankColors[entry.rank - 1]}`}>
            {rankLabels[entry.rank - 1]}
          </span>
          <a
            href={`/user/${entry.nickname}`}
            className="block text-sm font-semibold mt-1 hover:text-purple-400 transition-colors cursor-pointer"
          >
            {entry.nickname}
          </a>
        </div>
        <TierBadge tier={tier} division={division} />
      </div>

      {/* Pioneer message */}
      {message && (
        <p className="text-xs text-white/30 italic mb-3 leading-relaxed">{message}</p>
      )}

      {/* Points */}
      <div className="font-mono text-lg font-bold tracking-tight mb-2">
        {formatNumber(points)} <span className="text-xs font-normal text-white/30">pts</span>
      </div>

      {/* Token bars */}
      <div className="flex gap-3 text-xs font-mono">
        <div className="flex-1">
          <div className="text-orange-400/50 mb-0.5">Claude</div>
          <div className="text-orange-400/80">
            {formatTokens(claude)}
            {claudeDiff > 0 && <span className="text-orange-300 ml-1 token-diff">+{formatTokens(claudeDiff)}</span>}
          </div>
        </div>
        <div className="flex-1">
          <div className="text-emerald-400/50 mb-0.5">Codex</div>
          <div className="text-emerald-400/80">
            {formatTokens(codex)}
            {codexDiff > 0 && <span className="text-emerald-300 ml-1 token-diff">+{formatTokens(codexDiff)}</span>}
          </div>
        </div>
      </div>

      {/* Milestone */}
      {milestone && (
        <p className="text-[10px] text-purple-400/40 mt-3 truncate">{milestone}</p>
      )}
    </motion.div>
  );
}

export default function Home() {
  const [tab, setTab] = useState<LeaderboardType>("realtime");
  const [data, setData] = useState<LeaderboardResponse | null>(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [dateInput, setDateInput] = useState(todayString());
  const [search, setSearch] = useState("");
  const [lang, setLang] = useState<Lang>("en");
  const [countdown, setCountdown] = useState(60);
  const [prevTokens, setPrevTokens] = useState<Record<string, { claude: number; codex: number }>>({});
  const lastUpdateRef = useRef<Date>(new Date());
  const dataRef = useRef<LeaderboardResponse | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const params: Record<string, string> = {};
    if (tab === "daily") params.date = dateInput;
    const result = await fetchLeaderboard(tab, params, page);
    if (dataRef.current?.rankings) {
      const snapshot: Record<string, { claude: number; codex: number }> = {};
      for (const r of dataRef.current.rankings) {
        snapshot[r.nickname] = { claude: r.claude_tokens ?? 0, codex: r.codex_tokens ?? 0 };
      }
      setPrevTokens(snapshot);
    }
    dataRef.current = result;
    setData(result);
    setLoading(false);
    lastUpdateRef.current = new Date();
    setCountdown(60);
  }, [tab, page, dateInput]);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (tab !== "realtime") return;
    const channel = supabase
      .channel("leaderboard-realtime")
      .on("postgres_changes", { event: "*", schema: "public", table: "daily_records" }, () => { load(); })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [tab, load]);

  useEffect(() => {
    if (tab !== "realtime") return;
    const tick = setInterval(() => {
      const elapsed = Math.floor((Date.now() - lastUpdateRef.current.getTime()) / 1000);
      const remaining = Math.max(0, 60 - elapsed);
      setCountdown(remaining);
      if (remaining === 0) load();
    }, 1000);
    return () => clearInterval(tick);
  }, [tab, load]);

  const filteredRankings = data?.rankings?.filter(
    (r) => !search || r.nickname.toLowerCase().includes(search.toLowerCase())
  );

  const topThree = filteredRankings?.slice(0, 3) ?? [];
  const rest = filteredRankings?.slice(3) ?? [];

  return (
    <div>
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="mb-10 flex items-start justify-between"
      >
        <div>
          <h1 className="text-2xl font-bold tracking-tight">
            <span className="text-white/90">AI Pioneer</span>{" "}
            <span className="bg-gradient-to-r from-purple-400 to-cyan-400 bg-clip-text text-transparent">
              Leaderboard
            </span>
          </h1>
          <p className="text-white/25 text-xs mt-1.5 tracking-wide">
            {data ? `${formatNumber(data.total_users)} pioneers competing` : "Connecting..."}
          </p>
        </div>
        <div className="flex items-center gap-3">
          {tab === "realtime" && <CountdownRing seconds={countdown} />}
          <button
            onClick={() => setLang((l) => (l === "en" ? "ko" : "en"))}
            className="px-2.5 py-1 bg-white/[0.03] border border-white/[0.06] rounded-md text-xs font-medium text-white/40 hover:text-white/70 hover:bg-white/[0.06] transition-all cursor-pointer"
          >
            {lang === "en" ? "KR" : "EN"}
          </button>
        </div>
      </motion.div>

      {/* Tabs */}
      <div className="flex gap-0.5 mb-8 bg-white/[0.02] rounded-lg p-0.5 w-fit border border-white/[0.04]">
        {TABS.map(({ key, label }) => (
          <button
            key={key}
            onClick={() => { setTab(key); setPage(1); }}
            className={`px-4 py-1.5 rounded-md text-xs font-medium transition-all cursor-pointer ${
              tab === key
                ? "bg-white/[0.08] text-white shadow-sm"
                : "text-white/30 hover:text-white/60"
            }`}
          >
            {label}
            {key === "realtime" && tab === key && (
              <span className="ml-1.5 w-1.5 h-1.5 bg-cyan-400 rounded-full inline-block animate-pulse" />
            )}
          </button>
        ))}
      </div>

      {/* Controls */}
      <div className="flex gap-3 mb-6 items-center">
        {tab === "daily" && (
          <input
            type="date"
            value={dateInput}
            onChange={(e) => { setDateInput(e.target.value); setPage(1); }}
            className="bg-white/[0.02] border border-white/[0.06] rounded-md px-3 py-1.5 text-xs text-white/70"
          />
        )}
        <div className="relative">
          <svg className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-white/20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" />
            <path d="M21 21l-4.35-4.35" />
          </svg>
          <input
            type="text"
            placeholder="Search..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="bg-white/[0.02] border border-white/[0.06] rounded-md pl-8 pr-3 py-1.5 text-xs w-56 focus:outline-none focus:border-cyan-500/30 text-white/70 placeholder:text-white/15 transition-colors"
          />
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-24">
          <div className="flex items-center gap-3 text-white/20 text-sm">
            <svg className="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" strokeOpacity="0.2" />
              <path d="M12 2a10 10 0 019.95 9" />
            </svg>
            Loading...
          </div>
        </div>
      ) : !filteredRankings?.length ? (
        <div className="flex items-center justify-center py-24 text-white/15 text-sm">
          No data yet
        </div>
      ) : (
        <>
          {/* Top 3 Podium */}
          {topThree.length > 0 && (
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-8">
              {topThree.map((entry) => (
                <PodiumCard
                  key={entry.nickname}
                  entry={entry}
                  lang={lang}
                  prev={prevTokens[entry.nickname]}
                />
              ))}
            </div>
          )}

          {/* Rest of rankings */}
          {rest.length > 0 && (
            <div className="bg-white/[0.015] rounded-xl border border-white/[0.04] overflow-hidden">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/[0.04] text-white/20 text-[10px] uppercase tracking-[0.15em]">
                    <th className="text-left py-2.5 px-4 w-14">#</th>
                    <th className="text-left py-2.5 px-4">Pioneer</th>
                    <th className="text-left py-2.5 px-4">Tier</th>
                    <th className="text-right py-2.5 px-4 hidden sm:table-cell">
                      <span className="text-orange-400/40">Claude</span>
                    </th>
                    <th className="text-right py-2.5 px-4 hidden sm:table-cell">
                      <span className="text-emerald-400/40">Codex</span>
                    </th>
                    <th className="text-right py-2.5 px-4">Pts</th>
                  </tr>
                </thead>
                <tbody>
                  <AnimatePresence mode="popLayout">
                    {rest.map((entry, i) => (
                      <RankRow
                        key={entry.nickname}
                        entry={entry}
                        type={tab}
                        lang={lang}
                        prev={prevTokens[entry.nickname]}
                        index={i}
                      />
                    ))}
                  </AnimatePresence>
                </tbody>
              </table>
            </div>
          )}
        </>
      )}

      {/* Pagination */}
      {data && data.total_pages > 1 && (
        <div className="flex justify-center gap-2 mt-8">
          <button
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
            className="px-3 py-1.5 bg-white/[0.03] border border-white/[0.06] rounded-md text-xs disabled:opacity-20 hover:bg-white/[0.06] transition-colors cursor-pointer"
          >
            Prev
          </button>
          <span className="px-3 py-1.5 text-xs text-white/20 font-mono">
            {page} / {data.total_pages}
          </span>
          <button
            onClick={() => setPage((p) => Math.min(data.total_pages, p + 1))}
            disabled={page >= data.total_pages}
            className="px-3 py-1.5 bg-white/[0.03] border border-white/[0.06] rounded-md text-xs disabled:opacity-20 hover:bg-white/[0.06] transition-colors cursor-pointer"
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}

function RankRow({ entry, type, lang, prev, index }: {
  entry: RankEntry;
  type: LeaderboardType;
  lang: Lang;
  prev?: { claude: number; codex: number };
  index: number;
}) {
  const tier = entry.pioneer_tier ?? entry.best_tier ?? entry.last_tier ?? "";
  const division = entry.pioneer_division ?? entry.last_division ?? null;
  const points = entry.daily_points ?? entry.period_points ?? entry.total_points ?? 0;
  const claude = entry.claude_tokens ?? 0;
  const codex = entry.codex_tokens ?? 0;
  const message = pioneerMessage(tier, division, lang);
  const milestone = tokenMilestone(claude + codex, lang);
  const claudeDiff = prev ? claude - prev.claude : 0;
  const codexDiff = prev ? codex - prev.codex : 0;

  return (
    <motion.tr
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.2, delay: index * 0.02 }}
      className="border-b border-white/[0.02] hover:bg-white/[0.02] transition-colors group"
    >
      <td className="py-2.5 px-4">
        <span className="font-mono text-xs text-white/25">
          {entry.rank}
        </span>
      </td>
      <td className="py-2.5 px-4">
        <div>
          <a
            href={`/user/${entry.nickname}`}
            className="text-sm text-white/70 group-hover:text-white transition-colors cursor-pointer"
          >
            {entry.nickname}
          </a>
          {milestone && (
            <p className="text-[10px] text-purple-400/30 mt-0.5">{milestone}</p>
          )}
        </div>
      </td>
      <td className="py-2.5 px-4">
        <div>
          <TierBadge tier={tier} division={division} />
          {message && (
            <p className="text-[10px] text-white/15 mt-0.5 italic">{message}</p>
          )}
        </div>
      </td>
      <td className="py-2.5 px-4 text-right font-mono text-xs hidden sm:table-cell">
        <span className="text-orange-400/50">{formatTokens(claude)}</span>
        {claudeDiff > 0 && (
          <span className="text-orange-300/70 text-[10px] ml-1 token-diff">+{formatTokens(claudeDiff)}</span>
        )}
      </td>
      <td className="py-2.5 px-4 text-right font-mono text-xs hidden sm:table-cell">
        <span className="text-emerald-400/50">{formatTokens(codex)}</span>
        {codexDiff > 0 && (
          <span className="text-emerald-300/70 text-[10px] ml-1 token-diff">+{formatTokens(codexDiff)}</span>
        )}
      </td>
      <td className="py-2.5 px-4 text-right font-mono text-xs text-white/50">
        {formatNumber(points)}
        {type === "weekly" || type === "monthly" ? (
          <span className="text-white/15 ml-1 text-[10px]">
            ({entry.days_active}d)
          </span>
        ) : null}
      </td>
    </motion.tr>
  );
}

function todayString(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
