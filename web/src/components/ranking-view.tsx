"use client";

import { motion } from "motion/react";
import { BorderBeam } from "@/components/ui/border-beam";
import { TierBadge } from "@/components/shared";
import {
  type RankEntry,
  type Lang,
  formatHeroTokens,
  formatTokens,
  tokenMilestone,
  calculateLevel,
  t,
} from "@/lib/supabase";

interface RankingViewProps {
  rankings: RankEntry[];
  lang: Lang;
  totalUsers: number;
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

/** Level badge */
function LevelBadge({ level, size = "sm" }: { level: number; size?: "sm" | "lg" }) {
  const cls = size === "lg" ? "text-base px-2.5 py-0.5" : "text-xs px-2 py-0.5";
  return (
    <span className={`font-mono font-bold bg-purple-500/20 text-purple-400 rounded-md shrink-0 ${cls}`}>
      Lv.{level}
    </span>
  );
}

/** "데일리 티어" label + TierBadge */
function DailyTierLabel({ tier, division, lang }: { tier: string; division: number | null; lang: Lang }) {
  if (!tier) return null;
  return (
    <div className="flex items-center gap-1.5 shrink-0">
      <span className="text-[10px] text-white/40">
        {lang === "ko" ? "데일리" : "Daily"}
      </span>
      <TierBadge tier={tier} division={division} />
    </div>
  );
}

/** Rank indicator: #N for top 10, "상위 X%" for 11+ */
function RankIndicator({ rank, totalUsers, lang }: { rank: number; totalUsers: number; lang: Lang }) {
  if (rank <= 10) {
    return <span className="font-mono text-sm text-white/50 w-8 text-right shrink-0">#{rank}</span>;
  }
  const pct = Math.ceil((rank / totalUsers) * 100);
  return (
    <span className="text-[11px] text-white/40 w-12 text-right shrink-0 font-mono">
      {lang === "ko" ? `상위 ${pct}%` : `Top ${pct}%`}
    </span>
  );
}

/** XP progress bar to next level */
function LevelProgress({ totalTokens, lang }: { totalTokens: number; lang: Lang }) {
  const { level, currentXP, nextXP, progress } = calculateLevel(totalTokens);
  return (
    <div>
      <div className="flex items-center justify-between mb-1">
        <LevelBadge level={level} />
        <span className="text-[11px] text-white/40 font-mono">
          Lv.{level + 1} {lang === "ko" ? "까지" : "next"} {formatHeroTokens(nextXP - currentXP, lang)}
        </span>
      </div>
      <div className="w-full h-1.5 rounded-full bg-white/[0.06] overflow-hidden">
        <motion.div
          initial={{ width: 0 }}
          animate={{ width: `${Math.round(progress * 100)}%` }}
          transition={{ duration: 0.8, ease: "easeOut" }}
          className="h-full rounded-full bg-gradient-to-r from-purple-500 to-cyan-400"
        />
      </div>
    </div>
  );
}

/** Top 1 spotlight card */
function TopCard({ entry, lang }: { entry: RankEntry; lang: Lang }) {
  const tokens = entry.total_tokens ?? 0;
  const claude = entry.total_claude_tokens ?? 0;
  const codex = entry.total_codex_tokens ?? 0;
  const tier = entry.last_tier ?? "";
  const division = entry.last_division ?? null;
  const milestone = tokenMilestone(tokens, lang);
  const daysActive = entry.total_days_active ?? 0;
  const { level } = calculateLevel(tokens);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
      className="relative bg-gradient-to-br from-yellow-500/[0.06] to-purple-500/[0.04] rounded-xl border border-yellow-500/[0.15] p-6 mb-4 overflow-hidden"
    >
      <BorderBeam size={100} duration={8} colorFrom="#facc15" colorTo="#a78bfa" borderWidth={1} />

      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span className="font-mono text-2xl font-bold text-yellow-400">#1</span>
            <a
              href={`/user/${entry.nickname}`}
              className="text-xl font-bold text-white hover:text-purple-400 transition-colors cursor-pointer truncate"
            >
              {entry.nickname}
            </a>
          </div>
          <div className="flex items-center gap-3 mb-3">
            <LevelBadge level={level} size="lg" />
            <DailyTierLabel tier={tier} division={division} lang={lang} />
          </div>
          {milestone && (
            <p className="text-sm text-purple-400/70 italic mb-3">{milestone}</p>
          )}
          <div className="flex gap-4 text-sm font-mono">
            <div>
              <span className="text-orange-400/70 text-xs">Claude</span>
              <div className="text-orange-400">{formatTokens(claude)}</div>
            </div>
            <div>
              <span className="text-emerald-400/70 text-xs">Codex</span>
              <div className="text-emerald-400">{formatTokens(codex)}</div>
            </div>
          </div>
        </div>

        <div className="text-right shrink-0">
          <p className="font-mono text-3xl sm:text-4xl font-bold text-white/95 tracking-tight">
            {formatHeroTokens(tokens, lang)}
            <span className="text-base font-medium text-white/40 ml-1">Tokens</span>
          </p>
          <p className="text-xs text-white/40 mt-1">
            {daysActive}{lang === "ko" ? "일 활동" : "d active"}
          </p>
        </div>
      </div>

      <div className="mt-4">
        <LevelProgress totalTokens={tokens} lang={lang} />
      </div>
    </motion.div>
  );
}

