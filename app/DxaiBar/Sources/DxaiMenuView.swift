import SwiftUI
import ServiceManagement

// MARK: - Theme

enum ToolTheme {
    case claude, codex

    var primary: Color {
        switch self {
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:  return Color(red: 0.06, green: 0.64, blue: 0.50)
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .claude:
            return LinearGradient(
                colors: [Color(red: 0.85, green: 0.47, blue: 0.34),
                         Color(red: 0.91, green: 0.61, blue: 0.48)],
                startPoint: .leading, endPoint: .trailing)
        case .codex:
            return LinearGradient(
                colors: [Color(red: 0.06, green: 0.64, blue: 0.50),
                         Color(red: 0.10, green: 0.76, blue: 0.49)],
                startPoint: .leading, endPoint: .trailing)
        }
    }

    var icon: String {
        switch self {
        case .claude: return "bolt.fill"
        case .codex:  return "chevron.left.forwardslash.chevron.right"
        }
    }

    var label: String {
        switch self {
        case .claude: return "Claude"
        case .codex:  return "Codex"
        }
    }

    static func from(_ tool: String) -> ToolTheme? {
        switch tool.lowercased() {
        case "claude": return .claude
        case "codex":  return .codex
        default: return nil
        }
    }
}

// MARK: - Main View

struct DxaiMenuView: View {
    @ObservedObject var viewModel: DxaiViewModel
    @State private var hoveredAction: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showAbout = false
    @State private var showInsights = false
    @AppStorage("appLanguage") private var lang = "en"
    private var l: L { L(lang) }

