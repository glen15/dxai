"use client";

import { useState, useEffect, use } from "react";
import { motion } from "motion/react";
import { NumberTicker } from "@/components/ui/number-ticker";
import { BorderBeam } from "@/components/ui/border-beam";
import { TierBadge } from "@/components/shared";
import {
  fetchUserProfile,
  type UserProfile,
  formatTokens,
  formatNumber,
  formatHeroTokens,
  vanguardMessage,
  tokenMilestone,
  calculateLevel,
  t,
  type Lang,
} from "@/lib/supabase";

/** SVG donut pie chart for Claude vs Codex ratio */
function TokenPieChart({ claude, codex, lang }: { claude: number; codex: number; lang: Lang }) {
  const total = claude + codex;
  if (total === 0) return null;

  const claudePct = (claude / total) * 100;
  const codexPct = (codex / total) * 100;

  // SVG donut: stroke-dasharray trick
  const radius = 40;
  const circumference = 2 * Math.PI * radius;
  const claudeArc = (claudePct / 100) * circumference;
  const codexArc = (codexPct / 100) * circumference;

  return (
    <div className="flex items-center gap-5">
      <div className="relative w-24 h-24 shrink-0">
        <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
          {/* Codex (background ring) */}
          <circle
            cx="50" cy="50" r={radius}
            fill="none"
            stroke="rgb(52, 211, 153)"
            strokeWidth="12"
            strokeDasharray={`${codexArc} ${circumference - codexArc}`}
            strokeDashoffset={-claudeArc}
            className="opacity-70"
          />
          {/* Claude (foreground ring) */}
          <circle
            cx="50" cy="50" r={radius}
            fill="none"
            stroke="rgb(251, 146, 60)"
            strokeWidth="12"
            strokeDasharray={`${claudeArc} ${circumference - claudeArc}`}
            className="opacity-80"
          />
        </svg>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-[11px] font-mono text-white/50">{formatHeroTokens(total, lang)}</span>
        </div>
      </div>
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <span className="w-2.5 h-2.5 rounded-full bg-orange-400 shrink-0" />
          <span className="text-sm text-white/70">Claude</span>
          <span className="font-mono text-sm text-orange-400 ml-auto">{formatTokens(claude)}</span>
          <span className="text-xs text-white/40 w-10 text-right">{Math.round(claudePct)}%</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 shrink-0" />
          <span className="text-sm text-white/70">Codex</span>
          <span className="font-mono text-sm text-emerald-400 ml-auto">{formatTokens(codex)}</span>
          <span className="text-xs text-white/40 w-10 text-right">{Math.round(codexPct)}%</span>
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, sub, accent }: { label: string; value: number; sub?: string; accent?: string }) {
  return (
    <div className="bg-white/[0.03] rounded-xl border border-white/[0.08] p-4">
      <div className="text-xs text-white/50 mb-1">{label}</div>
      <div className={`text-2xl font-bold ${accent ?? "text-white"}`}>
        <NumberTicker value={value} className={`text-2xl font-bold ${accent ?? "text-white"}`} />
      </div>
      {sub && <div className="text-xs text-white/40 mt-1">{sub}</div>}
    </div>
  );
}

