"use client";

import { useState, useEffect, useCallback } from "react";
import {
  fetchLeaderboard,
  type LeaderboardType,
  type LeaderboardResponse,
  type RankEntry,
  tierEmoji,
  tierColor,
  formatTokens,
  formatNumber,
} from "@/lib/supabase";

const TABS: { key: LeaderboardType; label: string }[] = [
  { key: "realtime", label: "Real-time" },
  { key: "daily", label: "Daily" },
  { key: "weekly", label: "Weekly" },
  { key: "monthly", label: "Monthly" },
  { key: "total", label: "All-time" },
];

export default function Home() {
  const [tab, setTab] = useState<LeaderboardType>("realtime");
  const [data, setData] = useState<LeaderboardResponse | null>(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [dateInput, setDateInput] = useState(todayString());
  const [search, setSearch] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    const params: Record<string, string> = {};
    if (tab === "daily") params.date = dateInput;
    const result = await fetchLeaderboard(tab, params, page);
    setData(result);
    setLoading(false);
  }, [tab, page, dateInput]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (tab !== "realtime") return;
    const interval = setInterval(load, 30_000);
    return () => clearInterval(interval);
  }, [tab, load]);

  const filteredRankings = data?.rankings?.filter(
    (r) => !search || r.nickname.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Pioneer Leaderboard</h1>
        <p className="text-gray-500">
          {data ? `${formatNumber(data.total_users)} pioneers competing` : "Loading..."}
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-gray-900 rounded-lg p-1 w-fit">
        {TABS.map(({ key, label }) => (
          <button
            key={key}
            onClick={() => { setTab(key); setPage(1); }}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              tab === key
                ? "bg-purple-600 text-white"
                : "text-gray-400 hover:text-white hover:bg-gray-800"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Controls */}
      <div className="flex gap-4 mb-6 items-center">
        {tab === "daily" && (
          <input
            type="date"
            value={dateInput}
            onChange={(e) => { setDateInput(e.target.value); setPage(1); }}
            className="bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-sm"
          />
        )}
        <input
          type="text"
          placeholder="Search nickname..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-sm w-64"
        />
        {tab === "realtime" && (
          <span className="text-xs text-green-500 flex items-center gap-1">
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
            Live
          </span>
        )}
      </div>

      {/* Table */}
      <div className="bg-gray-900/50 rounded-xl border border-gray-800 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-800 text-gray-500 text-sm">
              <th className="text-left py-3 px-4 w-16">#</th>
              <th className="text-left py-3 px-4">Pioneer</th>
              <th className="text-left py-3 px-4">Tier</th>
              <th className="text-right py-3 px-4">Points</th>
              <th className="text-right py-3 px-4 hidden sm:table-cell">Claude</th>
              <th className="text-right py-3 px-4 hidden sm:table-cell">Codex</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} className="text-center py-16 text-gray-600">
                  Loading...
                </td>
              </tr>
            ) : !filteredRankings?.length ? (
              <tr>
                <td colSpan={6} className="text-center py-16 text-gray-600">
                  No data yet
                </td>
              </tr>
            ) : (
              filteredRankings.map((entry) => (
                <RankRow key={entry.nickname} entry={entry} type={tab} />
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {data && data.total_pages > 1 && (
        <div className="flex justify-center gap-2 mt-6">
          <button
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
            className="px-4 py-2 bg-gray-900 rounded-lg text-sm disabled:opacity-30 hover:bg-gray-800 transition-colors"
          >
            Prev
          </button>
          <span className="px-4 py-2 text-sm text-gray-500">
            {page} / {data.total_pages}
          </span>
          <button
            onClick={() => setPage((p) => Math.min(data.total_pages, p + 1))}
            disabled={page >= data.total_pages}
            className="px-4 py-2 bg-gray-900 rounded-lg text-sm disabled:opacity-30 hover:bg-gray-800 transition-colors"
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}

function RankRow({ entry, type }: { entry: RankEntry; type: LeaderboardType }) {
  const tier = entry.pioneer_tier ?? entry.best_tier ?? entry.last_tier ?? "";
  const division = entry.pioneer_division ?? entry.last_division;
  const points = entry.daily_points ?? entry.period_points ?? entry.total_points ?? 0;
  const claude = entry.claude_tokens ?? 0;
  const codex = entry.codex_tokens ?? 0;

  return (
    <tr className="border-b border-gray-800/50 hover:bg-gray-800/30 transition-colors">
      <td className="py-3 px-4">
        <span className={`font-mono text-sm ${
          entry.rank === 1 ? "text-yellow-400 font-bold" :
          entry.rank === 2 ? "text-gray-300 font-bold" :
          entry.rank === 3 ? "text-amber-600 font-bold" :
          "text-gray-500"
        }`}>
          {entry.rank}
        </span>
      </td>
      <td className="py-3 px-4">
        <a
          href={`/user/${entry.nickname}`}
          className="font-medium hover:text-purple-400 transition-colors"
        >
          {entry.nickname}
        </a>
      </td>
      <td className="py-3 px-4">
        <span className={tierColor(tier)}>
          {tierEmoji(tier)} {tier}
          {division != null && ` ${division}`}
        </span>
      </td>
      <td className="py-3 px-4 text-right font-mono text-sm">
        {formatNumber(points)}
        {type === "weekly" || type === "monthly" ? (
          <span className="text-gray-600 ml-1 text-xs">
            ({entry.days_active}d)
          </span>
        ) : null}
      </td>
      <td className="py-3 px-4 text-right font-mono text-sm text-gray-500 hidden sm:table-cell">
        {formatTokens(claude)}
      </td>
      <td className="py-3 px-4 text-right font-mono text-sm text-gray-500 hidden sm:table-cell">
        {formatTokens(codex)}
      </td>
    </tr>
  );
}

function todayString(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
