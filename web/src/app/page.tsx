"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { NumberTicker } from "@/components/ui/number-ticker";
import { BorderBeam } from "@/components/ui/border-beam";
import { SparklesText } from "@/components/ui/sparkles-text";
import { AnimatedGradientText } from "@/components/ui/animated-gradient-text";
import {
  fetchLeaderboard,
  supabase,
  type LeaderboardType,
  type LeaderboardResponse,
  type RankEntry,
  type Lang,
  formatTokens,
  formatNumber,
  vanguardMessage,
  tokenMilestone,
  t,
} from "@/lib/supabase";

const TABS: { key: LeaderboardType; ko: string; en: string }[] = [
  { key: "realtime", ko: "실시간", en: "Live" },
  { key: "daily", ko: "일간", en: "Daily" },
  { key: "weekly", ko: "주간", en: "Weekly" },
  { key: "monthly", ko: "월간", en: "Monthly" },
  { key: "total", ko: "전체", en: "All-time" },
];

// Tier badge colors for backgrounds
const TIER_BG: Record<string, string> = {
  Bronze: "bg-amber-900/25 text-amber-500 border-amber-700/40",
  Silver: "bg-slate-700/25 text-slate-200 border-slate-500/40",
  Gold: "bg-yellow-900/25 text-yellow-300 border-yellow-600/40",
  Platinum: "bg-cyan-900/25 text-cyan-300 border-cyan-600/40",
  Diamond: "bg-blue-900/25 text-blue-300 border-blue-600/40",
  Master: "bg-purple-900/25 text-purple-300 border-purple-600/40",
  Grandmaster: "bg-red-900/25 text-red-300 border-red-600/40",
  Challenger: "bg-orange-900/25 text-orange-300 border-orange-600/40",
};

