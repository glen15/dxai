"use client";

import { useState, useEffect, use } from "react";
import {
  fetchUserProfile,
  type UserProfile,
  tierEmoji,
  tierColor,
  formatTokens,
  formatNumber,
} from "@/lib/supabase";

export default function UserPage({ params }: { params: Promise<{ nickname: string }> }) {
  const { nickname } = use(params);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

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
    return <div className="text-center py-20 text-gray-500">Loading...</div>;
  }

  if (error || !profile) {
    return (
      <div className="text-center py-20">
        <h1 className="text-2xl font-bold mb-2">User not found</h1>
        <p className="text-gray-500">{error}</p>
        <a href="/" className="text-purple-400 hover:underline mt-4 inline-block">
          Back to Leaderboard
        </a>
      </div>
    );
  }

  const tier = profile.last_tier ?? "";
  const division = profile.last_division;

  return (
    <div>
      {/* Back link */}
      <a href="/" className="text-sm text-gray-500 hover:text-gray-300 mb-6 inline-block">
        &larr; Leaderboard
      </a>

      {/* Profile Header */}
      <div className="bg-gray-900/50 rounded-xl border border-gray-800 p-6 mb-6">
        <div className="flex items-start justify-between flex-wrap gap-4">
          <div>
            <h1 className="text-3xl font-bold mb-1">{profile.nickname}</h1>
            <p className={`text-lg ${tierColor(tier)}`}>
              {tierEmoji(tier)} {tier}
              {division != null && ` ${division}`}
            </p>
            <p className="text-sm text-gray-500 mt-2">
              Member since {new Date(profile.member_since).toLocaleDateString()}
              {profile.streak > 0 && (
                <span className="ml-3 text-orange-400">
                  {profile.streak} day streak
                </span>
              )}
            </p>
          </div>
          <div className="text-right">
            <div className="text-4xl font-bold text-purple-400">
              #{profile.rank}
            </div>
            <div className="text-sm text-gray-500">
              of {formatNumber(profile.total_users)} pioneers
            </div>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
        <StatCard label="Total Points" value={formatNumber(profile.total_points)} />
        <StatCard label="Total Coins" value={formatNumber(profile.total_coins)} accent="text-yellow-400" />
        <StatCard label="Weekly Points" value={formatNumber(profile.weekly.points)} sub={`${profile.weekly.days_active} days active`} />
        <StatCard label="Monthly Points" value={formatNumber(profile.monthly.points)} sub={`${profile.monthly.days_active} days active`} />
      </div>

      {/* Token Usage */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
        <div className="bg-gray-900/50 rounded-xl border border-gray-800 p-5">
          <h3 className="text-sm text-gray-500 mb-3">Weekly Tokens</h3>
          <div className="flex justify-between mb-2">
            <span className="text-gray-400">Claude</span>
            <span className="font-mono">{formatTokens(profile.weekly.claude_tokens)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">Codex</span>
            <span className="font-mono">{formatTokens(profile.weekly.codex_tokens)}</span>
          </div>
        </div>
        <div className="bg-gray-900/50 rounded-xl border border-gray-800 p-5">
          <h3 className="text-sm text-gray-500 mb-3">Monthly Tokens</h3>
          <div className="flex justify-between mb-2">
            <span className="text-gray-400">Claude</span>
            <span className="font-mono">{formatTokens(profile.monthly.claude_tokens)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">Codex</span>
            <span className="font-mono">{formatTokens(profile.monthly.codex_tokens)}</span>
          </div>
        </div>
      </div>

      {/* 30-Day History */}
      <h2 className="text-xl font-bold mb-4">30-Day History</h2>
      <div className="bg-gray-900/50 rounded-xl border border-gray-800 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-800 text-gray-500 text-sm">
              <th className="text-left py-3 px-4">Date</th>
              <th className="text-left py-3 px-4">Tier</th>
              <th className="text-right py-3 px-4">Points</th>
              <th className="text-right py-3 px-4 hidden sm:table-cell">Claude</th>
              <th className="text-right py-3 px-4 hidden sm:table-cell">Codex</th>
            </tr>
          </thead>
          <tbody>
            {profile.history.length === 0 ? (
              <tr>
                <td colSpan={5} className="text-center py-8 text-gray-600">No history</td>
              </tr>
            ) : (
              profile.history.map((day) => (
                <tr key={day.date} className="border-b border-gray-800/50 hover:bg-gray-800/30 transition-colors">
                  <td className="py-2.5 px-4 text-sm text-gray-400">{day.date}</td>
                  <td className="py-2.5 px-4">
                    <span className={`text-sm ${tierColor(day.pioneer_tier)}`}>
                      {tierEmoji(day.pioneer_tier)} {day.pioneer_tier}
                      {day.pioneer_division != null && ` ${day.pioneer_division}`}
                    </span>
                  </td>
                  <td className="py-2.5 px-4 text-right font-mono text-sm">
                    {formatNumber(day.daily_points)}
                  </td>
                  <td className="py-2.5 px-4 text-right font-mono text-sm text-gray-500 hidden sm:table-cell">
                    {formatTokens(day.claude_tokens)}
                  </td>
                  <td className="py-2.5 px-4 text-right font-mono text-sm text-gray-500 hidden sm:table-cell">
                    {formatTokens(day.codex_tokens)}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function StatCard({ label, value, sub, accent }: { label: string; value: string; sub?: string; accent?: string }) {
  return (
    <div className="bg-gray-900/50 rounded-xl border border-gray-800 p-4">
      <div className="text-sm text-gray-500 mb-1">{label}</div>
      <div className={`text-2xl font-bold ${accent ?? "text-white"}`}>{value}</div>
      {sub && <div className="text-xs text-gray-600 mt-1">{sub}</div>}
    </div>
  );
}
