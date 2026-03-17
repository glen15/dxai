"use client";

import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { TierBadge } from "@/components/shared";
import {
  type SearchResult,
  type Lang,
  formatHeroTokens,
  fetchSearch,
  calculateLevel,
  t,
} from "@/lib/supabase";

interface SearchViewProps {
  lang: Lang;
}

export function SearchView({ lang }: SearchViewProps) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(null);

  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      setSearched(false);
      return;
    }

    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      setLoading(true);
      const res = await fetchSearch(query.trim());
      if (res.ok) setResults(res.results ?? []);
      setSearched(true);
      setLoading(false);
    }, 300);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  return (
    <div>
      {/* Search input */}
      <motion.div
        initial={{ opacity: 0, y: -8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="mb-8"
      >
        <div className="relative max-w-md mx-auto">
          <svg
            className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-white/25"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
          >
            <circle cx="11" cy="11" r="8" />
            <path d="M21 21l-4.35-4.35" />
          </svg>
          <input
            type="text"
            placeholder={lang === "ko" ? "닉네임으로 검색..." : "Search by nickname..."}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            autoFocus
            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-xl pl-12 pr-4 py-3.5 text-base focus:outline-none focus:border-purple-500/30 text-white/90 placeholder:text-white/20 transition-colors"
          />
          {loading && (
            <svg
              className="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30 animate-spin"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <circle cx="12" cy="12" r="10" strokeOpacity="0.2" />
              <path d="M12 2a10 10 0 019.95 9" />
            </svg>
          )}
        </div>

        {!query && (
          <p className="text-center text-[11px] text-white/20 mt-3">
            {lang === "ko"
              ? "Vanguard의 닉네임을 검색하여 프로필과 성장 기록을 확인하세요"
              : "Search for a Vanguard to view their profile and growth history"}
          </p>
        )}
      </motion.div>

      {/* Results */}
      <AnimatePresence mode="wait">
        {searched && results.length === 0 && query.trim() && (
          <motion.div
            key="empty"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="text-center py-16 text-white/20 text-sm"
          >
            {lang === "ko" ? "검색 결과 없음" : "No results found"}
          </motion.div>
        )}

        {results.length > 0 && (
          <motion.div
            key="results"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="space-y-2 max-w-md mx-auto"
          >
            {results.map((user, i) => (
              <motion.a
                key={user.nickname}
                href={`/user/?name=${encodeURIComponent(user.nickname)}`}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.2, delay: i * 0.05 }}
                className="flex items-center gap-3 px-4 py-3.5 rounded-xl bg-white/[0.03] border border-white/[0.06] hover:bg-white/[0.06] hover:border-purple-500/20 transition-all cursor-pointer group"
              >
                {/* Name + Level + Tier */}
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-base font-medium text-white/90 group-hover:text-purple-400 transition-colors truncate">
                      {user.nickname}
                    </p>
                    <span className="font-mono text-xs font-bold bg-purple-500/20 text-purple-400 rounded-md px-2 py-0.5">
                      Lv.{calculateLevel(user.total_tokens).level}
                    </span>
                  </div>
                  <div className="flex items-center gap-2 mt-0.5">
                    <TierBadge tier={user.last_tier} division={user.last_division} />
                    <span className="text-[11px] text-white/25 font-mono">
                      {user.total_days_active}{lang === "ko" ? "일 활동" : "d active"}
                    </span>
                  </div>
                </div>

                {/* Token total */}
                <div className="text-right shrink-0">
                  <p className="font-mono text-sm font-bold text-white/80">
                    {formatHeroTokens(user.total_tokens, lang)}
                  </p>
                  <p className="text-[10px] text-white/25">
                    {lang === "ko" ? "토큰" : "tokens"}
                  </p>
                </div>

                {/* Arrow */}
                <svg
                  className="w-4 h-4 text-white/15 group-hover:text-purple-400/50 transition-colors shrink-0"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                >
                  <path d="M9 18l6-6-6-6" />
                </svg>
              </motion.a>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