function TierBadge({ tier, division }: { tier: string; division: number | null }) {
  const cls = TIER_BG[tier] ?? "bg-gray-800/20 text-gray-400 border-gray-700/30";
  if (tier === "Challenger") {
    return (
      <SparklesText
        sparklesCount={6}
        colors={{ first: "#facc15", second: "#fb923c" }}
        className="text-xs font-bold"
      >
        Challenger
      </SparklesText>
    );
  }
  return (
    <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded text-sm font-medium border ${cls}`}>
      {tier}{division != null && ` ${division}`}
    </span>
  );
}

// Countdown ring SVG
// Top 3 podium card
function PodiumCard({ entry, lang, diff }: {
  entry: RankEntry;
  lang: Lang;
  diff?: { claude: number; codex: number };
}) {
  const tier = entry.vanguard_tier ?? entry.last_tier ?? "";
  const division = entry.vanguard_division ?? entry.last_division ?? null;
  const points = entry.daily_points ?? entry.period_points ?? entry.total_points ?? 0;
  const claude = entry.claude_tokens ?? 0;
  const codex = entry.codex_tokens ?? 0;
  const message = vanguardMessage(tier, division, lang);
  const milestone = tokenMilestone(claude + codex, lang);
  const claudeDiff = diff?.claude ?? 0;
  const codexDiff = diff?.codex ?? 0;

  const podiumClass =
    entry.rank === 1 ? "podium-card podium-gold" :
    entry.rank === 2 ? "podium-card podium-silver" :
    "podium-card podium-bronze";

  const rankColors = ["text-yellow-400", "text-slate-300", "text-amber-600"];
  const rankLabels = ["1st", "2nd", "3rd"];
  const beamColors: [string, string][] = [
    ["#facc15", "#fbbf24"],  // gold
    ["#94a3b8", "#cbd5e1"],  // silver
    ["#d97706", "#f59e0b"],  // bronze
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: entry.rank * 0.1 }}
      className={`${podiumClass} relative`}
    >
      <BorderBeam
        size={80}
        duration={8}
        colorFrom={beamColors[entry.rank - 1][0]}
        colorTo={beamColors[entry.rank - 1][1]}
        borderWidth={1}
      />

      {/* Rank + Name */}
      <div className="flex items-start justify-between mb-3">
        <div>
          <span className={`font-mono text-3xl font-bold ${rankColors[entry.rank - 1]}`}>
            {rankLabels[entry.rank - 1]}
          </span>
          <a
            href={`/user/${entry.nickname}`}
            className="block text-base font-semibold mt-1 hover:text-purple-400 transition-colors cursor-pointer"
          >
            {entry.nickname}
          </a>
        </div>
        <TierBadge tier={tier} division={division} />
      </div>

      {/* Vanguard message */}
      {message && (
        <p className="text-sm text-white/50 italic mb-3 leading-relaxed">{message}</p>
      )}

      {/* Points */}
      <div className="font-mono text-xl font-bold tracking-tight mb-2">
        <NumberTicker value={points} className="text-xl font-bold text-white" />{" "}
        <span className="text-sm font-normal text-white/50">{lang === "ko" ? "점" : "pts"}</span>
      </div>

      {/* Token bars */}
      <div className="flex gap-3 text-sm font-mono">
        <div className="flex-1">
          <div className="text-orange-400/70 text-xs mb-0.5">Claude</div>
          <div className="text-orange-400">
            {formatTokens(claude)}
            {claudeDiff > 0 && <span className="text-orange-300 text-xs ml-1 token-diff">+{formatTokens(claudeDiff)}</span>}
          </div>
        </div>
        <div className="flex-1">
          <div className="text-emerald-400/70 text-xs mb-0.5">Codex</div>
          <div className="text-emerald-400">
            {formatTokens(codex)}
            {codexDiff > 0 && <span className="text-emerald-300 text-xs ml-1 token-diff">+{formatTokens(codexDiff)}</span>}
          </div>
        </div>
      </div>

      {/* Milestone */}
      {milestone && (
        <p className="text-xs text-purple-400/70 mt-3 truncate">{milestone}</p>
      )}
    </motion.div>
  );
}

export default function Home() {
  const [tab, setTab] = useState<LeaderboardType>("realtime");
  const [data, setData] = useState<LeaderboardResponse | null>(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [dateInput, setDateInput] = useState(yesterdayString());
  const [search, setSearch] = useState("");
  const [lang, setLang] = useState<Lang>("en");
  const [diffs, setDiffs] = useState<Record<string, { claude: number; codex: number }>>({});
  const dataRef = useRef<LeaderboardResponse | null>(null);

  const load = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    const params: Record<string, string> = {};
    if (tab === "daily") params.date = dateInput;
    const result = await fetchLeaderboard(tab, params, page);

    // diff 계산: 변경분 감지 → 다음 변경까지 유지
    if (dataRef.current?.rankings && result?.rankings) {
      const oldMap: Record<string, { claude: number; codex: number }> = {};
      for (const r of dataRef.current.rankings) {
        oldMap[r.nickname] = { claude: r.claude_tokens ?? 0, codex: r.codex_tokens ?? 0 };
      }
      const newDiffs: Record<string, { claude: number; codex: number }> = {};
      let hasDiff = false;
      for (const r of result.rankings) {
        const old = oldMap[r.nickname];
        if (!old) continue;
        const cDiff = (r.claude_tokens ?? 0) - old.claude;
        const xDiff = (r.codex_tokens ?? 0) - old.codex;
        if (cDiff > 0 || xDiff > 0) {
          newDiffs[r.nickname] = { claude: cDiff, codex: xDiff };
          hasDiff = true;
        }
      }
      setDiffs(hasDiff ? newDiffs : {});
    }

    dataRef.current = result;
    setData(result);
    if (!silent) setLoading(false);
  }, [tab, page, dateInput]);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (tab !== "realtime") return;
    const channel = supabase
      .channel("leaderboard-realtime")
      .on("postgres_changes", { event: "*", schema: "public", table: "daily_records" }, () => { load(true); })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
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
          <h1 className="text-3xl font-bold tracking-tight">
            <AnimatedGradientText
              colorFrom="#a78bfa"
              colorTo="#22d3ee"
              speed={1.5}
              className="text-3xl font-bold"
            >
              Vanguard
            </AnimatedGradientText>{" "}
            <span className="text-white/90">Leaderboard</span>
          </h1>
          <p className="text-white/50 text-sm mt-1.5 tracking-wide">
            {data ? `${formatNumber(data.total_users)} ${t("vanguards_competing", lang)}` : t("connecting", lang)}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setLang((l) => (l === "en" ? "ko" : "en"))}
            className="px-3 py-1.5 bg-white/[0.04] border border-white/[0.08] rounded-md text-sm font-medium text-white/60 hover:text-white/90 hover:bg-white/[0.08] transition-all cursor-pointer"
          >
            {lang === "en" ? "KR" : "EN"}
          </button>
        </div>
      </motion.div>

      {/* Tabs */}
      <div className="flex gap-0.5 mb-8 bg-white/[0.02] rounded-lg p-0.5 w-fit border border-white/[0.04]">
        {TABS.map((item) => (
          <button
            key={item.key}
            onClick={() => { setTab(item.key); setPage(1); }}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-all cursor-pointer ${
              tab === item.key
                ? "bg-white/[0.08] text-white shadow-sm"
                : "text-white/50 hover:text-white/80"
            }`}
          >
            {lang === "ko" ? item.ko : item.en}
            {item.key === "realtime" && tab === item.key && (
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
            placeholder={t("search", lang)}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="bg-white/[0.02] border border-white/[0.06] rounded-md pl-8 pr-3 py-2 text-sm w-60 focus:outline-none focus:border-cyan-500/30 text-white/70 placeholder:text-white/20 transition-colors"
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
            {t("loading", lang)}
          </div>
        </div>
      ) : !filteredRankings?.length ? (
        <div className="flex items-center justify-center py-24 text-white/15 text-sm">
          {t("no_data", lang)}
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
                  diff={diffs[entry.nickname]}
                />
              ))}
            </div>
          )}

          {/* Rest of rankings */}
          {rest.length > 0 && (
            <div className="bg-white/[0.04] rounded-xl border border-white/[0.08] overflow-hidden">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/[0.08] text-white/70 text-xs uppercase tracking-[0.15em]">
                    <th className="text-left py-3 px-5 w-14">#</th>
                    <th className="text-left py-3 px-5">Vanguard</th>
                    <th className="text-left py-3 px-5">{t("tier", lang)}</th>
                    <th className="text-right py-3 px-5 hidden sm:table-cell">
                      <span className="text-orange-400/80">Claude</span>
                    </th>
                    <th className="text-right py-3 px-5 hidden sm:table-cell">
                      <span className="text-emerald-400/80">Codex</span>
                    </th>
                    <th className="text-right py-3 px-5">{t("pts", lang)}</th>
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
                        diff={diffs[entry.nickname]}
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
            className="px-4 py-2 bg-white/[0.03] border border-white/[0.06] rounded-md text-sm disabled:opacity-20 hover:bg-white/[0.06] transition-colors cursor-pointer"
          >
            {t("prev", lang)}
          </button>
          <span className="px-3 py-2 text-sm text-white/30 font-mono">
            {page} / {data.total_pages}
          </span>
          <button
            onClick={() => setPage((p) => Math.min(data.total_pages, p + 1))}
            disabled={page >= data.total_pages}
            className="px-4 py-2 bg-white/[0.03] border border-white/[0.06] rounded-md text-sm disabled:opacity-20 hover:bg-white/[0.06] transition-colors cursor-pointer"
          >
            {t("next", lang)}
          </button>
        </div>
      )}
    </div>
  );
}

