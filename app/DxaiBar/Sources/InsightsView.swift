import SwiftUI

struct InsightsView: View {
    let stats: [DxaiDatabase.DailyStats]
    @AppStorage("appLanguage") private var lang = "en"
    @Environment(\.colorScheme) private var scheme
    private var l: L { L(lang) }
    private var colors: DxaiColors { DxaiColors(scheme: scheme) }

    // MARK: - Week Split (calendar-based 7-day windows)

    private var thisWeekDates: Set<String> {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return Set((0...6).map { fmt.string(from: cal.date(byAdding: .day, value: -$0, to: today)!) })
    }

    private var thisWeekStats: [DxaiDatabase.DailyStats] {
        let dates = thisWeekDates
        return stats.filter { dates.contains($0.date) }
    }

    private var lastWeekStats: [DxaiDatabase.DailyStats] {
        let dates = thisWeekDates
        return stats.filter { !dates.contains($0.date) }
    }

    // MARK: - This Week Computed Data

    private var dailyTotals: [(date: String, total: Int, claude: Int, codex: Int)] {
        var byDate: [String: (claude: Int, codex: Int)] = [:]
        for s in thisWeekStats {
            var entry = byDate[s.date] ?? (claude: 0, codex: 0)
            if s.tool == "claude" { entry.claude += s.totalTokens }
            else { entry.codex += s.totalTokens }
            byDate[s.date] = entry
        }
        let dates = Set(thisWeekStats.map(\.date)).sorted()
        return dates.map { d in
            let e = byDate[d] ?? (claude: 0, codex: 0)
            return (date: d, total: e.claude + e.codex, claude: e.claude, codex: e.codex)
        }
    }

    private var weekTotal: Int { dailyTotals.reduce(0) { $0 + $1.total } }
    private var dailyAvg: Int { dailyTotals.isEmpty ? 0 : weekTotal / dailyTotals.count }
    private var peakDay: (date: String, total: Int) {
        guard let peak = dailyTotals.max(by: { $0.total < $1.total }) else {
            return (date: "", total: 0)
        }
        return (date: peak.date, total: peak.total)
    }
    private var claudeTotal: Int { thisWeekStats.filter { $0.tool == "claude" }.reduce(0) { $0 + $1.totalTokens } }
    private var codexTotal: Int { thisWeekStats.filter { $0.tool == "codex" }.reduce(0) { $0 + $1.totalTokens } }
    private var totalInput: Int { thisWeekStats.reduce(0) { $0 + $1.inputTokens } }
    private var totalOutput: Int { thisWeekStats.reduce(0) { $0 + $1.outputTokens } }
    private var totalCache: Int { thisWeekStats.reduce(0) { $0 + $1.cacheReadTokens } }
    private var totalRequests: Int { thisWeekStats.reduce(0) { $0 + $1.requests } }

    // MARK: - Last Week & Trends

    private var lastWeekTotal: Int { lastWeekStats.reduce(0) { $0 + $1.totalTokens } }

    private var weekOverWeekChange: Int? {
        guard lastWeekTotal > 0 else { return nil }
        return Int(round(Double(weekTotal - lastWeekTotal) / Double(lastWeekTotal) * 100))
    }

    private var cacheHitRate: Int {
        let total = totalInput + totalCache
        guard total > 0 else { return 0 }
        return Int(round(Double(totalCache) / Double(total) * 100))
    }

    // MARK: - Summary Bullets

    private var summaryBullets: [String] {
        var bullets: [String] = []

        let changeStr: String
        if let change = weekOverWeekChange {
            changeStr = change >= 0 ? "+\(change)%" : "\(change)%"
        } else {
            changeStr = ""
        }
        bullets.append(l.insightsBulletTotal(l.formatImpact(weekTotal), changeStr))
        bullets.append(l.insightsBulletCache(cacheHitRate))

        if peakDay.total > 0, dailyAvg > 0, peakDay.total >= dailyAvg * 3 / 2 {
            bullets.append(l.insightsBulletPeak(shortDay(peakDay.date), l.formatImpact(peakDay.total)))
        }

        return bullets
    }

    // MARK: - Body

    private var allTotal: Int { stats.reduce(0) { $0 + $1.totalTokens } }