export default function UserPage({ params }: { params: Promise<{ nickname: string }> }) {
  const { nickname } = use(params);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [lang, setLang] = useState<Lang>("en");

  useEffect(() => {
    fetchUserProfile(nickname).then((res) => {
      if (res.ok && res.profile) {
        setProfile(res.profile);
      } else {
        setError(res.error ?? "User not found");
      }
      setLoading(false);
    });
  }, [nickname]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="flex items-center gap-3 text-white/30 text-sm">
          <svg className="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" strokeOpacity="0.2" />
            <path d="M12 2a10 10 0 019.95 9" />
          </svg>
          {t("loading", lang)}
        </div>
      </div>
    );
  }

  if (error || !profile) {
    return (
      <div className="text-center py-20">
        <h1 className="text-2xl font-bold mb-2 text-white/90">{t("user_not_found", lang)}</h1>
        <p className="text-white/50">{error}</p>
        <a href="/" className="text-purple-400 hover:text-purple-300 mt-4 inline-block transition-colors">
          &larr; {t("back", lang)}
        </a>
      </div>
    );
  }

  const tier = profile.last_tier ?? "";
  const division = profile.last_division;
  const message = vanguardMessage(tier, division, lang);

  // Monthly tokens (last 30 days)
  const monthlyClaudeTokens = profile.monthly.claude_tokens;
  const monthlyCodexTokens = profile.monthly.codex_tokens;
  const monthlyTotalTokens = monthlyClaudeTokens + monthlyCodexTokens;
  // All-time cumulative tokens (for level calculation)
  const allTimeTotalTokens = profile.total_tokens ?? monthlyTotalTokens;

  const milestone = tokenMilestone(allTimeTotalTokens, lang);
  const { level, progress, currentXP, nextXP } = calculateLevel(allTimeTotalTokens);

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
    >
      {/* Top bar */}
      <div className="flex items-center justify-between mb-6">
        <a href="/" className="text-sm text-white/50 hover:text-white/80 transition-colors">
          &larr; {t("back", lang)}
        </a>
        <button
          onClick={() => setLang((l) => (l === "en" ? "ko" : "en"))}
          className="px-3 py-1.5 bg-white/[0.04] border border-white/[0.08] rounded-md text-sm font-medium text-white/60 hover:text-white/90 hover:bg-white/[0.08] transition-all cursor-pointer"
        >
          {lang === "en" ? "KR" : "EN"}
        </button>
      </div>

      {/* Profile Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.1 }}
        className="relative bg-white/[0.03] rounded-xl border border-white/[0.08] p-6 mb-6 overflow-hidden"
      >
        <BorderBeam size={100} duration={10} colorFrom="#a78bfa" colorTo="#22d3ee" borderWidth={1} />
        <div className="flex items-start justify-between flex-wrap gap-4">
          <div>
            <h1 className="text-3xl font-bold mb-2 text-white">{profile.nickname}</h1>
            <div className="flex items-center gap-3 mb-2">
              <span className="font-mono font-bold bg-purple-500/20 text-purple-400 rounded-md text-lg px-3 py-0.5">
                Lv.{level}
              </span>
              <div className="flex items-center gap-1.5">
                <span className="text-[11px] text-white/40">
                  {lang === "ko" ? "데일리" : "Daily"}
                </span>
                <TierBadge tier={tier} division={division} size="lg" />
              </div>
            </div>
            {message && (
              <p className="text-sm text-white/60 italic mt-2">{message}</p>
            )}
            <p className="text-sm text-white/45 mt-2">
              {t("member_since", lang)} {new Date(profile.member_since).toLocaleDateString(lang === "ko" ? "ko-KR" : "en-US")}
              {profile.streak > 0 && (
                <span className="ml-3 text-orange-400 font-medium">
                  {profile.streak}{t("day_streak", lang)}
                </span>
              )}
            </p>
          </div>
          <div className="text-right">
            <div className="text-4xl font-bold text-purple-400">
              #<NumberTicker value={profile.rank} className="text-4xl font-bold text-purple-400" />
            </div>
            <div className="text-sm text-white/50">
              {lang === "ko"
                ? `${formatNumber(profile.total_users)}명 중`
                : `of ${formatNumber(profile.total_users)} vanguards`}
            </div>
          </div>
        </div>

        {/* Level progress bar */}
        <div className="mt-4">
          <div className="flex items-center justify-between mb-1">
            <span className="text-[11px] text-white/40 font-mono">
              {formatHeroTokens(allTimeTotalTokens, lang)} {lang === "ko" ? "토큰" : "tokens"}
            </span>
            <span className="text-[11px] text-white/40 font-mono">
              Lv.{level + 1} {lang === "ko" ? "까지" : "next"} {formatHeroTokens(nextXP - currentXP, lang)}
            </span>
          </div>
          <div className="w-full h-2 rounded-full bg-white/[0.06] overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${Math.round(progress * 100)}%` }}
              transition={{ duration: 1, ease: "easeOut" }}
              className="h-full rounded-full bg-gradient-to-r from-purple-500 to-cyan-400"
            />
          </div>
        </div>
      </motion.div>

      {/* Stats Grid — Level, Total Tokens, Coins (no points) */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.2 }}
        className="grid grid-cols-3 gap-3 mb-6"
      >
        <StatCard
          label={lang === "ko" ? "계정 레벨" : "Account Level"}
          value={level}
          accent="text-purple-400"
        />
        <StatCard
          label={lang === "ko" ? "총 토큰" : "Total Tokens"}
          value={allTimeTotalTokens}
          sub={formatHeroTokens(allTimeTotalTokens, lang)}
        />
        <StatCard
          label={lang === "ko" ? "코인" : "Coins"}
          value={profile.total_coins}
          accent="text-yellow-400"
        />
      </motion.div>

      {/* Coin notice */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3 }}
        className="text-[11px] text-white/30 mb-6 -mt-3 px-1"
      >
        {lang === "ko"
          ? "코인은 추후 다양한 기능에서 사용될 예정입니다"
          : "Coins will be usable for various features in the future"}
      </motion.p>

      {/* Token Usage — Pie Chart */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.3 }}
        className="bg-white/[0.03] rounded-xl border border-white/[0.08] p-5 mb-4"
      >
        <h3 className="text-sm font-medium text-white/60 mb-4">
          {lang === "ko" ? "AI 도구별 토큰 사용 비율" : "Token Usage by AI Tool"}
        </h3>
        <TokenPieChart
          claude={monthlyClaudeTokens}
          codex={monthlyCodexTokens}
          lang={lang}
        />
      </motion.div>

      {/* Upcoming tools notice */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.4 }}
        className="text-[11px] text-white/30 mb-6 px-1"
      >
        {lang === "ko"
          ? "Gemini, Grok 등 다른 AI 구독 서비스도 추가 지원 예정입니다"
          : "Support for Gemini, Grok, and other AI subscriptions coming soon"}
      </motion.p>

      {/* Milestone */}
      {milestone && (
        <p className="text-sm text-purple-400/70 mb-6 italic">{milestone}</p>
      )}

      {/* 30-Day History */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.5 }}
      >
        <h2 className="text-lg font-bold mb-4 text-white/90">{t("history_30d", lang)}</h2>
        <div className="bg-white/[0.04] rounded-xl border border-white/[0.08] overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/[0.08] text-white/60 text-xs uppercase tracking-[0.15em]">
                <th className="text-left py-3 px-5">{t("date", lang)}</th>
                <th className="text-left py-3 px-5">{lang === "ko" ? "데일리 티어" : "Daily Tier"}</th>
                <th className="text-right py-3 px-5 hidden sm:table-cell">
                  <span className="text-orange-400/80">Claude</span>
                </th>
                <th className="text-right py-3 px-5 hidden sm:table-cell">
                  <span className="text-emerald-400/80">Codex</span>
                </th>
                <th className="text-right py-3 px-5">
                  {lang === "ko" ? "합계" : "Total"}
                </th>
              </tr>
            </thead>
            <tbody>
              {profile.history.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center py-8 text-white/30">{t("no_history", lang)}</td>
                </tr>
              ) : (
                profile.history.map((day, i) => (
                  <motion.tr
                    key={day.date}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: 0.2, delay: i * 0.03 }}
                    className="border-b border-white/[0.04] hover:bg-white/[0.04] transition-colors"
                  >
                    <td className="py-3 px-5 text-sm text-white/60 font-mono">{day.date}</td>
                    <td className="py-3 px-5">
                      <TierBadge tier={day.vanguard_tier} division={day.vanguard_division} />
                    </td>
                    <td className="py-3 px-5 text-right font-mono text-sm text-orange-400 hidden sm:table-cell">
                      {formatTokens(day.claude_tokens)}
                    </td>
                    <td className="py-3 px-5 text-right font-mono text-sm text-emerald-400 hidden sm:table-cell">
                      {formatTokens(day.codex_tokens)}
                    </td>
                    <td className="py-3 px-5 text-right font-mono text-sm text-white/80">
                      {formatTokens(day.claude_tokens + day.codex_tokens)}
                    </td>
                  </motion.tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </motion.div>
    </motion.div>
  );
}