/** Runner-up cards (2nd, 3rd) — now also shows total tokens */
function RunnerCard({ entry, lang }: { entry: RankEntry; lang: Lang }) {
  const tokens = entry.total_tokens ?? 0;
  const claude = entry.total_claude_tokens ?? 0;
  const codex = entry.total_codex_tokens ?? 0;
  const tier = entry.last_tier ?? "";
  const division = entry.last_division ?? null;
  const { level } = calculateLevel(tokens);
  const rankColors = ["", "text-slate-300", "text-amber-600"];
  const beamColors: Record<number, [string, string]> = {
    2: ["#94a3b8", "#cbd5e1"],
    3: ["#d97706", "#f59e0b"],
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay: entry.rank * 0.1 }}
      className="relative bg-white/[0.03] rounded-xl border border-white/[0.08] p-4 overflow-hidden"
    >
      <BorderBeam
        size={60}
        duration={10}
        colorFrom={beamColors[entry.rank]?.[0] ?? "#666"}
        colorTo={beamColors[entry.rank]?.[1] ?? "#999"}
        borderWidth={1}
      />
      <div className="flex items-center justify-between gap-2 mb-2">
        <div className="flex items-center gap-2 min-w-0">
          <span className={`font-mono text-lg font-bold ${rankColors[entry.rank - 1] ?? "text-white/50"}`}>
            #{entry.rank}
          </span>
          <a
            href={`/user/${entry.nickname}`}
            className="text-base font-semibold text-white/90 hover:text-purple-400 transition-colors cursor-pointer truncate"
          >
            {entry.nickname}
          </a>
          <LevelBadge level={level} />
        </div>
        <DailyTierLabel tier={tier} division={division} lang={lang} />
      </div>
      <div className="mb-2">
        <span className="font-mono text-xl font-bold text-white/90">
          {formatHeroTokens(tokens, lang)}
          <span className="text-xs font-normal text-white/40 ml-1">Tokens</span>
        </span>
        <span className="text-xs text-white/40 font-mono ml-2">
          <span className="text-orange-400/70">{formatTokens(claude)}</span>
          {" + "}
          <span className="text-emerald-400/70">{formatTokens(codex)}</span>
        </span>
      </div>
      <LevelProgress totalTokens={tokens} lang={lang} />
    </motion.div>
  );
}

