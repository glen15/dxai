"use client";

import { useState, useEffect } from "react";
import { motion } from "motion/react";
import {
  fetchAchievements,
  type Achievement,
  type Lang,
  t,
} from "@/lib/supabase";

const RARITY_STYLES: Record<string, { border: string; bg: string; text: string; glow: string }> = {
  common:    { border: "border-white/10",     bg: "bg-white/[0.03]",     text: "text-white/50",   glow: "" },
  uncommon:  { border: "border-green-500/30", bg: "bg-green-500/[0.06]", text: "text-green-400",  glow: "" },
  rare:      { border: "border-blue-500/30",  bg: "bg-blue-500/[0.06]",  text: "text-blue-400",   glow: "shadow-blue-500/10 shadow-lg" },
  legendary: { border: "border-amber-500/30", bg: "bg-amber-500/[0.06]", text: "text-amber-400",  glow: "shadow-amber-500/10 shadow-lg" },
};

const CATEGORY_LABELS: Record<string, [string, string]> = {
  token:   ["토큰", "Token"],
  tier:    ["티어", "Tier"],
  streak:  ["연속", "Streak"],
  days:    ["활동일", "Days"],
  coins:   ["코인", "Coins"],
  special: ["스페셜", "Special"],
};

const CATEGORY_ORDER = ["token", "tier", "streak", "days", "coins", "special"];

function AchievementCard({ a, lang }: { a: Achievement; lang: Lang }) {
  const style = RARITY_STYLES[a.rarity] ?? RARITY_STYLES.common;
  const name = lang === "ko" ? a.name_ko : a.name_en;
  const desc = lang === "ko" ? a.desc_ko : a.desc_en;
  const rate = a.total_users && a.total_users > 0
    ? Math.round(((a.achieved_count ?? 0) / a.total_users) * 100)
    : 0;

  return (
    <div className={`rounded-xl border ${style.border} ${style.bg} ${style.glow} p-4 relative`}>
      <div className="flex items-start gap-3">
        <span className="text-3xl shrink-0">{a.icon}</span>
        <div className="min-w-0 flex-1">
          <div className="text-sm font-semibold text-white/90">{name}</div>
          <div className="text-xs text-white/40 mt-0.5">{desc}</div>
        </div>
      </div>
      <div className="flex items-center justify-between mt-3">
        <span className={`text-[10px] uppercase font-bold tracking-wider ${style.text}`}>
          {a.rarity}
        </span>
        <div className="flex items-center gap-2">
          <div className="w-16 h-1.5 rounded-full bg-white/[0.06] overflow-hidden">
            <div
              className="h-full rounded-full bg-purple-500/60 transition-all duration-500"
              style={{ width: `${rate}%` }}
            />
          </div>
          <span className="text-[10px] font-mono text-white/30">
            {rate}%
          </span>
        </div>
      </div>
    </div>
  );
}

export default function AchievementsPage() {
  const [achievements, setAchievements] = useState<Achievement[]>([]);
  const [loading, setLoading] = useState(true);
  const [lang, setLang] = useState<Lang>("ko");

  useEffect(() => {
    const saved = localStorage.getItem("lang");
    if (saved === "ko" || saved === "en") setLang(saved);
  }, []);

  useEffect(() => {
    fetchAchievements().then((res) => {
      if (res.ok) setAchievements(res.achievements);
      setLoading(false);
    });
  }, []);

  const grouped = CATEGORY_ORDER.reduce<Record<string, Achievement[]>>((acc, cat) => {
    acc[cat] = achievements.filter((a) => a.category === cat);
    return acc;
  }, {});

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }}>
      <div className="flex items-center justify-between mb-8">
        <div>
          <a href="/" className="text-sm text-white/50 hover:text-white/80 transition-colors">
            &larr; {t("back", lang)}
          </a>
          <h1 className="text-2xl font-bold text-white/90 mt-2">
            {lang === "ko" ? "업적 갤러리" : "Achievement Gallery"}
          </h1>
          <p className="text-sm text-white/40 mt-1">
            {lang === "ko"
              ? `총 ${achievements.length}개 업적`
              : `${achievements.length} achievements total`}
          </p>
        </div>
        <button
          onClick={() => setLang((l) => {
            const next = l === "en" ? "ko" : "en";
            localStorage.setItem("lang", next);
            return next;
          })}
          className="px-3 py-1.5 bg-white/[0.04] border border-white/[0.08] rounded-md text-sm font-medium text-white/60 hover:text-white/90 hover:bg-white/[0.08] transition-all cursor-pointer"
        >
          {lang === "en" ? "KR" : "EN"}
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-24">
          <div className="flex items-center gap-3 text-white/30 text-sm">
            <svg className="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" strokeOpacity="0.2" />
              <path d="M12 2a10 10 0 019.95 9" />
            </svg>
            {t("loading", lang)}
          </div>
        </div>
      ) : (
        <div className="space-y-8">
          {CATEGORY_ORDER.map((cat) => {
            const items = grouped[cat];
            if (!items || items.length === 0) return null;
            const [ko, en] = CATEGORY_LABELS[cat] ?? [cat, cat];
            return (
              <motion.section
                key={cat}
                initial={{ opacity: 0, y: 15 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, delay: CATEGORY_ORDER.indexOf(cat) * 0.05 }}
              >
                <h2 className="text-lg font-bold text-white/80 mb-3">
                  {lang === "ko" ? ko : en}
                  <span className="text-sm font-normal text-white/30 ml-2">{items.length}</span>
                </h2>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {items.map((a) => (
                    <AchievementCard key={a.id} a={a} lang={lang} />
                  ))}
                </div>
              </motion.section>
            );
          })}
        </div>
      )}
    </motion.div>
  );
}