    var body: some View {
        VStack(spacing: 0) {
            if showAbout {
                aboutView
            } else if showInsights {
                insightsNavigationView
            } else if viewModel.showTaskPanel {
                taskPanelView
            } else {
                headerView
                Divider()

                VStack(spacing: 0) {
                    dashboardSection
                        .padding(.vertical, 10)

                    Divider().padding(.horizontal, 16)

                    toolCardsSection
                        .padding(.vertical, 8)

                    Divider().padding(.horizontal, 16)

                    quickActions
                        .padding(.vertical, 8)

                }

                Divider()
                footerView
            }
        }
        .frame(width: 400)
        .background(.ultraThickMaterial)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
                .font(.system(size: 18))
            Text("Deus eX AI")
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            Button(action: { showAbout = true }) {
                Text("About")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button(action: { lang = lang == "ko" ? "en" : "ko" }) {
                Text(lang == "ko" ? "KR" : "EN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button(action: { viewModel.refresh(force: true) }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text(l.refresh)
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Dashboard

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Token total (full width)
            VStack(alignment: .leading, spacing: 2) {
                Text(formatNumber(viewModel.todayTokens))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(l.tokensToday)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Pioneer badge + message
            if let level = viewModel.pioneerLevel {
                HStack(spacing: 8) {
                    Text("\(level.emoji) \(level.displayName)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(pioneerColor(level).opacity(0.12))
                        .foregroundColor(pioneerColor(level))
                        .cornerRadius(5)
                    Text(l.pioneerMessage(level.tier.rawValue, division: level.division))
                        .font(.system(size: 12))
                        .foregroundColor(pioneerColor(level).opacity(0.7))
                        .italic()
                        .lineLimit(1)
                }
            }

            // Progress bar
            pioneerProgressBar

            // (quota is now shown inside each tool card)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Pioneer Progress

    private var pioneerProgressBar: some View {
        let tiers: [(String, DxaiViewModel.PioneerLevel.Tier, Int)] = [
            ("B",  .bronze,      5_000),
            ("S",  .silver,      75_000),
            ("G",  .gold,        400_000),
            ("P",  .platinum,    2_000_000),
            ("D",  .diamond,     15_000_000),
            ("M",  .master,      60_000_000),
            ("GM", .grandmaster, 120_000_000),
            ("C",  .challenger,  500_000_000),
        ]
        let currentTier = viewModel.pioneerLevel?.tier
        let currentIdx = tiers.firstIndex(where: { $0.1 == currentTier }) ?? -1
        let next = DxaiViewModel.PioneerLevel.nextLevel(after: viewModel.pioneerLevel)

        return VStack(spacing: 6) {
            // Segmented bar
            HStack(spacing: 2) {
                ForEach(0..<tiers.count, id: \.self) { i in
                    let isCurrent = i == currentIdx
                    let isPast = i < currentIdx
                    let tierColor = pioneerTierColor(tiers[i].1)

                    VStack(spacing: 3) {
                        // Segment bar
                        if isCurrent {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(tierColor.opacity(0.25))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(tierColor)
                                        .frame(width: max(4, geo.size.width * CGFloat(pioneerProgress)))
                                    // Position indicator
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: tierColor, radius: 3)
                                        .position(
                                            x: max(4, geo.size.width * CGFloat(pioneerProgress)),
                                            y: geo.size.height / 2
                                        )
                                }
                            }
                            .frame(height: 10)
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isPast ? tierColor : Color.secondary.opacity(0.12))
                                .frame(height: isPast ? 6 : 5)
                        }

                        // Label
                        Text(tiers[i].0)
                            .font(.system(size: isCurrent ? 9 : 8,
                                          weight: isCurrent ? .bold : .regular,
                                          design: .monospaced))
                            .foregroundColor(isPast || isCurrent ? tierColor : .secondary.opacity(0.3))
                    }
                }
            }

            // Next level info
            HStack {
                if let next {
                    Text("Next: \(next.displayName)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(formatNumber(next.threshold - viewModel.todayTokens)) \(l.remaining)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("MAX RANK")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(pioneerColor(viewModel.pioneerLevel))
                    Spacer()
                }
            }

            // Token Milestone bar
            milestoneProgressBar
        }
    }

    // MARK: - Milestone Progress

    private var milestoneProgressBar: some View {
        let info = viewModel.currentMilestoneInfo
        let currentAbbr = pioneerAbbrev(viewModel.pioneerLevel)
        let nextAbbr = DxaiViewModel.PioneerLevel.nextLevel(after: viewModel.pioneerLevel)
            .map { pioneerAbbrev($0) } ?? "MAX"

        return VStack(spacing: 4) {
            // XP bar: P1 [====] D5
            HStack(spacing: 5) {
                Text(currentAbbr)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(pioneerColor(viewModel.pioneerLevel))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red.opacity(0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red.opacity(0.7))
                            .frame(width: max(2, geo.size.width * CGFloat(info.progress)))
                    }
                }
                .frame(height: 5)

                Text(nextAbbr)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            // Milestone title + resend button
            HStack(spacing: 4) {
                Text("\u{2694}\u{FE0F} \(info.currentBody)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .lineLimit(1)
                Spacer()
                Button {
                    viewModel.resendLastMilestone()
                } label: {
                    Text(l.testAlert)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pioneerAbbrev(_ level: DxaiViewModel.PioneerLevel?) -> String {
        guard let level else { return "—" }
        let prefix: String
        switch level.tier {
        case .bronze:      prefix = "B"
        case .silver:      prefix = "S"
        case .gold:        prefix = "G"
        case .platinum:    prefix = "P"
        case .diamond:     prefix = "D"
        case .master:      prefix = "M"
        case .grandmaster: prefix = "GM"
        case .challenger:  prefix = "C"
        }
        if let div = level.division {
            return "\(prefix)\(div)"
        }
        return prefix
    }

    private func pioneerTierColor(_ tier: DxaiViewModel.PioneerLevel.Tier) -> Color {
        switch tier {
        case .bronze:      return .orange
        case .silver:      return .gray
        case .gold:        return .yellow
        case .platinum:    return .teal
        case .diamond:     return .cyan
        case .master:      return .purple
        case .grandmaster: return .red
        case .challenger:  return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    // MARK: - Tool Cards (Claude + Codex only)

    private var toolCardsSection: some View {
        let filtered = viewModel.toolStats.filter {
            $0.tool.lowercased() == "claude" || $0.tool.lowercased() == "codex"
        }

        return VStack(spacing: 0) {
            // Section header with Insights button
            HStack {
                Spacer()
                Button(action: {
                    showInsights = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                        Text(l.insights)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            if filtered.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(l.noDataYet)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text(l.autoCollect)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                ForEach(filtered, id: \.tool) { stat in
                    toolCard(stat)
                    if stat.tool != filtered.last?.tool {
                        Divider().padding(.horizontal, 24)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func toolCard(_ stat: DxaiDatabase.DailyStats) -> some View {
        let theme = ToolTheme.from(stat.tool) ?? .claude
        let quota = stat.tool.lowercased() == "claude"
            ? viewModel.claudeQuota
            : viewModel.codexQuota

        return VStack(alignment: .leading, spacing: 8) {
            // Header: icon + name + plan
            HStack {
                Image(systemName: theme.icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.primary)
                Text(theme.label)
                    .font(.system(size: 16, weight: .semibold))
                if let plan = quota?.plan {
                    Text("(\(plan))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Quota bars (session / weekly)
            if let q = quota, q.fiveHour != nil || q.sevenDay != nil {
                usageBar(label: l.session5h, pct: q.fiveHour, reset: q.fiveHourReset, color: theme.primary)
                usageBar(label: l.weekly7d, pct: q.sevenDay, reset: q.sevenDayReset, color: theme.primary)
            }

            // Token stats
            HStack(spacing: 8) {
                Text("\(formatNumber(stat.totalTokens)) tok")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("\u{00B7}")
                    .foregroundColor(.secondary.opacity(0.4))
                Text("\(stat.requests) req")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(l.today)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.vertical, 10)
    }

    private func usageBar(label: String, pct: Int?, reset: Date?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                if let pct {
                    Text(l.used(pct))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(pct >= 80 ? .red : color)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    if let pct {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(pct >= 80 ? Color.red : color)
                            .frame(width: max(pct > 0 ? 2 : 0,
                                              geo.size.width * CGFloat(pct) / 100))
                    }
                }
            }
            .frame(height: 6)

            if let reset {
                Text("Resets \(formatResetDate(reset))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
    }

    // MARK: - Task Panel

    private var taskPanelView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { viewModel.hideTaskPanel() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(l.back)
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text(viewModel.taskTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Output
            if let status = viewModel.systemStatus {
                StatusPanelView(status: status)
                    .frame(maxHeight: 420)
            } else if let scan = viewModel.scanResult {
                ScanPanelView(scan: scan)
                    .frame(maxHeight: 420)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        if viewModel.isTaskRunning && viewModel.taskOutput.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.9)
                                Text(l.runningDots)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(viewModel.taskOutput)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)

                                if viewModel.isTaskRunning {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text(l.runningDots)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 8)
                                }

                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(12)
                        }
                    }
                    .onChange(of: viewModel.taskOutput) { _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .frame(maxHeight: 360)
            }

            Divider()

            // Footer
            HStack {
                if viewModel.isTaskRunning {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.orange)
                    Text(l.running)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(l.stop) { viewModel.stopTask() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text(l.done)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(l.close) { viewModel.stopTask() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 2) {
            actionRow(l.systemStatus,    "status",      icon: "heart.text.square", color: .green,
                      desc: l.systemStatusDesc)
            actionRow(l.aiScan,          "scan --json", icon: "magnifyingglass", color: .purple,
                      desc: l.aiScanDesc)
            actionRow(l.diskCleanup,     "clean",       icon: "trash",           color: .orange,
                      desc: l.diskCleanupDesc, needsAdmin: true)
            actionRow(l.systemOptimize,  "optimize",    icon: "bolt.fill",       color: .blue,
                      desc: l.systemOptimizeDesc, needsAdmin: true)
        }
        .padding(.horizontal, 8)
    }

    private func actionRow(
        _ label: String,
        _ command: String,
        icon: String,
        color: Color,
        desc: String,
        needsAdmin: Bool = false
    ) -> some View {
        Button {
            if viewModel.isTaskRunning && viewModel.taskTitle != label {
                viewModel.showRunningTask()
            } else {
                viewModel.runTask(title: label, command: command, needsAdmin: needsAdmin)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14))
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                Spacer()
                if viewModel.isTaskRunning && viewModel.taskTitle == label {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text(l.running)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                } else if viewModel.isTaskRunning {
                    Text(l.waiting)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                } else {
                    Text("Start")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hoveredAction == command
                        ? color.opacity(0.08) : .clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredAction = isHovered ? command : nil
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Text(l.timeAgo(viewModel.lastUpdated))
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                launchAtLogin.toggle()
                do {
                    if launchAtLogin {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: launchAtLogin ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                    Text(l.autoStart)
                        .font(.system(size: 13))
                }
                .foregroundColor(launchAtLogin ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text("\u{00B7}")
                .foregroundColor(.secondary.opacity(0.3))

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text(l.quit)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { showAbout = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(l.back)
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text(l.aboutTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            VStack(spacing: 16) {
                // App icon + name
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.2)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundColor(.purple)
                    }
                    .frame(width: 56, height: 56)

                    Text("Deus eX AI")
                        .font(.system(size: 18, weight: .bold))

                    Text("\(l.aboutVersion) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Description
                Text(l.aboutBody)
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Features
                VStack(alignment: .leading, spacing: 6) {
                    aboutFeature(icon: "chart.bar.fill", color: .purple,
                                 text: lang == "ko" ? "실시간 토큰 사용량 추적" : "Real-time token usage tracking")
                    aboutFeature(icon: "gauge.with.needle.fill", color: .teal,
                                 text: lang == "ko" ? "AI 쿼터 모니터링" : "AI quota monitoring")
                    aboutFeature(icon: "bolt.fill", color: .orange,
                                 text: lang == "ko" ? "원클릭 시스템 관리" : "One-click system management")
                    aboutFeature(icon: "trophy.fill", color: .yellow,
                                 text: lang == "ko" ? "게이미피케이션 랭크 시스템" : "Gamified rank system")
                }

                // GitHub link
                Button(action: {
                    if let url = URL(string: "https://github.com/glen15/dxai") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text("Star on GitHub")
                            .font(.system(size: 12, weight: .medium))
                        Text("glen15/dxai")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            HStack {
                Spacer()
                Button(l.aboutDismiss) { showAbout = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    private func aboutFeature(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
        }
    }

    // MARK: - Insights

    private var insightsNavigationView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { showInsights = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(l.back)
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text(l.insightsTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            InsightsView(stats: viewModel.weeklyStats)

            Divider()

            HStack {
                Spacer()
                Button(l.close) { showInsights = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Helpers

    private func formatCompact(_ n: Int) -> String {
        if n >= 1_000_000_000 { return String(format: "%.0fB", Double(n) / 1_000_000_000) }
        if n >= 1_000_000 { return String(format: "%.0fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        }
        if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }


    private func pioneerColor(_ level: DxaiViewModel.PioneerLevel?) -> Color {
        guard let level else { return .purple }
        switch level.tier {
        case .bronze:      return .orange
        case .silver:      return .gray
        case .gold:        return .yellow
        case .platinum:    return .teal
        case .diamond:     return .cyan
        case .master:      return .purple
        case .grandmaster: return .red
        case .challenger:  return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    private var pioneerGradient: LinearGradient {
        let c = pioneerColor(viewModel.pioneerLevel)
        return LinearGradient(colors: [c, c.opacity(0.6)],
                              startPoint: .leading, endPoint: .trailing)
    }

    private var pioneerProgress: Double {
        let tokens = viewModel.todayTokens
        guard let next = DxaiViewModel.PioneerLevel.nextLevel(after: viewModel.pioneerLevel) else {
            return 1.0
        }
        let prev = viewModel.pioneerLevel?.threshold ?? 0
        guard next.threshold > prev else { return 1.0 }
        return min(1.0, Double(tokens - prev) / Double(next.threshold - prev))
    }

    private func quotaColor(_ pct: Int) -> Color {
        if pct >= 80 { return .red }
        if pct >= 50 { return .yellow }
        return .green
    }

    private func formatResetDate(_ date: Date) -> String {
        let seconds = Int(date.timeIntervalSinceNow)
        if seconds <= 0 { return l.resetSoon }
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func relaunchApp() {
        let exe = ProcessInfo.processInfo.arguments[0]
        let bundleURL = Bundle.main.bundleURL

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")

        // .app 번들이면 open으로 재실행, 아니면 바이너리 직접 실행
        if bundleURL.pathExtension == "app" {
            task.arguments = ["-c", "sleep 0.5 && open -n \"\(bundleURL.path)\""]
        } else {
            task.arguments = ["-c", "sleep 0.5 && \"\(exe)\""]
        }

        try? task.run()
        exit(0)
    }

    private func runInTerminal(_ command: String) {
        let dxaiPath = findDxaiPath()
        let fullCommand = command.isEmpty ? dxaiPath : "\(dxaiPath) \(command)"
        let script = """
        tell application "Terminal"
            activate
            do script "\(fullCommand)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func findDxaiPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/dxai",
            "/usr/local/bin/dxai",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        let devPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/work/dxai/dxai").path
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        return "dxai"
    }
}
