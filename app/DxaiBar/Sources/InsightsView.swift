import SwiftUI

struct InsightsView: View {
    let stats: [DxaiDatabase.DailyStats]
    @AppStorage("appLanguage") private var lang = "en"
    private var l: L { L(lang) }

    // MARK: - Computed Data

    private var dailyTotals: [(date: String, total: Int, claude: Int, codex: Int)] {
        var byDate: [String: (claude: Int, codex: Int)] = [:]
        for s in stats {
            var entry = byDate[s.date] ?? (claude: 0, codex: 0)
            if s.tool == "claude" { entry.claude += s.totalTokens }
            else { entry.codex += s.totalTokens }
            byDate[s.date] = entry
        }
        let dates = Set(stats.map(\.date)).sorted()
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
    private var claudeTotal: Int { stats.filter { $0.tool == "claude" }.reduce(0) { $0 + $1.totalTokens } }
    private var codexTotal: Int { stats.filter { $0.tool == "codex" }.reduce(0) { $0 + $1.totalTokens } }
    private var totalInput: Int { stats.reduce(0) { $0 + $1.inputTokens } }
    private var totalOutput: Int { stats.reduce(0) { $0 + $1.outputTokens } }
    private var totalCache: Int { stats.reduce(0) { $0 + $1.cacheReadTokens } }
    private var totalRequests: Int { stats.reduce(0) { $0 + $1.requests } }

    var body: some View {
        if weekTotal == 0 {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "chart.bar")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary.opacity(0.4))
                Text(l.insightsNoData)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCards
                    Divider().padding(.horizontal, 4)
                    barChart
                    Divider().padding(.horizontal, 4)
                    toolBreakdown
                    Divider().padding(.horizontal, 4)
                    tokenTypes
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 8) {
            summaryCard(label: l.insightsTotalWeek, value: formatCompact(weekTotal),
                        sub: "\(totalRequests) \(l.insightsRequests)")
            summaryCard(label: l.insightsDailyAvg, value: formatCompact(dailyAvg), sub: nil)
            summaryCard(label: l.insightsPeakDay, value: formatCompact(peakDay.total),
                        sub: shortDay(peakDay.date))
        }
    }

    private func summaryCard(label: String, value: String, sub: String?) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(sub ?? " ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(sub != nil ? 0.6 : 0))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    // MARK: - Bar Chart

    private var barChart: some View {
        let maxVal = max(1, dailyTotals.map(\.total).max() ?? 1)
        let barHeight: CGFloat = 100

        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(dailyTotals, id: \.date) { day in
                let claudeH = barHeight * CGFloat(day.claude) / CGFloat(maxVal)
                let codexH = barHeight * CGFloat(day.codex) / CGFloat(maxVal)
                let isToday = day.date == dailyTotals.last?.date

                VStack(spacing: 2) {
                    Text(formatCompact(day.total))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))

                    VStack(spacing: 0) {
                        // Codex on top
                        if codexH > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ToolTheme.codex.primary.opacity(isToday ? 1 : 0.6))
                                .frame(height: max(2, codexH))
                        }
                        // Claude on bottom
                        if claudeH > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ToolTheme.claude.primary.opacity(isToday ? 1 : 0.6))
                                .frame(height: max(2, claudeH))
                        }
                    }
                    .frame(height: barHeight, alignment: .bottom)

                    Text(shortDay(day.date))
                        .font(.system(size: 10, weight: isToday ? .bold : .regular))
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
                .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            tokenTypeRow(label: l.insightsInput, value: totalInput, total: total,
                         color: .blue)
            tokenTypeRow(label: l.insightsOutput, value: totalOutput, total: total,
                         color: .orange)
            tokenTypeRow(label: l.insightsCache, value: totalCache, total: total,
                         color: .green)
        }
    }

    private func tokenTypeRow(label: String, value: Int, total: Int, color: Color) -> some View {
        let pct = Double(value) / Double(total)
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.7))
                    .frame(width: max(2, geo.size.width * pct))
            }
            .frame(height: 10)
            Text("\(Int(pct * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func legendDot(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11, weight: .medium))
            Text(value).font(.system(size: 11, design: .monospaced))
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
        fmt.timeZone = TimeZone(identifier: "UTC")
        guard let date = fmt.date(from: dateStr) else { return dateStr.suffix(2).description }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        out.locale = Locale(identifier: lang == "ko" ? "ko_KR" : "en_US")
        return out.string(from: date)
    }
}