/** Rank row for 4th+ — daily tier aligned right */
function RankingRow({ entry, lang, index, totalUsers }: {
  entry: RankEntry;
  lang: Lang;
  index: number;
  totalUsers: number;
}) {
  const tokens = entry.total_tokens ?? 0;
  const claude = entry.total_claude_tokens ?? 0;
  const codex = entry.total_codex_tokens ?? 0;
  const tier = entry.last_tier ?? "";
  const division = entry.last_division ?? null;
  const { level, progress } = calculateLevel(tokens);

  return (
    <motion.div
      initial={{ opacity: 0, x: -6 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.2, delay: index * 0.03 }}
      className="flex items-center gap-3 px-3 sm:px-4 py-3 hover:bg-white/[0.04] transition-colors"
    >
      <RankIndicator rank={entry.rank} totalUsers={totalUsers} lang={lang} />

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <a
            href={`/user/${entry.nickname}`}
            className="text-sm font-medium text-white/90 hover:text-purple-400 transition-colors cursor-pointer truncate"
          >
            {entry.nickname}
          </a>
          <LevelBadge level={level} />
        </div>
        <div className="flex items-center gap-2 mt-1">
          <div className="flex-1 h-1 rounded-full bg-white/[0.06] overflow-hidden max-w-32">
            <div
              className="h-full rounded-full bg-gradient-to-r from-purple-500 to-cyan-400"
              style={{ width: `${Math.round(progress * 100)}%` }}
            />
          </div>
          <span className="text-[11px] text-white/40 font-mono hidden sm:inline">
            <span className="text-orange-400/60">{formatTokens(claude)}</span>
            {" + "}
            <span className="text-emerald-400/60">{formatTokens(codex)}</span>
          </span>
        </div>
      </div>

      {/* Token total + daily tier — right aligned */}
      <div className="flex items-center gap-3 shrink-0">
        <div className="text-right">
          <span className="font-mono text-sm sm:text-base font-bold text-white/90">
            {formatHeroTokens(tokens, lang)}
            <span className="text-[10px] font-normal text-white/35 ml-0.5">Tokens</span>
          </span>
        </div>
        <DailyTierLabel tier={tier} division={division} lang={lang} />
      </div>
    </motion.div>
  );
}

export function RankingView({ rankings, lang, totalUsers }: RankingViewProps) {
  if (!rankings.length) {
    return (
      <div className="flex items-center justify-center py-24 text-white/20 text-sm">
        {t("no_data", lang)}
      </div>
    );
  }

  const communityTokens = rankings.reduce((s, r) => s + (r.total_tokens ?? 0), 0);

  const top1 = rankings[0];
  const runners = rankings.slice(1, 3);
  const rest = rankings.slice(3);

  return (
    <div>
      {/* Community hero */}
      <motion.div
        initial={{ opacity: 0, y: -8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="mb-6 text-center"
      >
        <p className="text-xs text-white/40 uppercase tracking-widest mb-1">
          {lang === "ko" ? "커뮤니티 총 토큰" : "Community Total Tokens"}
        </p>
        <p className="font-mono text-3xl sm:text-4xl font-bold text-white/95 tracking-tight">
          {formatHeroTokens(communityTokens, lang)}
          <span className="text-base font-medium text-white/40 ml-1">Tokens</span>
        </p>
        <p className="text-xs text-white/40 mt-1">
          {totalUsers}{lang === "ko" ? "명의 Vanguard" : " Vanguards"}
        </p>
      </motion.div>

      {/* #1 */}
      <TopCard entry={top1} lang={lang} />

      {/* #2, #3 */}
      {runners.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
          {runners.map((e) => (
            <RunnerCard key={e.nickname} entry={e} lang={lang} />
          ))}
        </div>
      )}

      {/* 4th+ */}
      {rest.length > 0 && (
        <div className="bg-white/[0.02] rounded-xl border border-white/[0.06] overflow-hidden divide-y divide-white/[0.03]">
          {rest.map((entry, i) => (
            <RankingRow key={entry.nickname} entry={entry} lang={lang} index={i} totalUsers={totalUsers} />
          ))}
        </div>
      )}
    </div>
  );
}
