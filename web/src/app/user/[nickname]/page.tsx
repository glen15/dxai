"use client";

import { useState, useEffect, use } from "react";
import { motion } from "motion/react";
import { NumberTicker } from "@/components/ui/number-ticker";
import { BorderBeam } from "@/components/ui/border-beam";
import {
  fetchUserProfile,
  type UserProfile,
  formatTokens,
  formatNumber,
  vanguardMessage,
  tokenMilestone,
  t,
  type Lang,
} from "@/lib/supabase";

// 메인 페이지와 동일한 TierBadge
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

function TierBadge({ tier, division, size = "sm" }: { tier: string; division: number | null; size?: "sm" | "lg" }) {
  const cls = TIER_BG[tier] ?? "bg-gray-800/20 text-gray-400 border-gray-700/30";
  const sizeClass = size === "lg" ? "px-4 py-1.5 text-base" : "px-2.5 py-1 text-sm";
  return (
    <span className={`inline-flex items-center gap-1 rounded font-medium border ${sizeClass} ${cls}`}>
      {tier}{division != null && ` ${division}`}
    </span>
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
        <div className="flex items-center gap-3 text-white/20 text-sm">
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
        <p className="text-white/40">{error}</p>
        <a href="/" className="text-purple-400 hover:text-purple-300 mt-4 inline-block transition-colors">
          &larr; {t("back", lang)}
        </a>
      </div>
    );
  }

  const tier = profile.last_tier ?? "";
  const division = profile.last_division;
  const message = vanguardMessage(tier, division, lang);
  const totalTokens = (profile.weekly.claude_tokens ?? 0) + (profile.weekly.codex_tokens ?? 0);
  const milestone = tokenMilestone(totalTokens, lang);

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
    >
      {/* Top bar */}
      <div className="flex items-center justify-between mb-6">
        <a href="/" className="text-sm text-white/40 hover:text-white/70 transition-colors">
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
              <TierBadge tier={tier} division={division} size="lg" />
            </div>
            {message && (
              <p className="text-sm text-white/50 italic mt-2">{message}</p>
            )}
            <p className="text-sm text-white/30 mt-2">
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
            <div className="text-sm text-white/40">
              {lang === "ko"
                ? `${formatNumber(profile.total_users)}명 중`
                : `of ${formatNumber(profile.total_users)} vanguards`}
            </div>
          </div>
        </div>
      </motion.div>

      {/* Stats Grid */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.2 }}
        className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6"
      >
        <StatCard label={t("total_points", lang)} value={profile.total_points} />
        <StatCard label={t("total_coins", lang)} value={profile.total_coins} accent="text-yellow-400" />
        <StatCard label={t("weekly_points", lang)} value={profile.weekly.points} sub={`${profile.weekly.days_active}${t("d_active", lang)}`} />
        <StatCard label={t("monthly_points", lang)} value={profile.monthly.points} sub={`${profile.monthly.days_active}${t("d_active", lang)}`} />
      </motion.div>

      {/* Token Usage */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.3 }}
        className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-8"
      >
        <div className="bg-white/[0.03] rounded-xl border border-white/[0.08] p-5">
          <h3 className="text-sm text-white/40 mb-3">{t("weekly_tokens", lang)}</h3>
          <div className="flex justify-between mb-2">
            <span className="text-orange-400/70">Claude</span>
            <span className="font-mono text-orange-400">{formatTokens(profile.weekly.claude_tokens)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-emerald-400/70">Codex</span>
            <span className="font-mono text-emerald-400">{formatTokens(profile.weekly.codex_tokens)}</span>
          </div>
        </div>
        <div className="bg-white/[0.03] rounded-xl border border-white/[0.08] p-5">
          <h3 className="text-sm text-white/40 mb-3">{t("monthly_tokens", lang)}</h3>
          <div className="flex justify-between mb-2">
            <span className="text-orange-400/70">Claude</span>
            <span className="font-mono text-orange-400">{formatTokens(profile.monthly.claude_tokens)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-emerald-400/70">Codex</span>
            <span className="font-mono text-emerald-400">{formatTokens(profile.monthly.codex_tokens)}</span>
          </div>
        </div>
      </motion.div>

      {/* Milestone */}
      {milestone && (
        <p className="text-sm text-purple-400/70 mb-6 italic">{milestone}</p>
      )}

      {/* 30-Day History */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.4 }}
      >
        <h2 className="text-lg font-bold mb-4 text-white/90">{t("history_30d", lang)}</h2>
        <div className="bg-white/[0.04] rounded-xl border border-white/[0.08] overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/[0.08] text-white/50 text-xs uppercase tracking-[0.15em]">
                <th className="text-left py-3 px-5">{t("date", lang)}</th>
                <th className="text-left py-3 px-5">{t("tier", lang)}</th>
                <th className="text-right py-3 px-5">{t("points", lang)}</th>
                <th className="text-right py-3 px-5 hidden sm:table-cell">
                  <span className="text-orange-400/80">Claude</span>
                </th>
                <th className="text-right py-3 px-5 hidden sm:table-cell">
                  <span className="text-emerald-400/80">Codex</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {profile.history.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center py-8 text-white/20">{t("no_history", lang)}</td>
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
                    <td className="py-3 px-5 text-right font-mono text-sm text-white/90">
                      {formatNumber(day.daily_points)}
                    </td>
                    <td className="py-3 px-5 text-right font-mono text-sm text-orange-400 hidden sm:table-cell">
                      {formatTokens(day.claude_tokens)}
                    </td>
                    <td className="py-3 px-5 text-right font-mono text-sm text-emerald-400 hidden sm:table-cell">
                      {formatTokens(day.codex_tokens)}
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

function StatCard({ label, value, sub, accent }: { label: string; value: number; sub?: string; accent?: string }) {
  return (
    <div className="bg-white/[0.03] rounded-xl border border-white/[0.08] p-4">
      <div className="text-xs text-white/40 mb-1">{label}</div>
      <div className={`text-2xl font-bold ${accent ?? "text-white"}`}>
        <NumberTicker value={value} className={`text-2xl font-bold ${accent ?? "text-white"}`} />
      </div>
      {sub && <div className="text-xs text-white/30 mt-1">{sub}</div>}
    </div>
  );
}