    var body: some View {
        if allTotal == 0 {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "chart.bar")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(colors.textMuted))
                Text(l.insightsNoData)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(spacing: 10) {
                summaryCards
                summaryBulletsView
                Divider().padding(.horizontal, 4)
                barChart
                Divider().padding(.horizontal, 4)
                toolBreakdown
                Divider().padding(.horizontal, 4)
                tokenTypes
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 8) {
            summaryCard(label: l.insightsTotalWeek, value: formatCompact(weekTotal),
                        sub: weekOverWeekSub, subColor: weekOverWeekColor, accent: .purple)
            summaryCard(label: l.insightsDailyAvg, value: formatCompact(dailyAvg),
                        sub: nil, subColor: nil, accent: .blue)
            summaryCard(label: l.insightsPeakDay, value: formatCompact(peakDay.total),
                        sub: shortDay(peakDay.date), subColor: nil, accent: .orange)
        }
    }

    private var weekOverWeekSub: String {
        guard let change = weekOverWeekChange else {
            return "\(totalRequests) \(l.insightsRequests)"
        }
        let arrow = change >= 0 ? "\u{2191}" : "\u{2193}"
        let sign = change >= 0 ? "+" : ""
        return "\(arrow)\(sign)\(change)% \(l.insightsVsLastWeek)"
    }

    private var weekOverWeekColor: Color? {
        guard let change = weekOverWeekChange else { return nil }
        return change >= 0 ? .green : .red
    }

    private func summaryCard(label: String, value: String, sub: String?,
                             subColor: Color?, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(accent)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(sub ?? " ")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(sub != nil ? (subColor ?? .secondary.opacity(colors.textDim)) : .clear)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(accent.opacity(colors.bgSubtle))
        .cornerRadius(8)
    }

    // MARK: - Summary Bullets View

    private var summaryBulletsView: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(summaryBullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2022}")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.purple.opacity(colors.textDim))
                    Text(bullet)
                        .font(.system(size: 12.5))
                        .foregroundColor(.primary.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(colors.bgSubtle))
        .cornerRadius(8)
    }

    // MARK: - Bar Chart

    private var barChart: some View {
        let maxVal = max(1, dailyTotals.map(\.total).max() ?? 1)
        let barHeight: CGFloat = 70

        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(dailyTotals, id: \.date) { day in
                let claudeH = barHeight * CGFloat(day.claude) / CGFloat(maxVal)
                let codexH = barHeight * CGFloat(day.codex) / CGFloat(maxVal)
                let isToday = day.date == dailyTotals.last?.date

                VStack(spacing: 2) {
                    Text(formatCompact(day.total))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary.opacity(colors.textDim))

                    VStack(spacing: 0) {
                        if codexH > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ToolTheme.codex.primary.opacity(isToday ? 1 : 0.6))
                                .frame(height: max(2, codexH))
                        }
                        if claudeH > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ToolTheme.claude.primary.opacity(isToday ? 1 : 0.6))
                                .frame(height: max(2, claudeH))
                        }
                    }
                    .frame(height: barHeight, alignment: .bottom)

                    Text(shortDay(day.date))
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .foregroundColor(isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Tool Breakdown

    private var toolBreakdown: some View {
        let total = max(1, claudeTotal + codexTotal)
        let claudePct = Int(Double(claudeTotal) / Double(total) * 100)
        let codexPct = 100 - claudePct

        return VStack(alignment: .leading, spacing: 8) {
            Text(l.insightsToolBreakdown)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            GeometryReader { geo in
                HStack(spacing: 1) {
                    if claudePct > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ToolTheme.claude.primary)
                            .frame(width: geo.size.width * CGFloat(claudePct) / 100)
                    }
                    if codexPct > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ToolTheme.codex.primary)
                            .frame(width: geo.size.width * CGFloat(codexPct) / 100)
                    }
                }
            }
            .frame(height: 14)

            HStack {
                legendDot(color: ToolTheme.claude.primary, label: "Claude",
                          value: "\(claudePct)%  \(formatCompact(claudeTotal))")
                Spacer()
                legendDot(color: ToolTheme.codex.primary, label: "Codex",
                          value: "\(codexPct)%  \(formatCompact(codexTotal))")
            }
        }
    }

    // MARK: - Token Types

    private var tokenTypes: some View {
        let total = max(1, totalInput + totalOutput + totalCache)

        return VStack(alignment: .leading, spacing: 8) {
            Text(l.insightsTokenTypes)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            tokenTypeRow(label: l.insightsInput, value: totalInput, total: total,
                         color: .blue)
            tokenTypeRow(label: l.insightsOutput, value: totalOutput, total: total,
                         color: .orange)
            tokenTypeRow(label: l.insightsCache, value: totalCache, total: total,
                         color: .green)

            HStack(spacing: 4) {
                Text(l.insightsCacheHitRate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(cacheHitRate)%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(cacheHitRate >= 50 ? .green : (cacheHitRate >= 20 ? .orange : .red))
            }
            .padding(.top, 4)
        }
    }

    private func tokenTypeRow(label: String, value: Int, total: Int, color: Color) -> some View {
        let pct = Double(value) / Double(total)
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.7))
                    .frame(width: max(2, geo.size.width * pct))
            }
            .frame(height: 12)
            Text("\(Int(pct * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary.opacity(colors.textDim))
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func legendDot(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label).font(.system(size: 12, weight: .medium))
            Text(value).font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func formatCompact(_ n: Int) -> String {
        if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func shortDay(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        guard let date = fmt.date(from: dateStr) else { return dateStr.suffix(2).description }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        out.locale = Locale(identifier: lang == "ko" ? "ko_KR" : "en_US")
        return out.string(from: date)
    }
}
