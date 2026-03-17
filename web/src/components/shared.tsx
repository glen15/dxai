"use client";

import { SparklesText } from "@/components/ui/sparkles-text";

/** Tier badge background/text/border color classes */
export const TIER_BG: Record<string, string> = {
  Bronze: "bg-amber-900/25 text-amber-500 border-amber-700/40",
  Silver: "bg-slate-700/25 text-slate-200 border-slate-500/40",
  Gold: "bg-yellow-900/25 text-yellow-300 border-yellow-600/40",
  Platinum: "bg-cyan-900/25 text-cyan-300 border-cyan-600/40",
  Diamond: "bg-blue-900/25 text-blue-300 border-blue-600/40",
  Master: "bg-purple-900/25 text-purple-300 border-purple-600/40",
  Grandmaster: "bg-red-900/25 text-red-300 border-red-600/40",
  Challenger: "bg-orange-900/25 text-orange-300 border-orange-600/40",
};

/** Tier text colors (indexed by tier order B/S/G/P/D/M/GM/C) */
export const TIER_COLORS = [
  "text-amber-600",   // B
  "text-slate-400",   // S
  "text-yellow-400",  // G
  "text-cyan-300",    // P
  "text-blue-400",    // D
  "text-purple-400",  // M
  "text-red-400",     // GM
  "text-orange-400",  // C
];

/** Tier bar fill colors */
export const TIER_BAR_COLORS = [
  "bg-amber-600",
  "bg-slate-400",
  "bg-yellow-400",
  "bg-cyan-300",
  "bg-blue-400",
  "bg-purple-400",
  "bg-red-400",
  "bg-orange-400",
];

/** Tier badge with sparkle effect for Challenger */
export function TierBadge({
  tier,
  division,
  size = "sm",
}: {
  tier: string;
  division: number | null;
  size?: "sm" | "lg";
}) {
  const cls = TIER_BG[tier] ?? "bg-gray-800/20 text-gray-400 border-gray-700/30";

  if (tier === "Challenger") {
    const textSize = size === "lg" ? "text-base font-bold" : "text-xs font-bold";
    return (
      <SparklesText
        sparklesCount={6}
        colors={{ first: "#facc15", second: "#fb923c" }}
        className={textSize}
      >
        Challenger
      </SparklesText>
    );
  }

  const sizeClass = size === "lg" ? "px-4 py-1.5 text-base" : "px-2.5 py-1 text-sm";
  return (
    <span className={`inline-flex items-center gap-1 rounded font-medium border ${sizeClass} ${cls}`}>
      {tier}{division != null && ` ${division}`}
    </span>
  );
}