function RankRow({ entry, type, lang, diff, index }: {
  entry: RankEntry;
  type: LeaderboardType;
  lang: Lang;
  diff?: { claude: number; codex: number };
  index: number;
}) {
  const tier = entry.vanguard_tier ?? entry.best_tier ?? entry.last_tier ?? "";
  const division = entry.vanguard_division ?? entry.last_division ?? null;
  const points = entry.daily_points ?? entry.period_points ?? entry.total_points ?? 0;
  const claude = entry.claude_tokens ?? 0;
  const codex = entry.codex_tokens ?? 0;
  const message = vanguardMessage(tier, division, lang);
  const milestone = tokenMilestone(claude + codex, lang);
  const claudeDiff = diff?.claude ?? 0;
  const codexDiff = diff?.codex ?? 0;

  return (
    <motion.tr
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.2, delay: index * 0.02 }}
      className="border-b border-white/[0.04] hover:bg-white/[0.04] transition-colors group"
    >
      <td className="py-3 px-5">
        <span className="font-mono text-sm text-white/70">
          {entry.rank}
        </span>
      </td>
      <td className="py-3 px-5">
        <div>
          <a
            href={`/user/${entry.nickname}`}
            className="text-base text-white/90 group-hover:text-white transition-colors cursor-pointer"
          >
            {entry.nickname}
          </a>
          {milestone && (
            <p className="text-xs text-purple-400/70 mt-0.5">{milestone}</p>
          )}
        </div>
      </td>
      <td className="py-3 px-5">
        <div>
          <TierBadge tier={tier} division={division} />
          {message && (
            <p className="text-xs text-white/45 mt-0.5 italic">{message}</p>
          )}
        </div>
      </td>
      <td className="py-3 px-5 text-right font-mono text-sm hidden sm:table-cell">
        <span className="text-orange-400">{formatTokens(claude)}</span>
        {claudeDiff > 0 && (
          <span className="text-orange-300 text-xs ml-1 token-diff">+{formatTokens(claudeDiff)}</span>
        )}
      </td>
      <td className="py-3 px-5 text-right font-mono text-sm hidden sm:table-cell">
        <span className="text-emerald-400">{formatTokens(codex)}</span>
        {codexDiff > 0 && (
          <span className="text-emerald-300 text-xs ml-1 token-diff">+{formatTokens(codexDiff)}</span>
        )}
      </td>
      <td className="py-3 px-5 text-right font-mono text-sm text-white/90">
        {formatNumber(points)}
        {type === "weekly" || type === "monthly" ? (
          <span className="text-white/45 ml-1 text-xs">
            ({entry.days_active}{lang === "ko" ? "일" : "d"})
          </span>
        ) : null}
      </td>
    </motion.tr>
  );
}

function yesterdayString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
