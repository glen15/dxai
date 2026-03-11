import Foundation
import UserNotifications
import Combine

@MainActor
final class DxaiViewModel: ObservableObject {
    @Published var todayTokens: Int = 0
    @Published var toolStats: [DxaiDatabase.DailyStats] = []
    @Published var claudeQuota: DxaiDatabase.QuotaInfo?
    @Published var codexQuota: DxaiDatabase.QuotaInfo?
    @Published var vanguardLevel: VanguardLevel?
    @Published var lastUpdated: Date = Date()
    @Published var systemStatus: SystemStatus?
    @Published var scanResult: ScanResult?
    @Published var weeklyStats: [DxaiDatabase.DailyStats] = []
    @Published var todayCoins: Int = 0
    @Published var weeklyCoins: Int = 0
    @Published var totalCoins: Int = 0

    var weeklyTokenTotal: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let dates = Set((0...6).map { fmt.string(from: cal.date(byAdding: .day, value: -$0, to: today)!) })
        return weeklyStats.filter { dates.contains($0.date) }.reduce(0) { $0 + $1.totalTokens }
    }

    private var timer: Timer?
    private var lastNotifiedLevel: VanguardLevel?
    private var lastNotifiedMilestone: Int = 0
    private var milestoneBaselineSet: Bool = false
    private var milestoneDate: String = ""  // "yyyy-MM-dd"

    // MARK: - Task Execution
    @Published var showTaskPanel = false
    @Published var isTaskRunning = false
    @Published var taskTitle = ""
    @Published var taskOutput = ""
    @Published var isJsonTask = false
    private var taskProcess: Process?

    // MARK: - Vanguard Level System

    struct VanguardLevel: Equatable {
        let tier: Tier
        let division: Int?   // nil = Challenger (no division)
        let threshold: Int

        var displayName: String {
            if let div = division {
                return "\(tier.rawValue) \(div)"
            }
            return tier.rawValue
        }

        var emoji: String { tier.emoji }
        var message: String { tier.message(division: division) }

        static func == (lhs: VanguardLevel, rhs: VanguardLevel) -> Bool {
            lhs.tier == rhs.tier && lhs.division == rhs.division
        }

        enum Tier: String, Equatable {
            case bronze = "Bronze"
            case silver = "Silver"
            case gold = "Gold"
            case platinum = "Platinum"
            case diamond = "Diamond"
            case master = "Master"
            case grandmaster = "Grandmaster"
            case challenger = "Challenger"

            var emoji: String {
                switch self {
                case .bronze:      return "\u{1F949}"  // medal
                case .silver:      return "\u{1F948}"
                case .gold:        return "\u{1F947}"
                case .platinum:    return "\u{1F4A0}"  // diamond shape
                case .diamond:     return "\u{1F48E}"
                case .master:      return "\u{1F3C6}"  // trophy
                case .grandmaster: return "\u{1F451}"  // crown
                case .challenger:  return "\u{26A1}"   // lightning
                }
            }

            func message(division: Int?) -> String {
                L().vanguardMessage(self.rawValue, division: division)
            }
        }

        // All levels sorted by threshold (ascending)
        static let all: [VanguardLevel] = {
            var levels: [VanguardLevel] = []

            // 기준: 아침 가벼운 사용 ~15M = Gold 중반
            //       하루 풀 작업 ~50M = Platinum 진입
            //       하루 헤비 ~100M = Platinum 후반
            //       Diamond 이상 = 진정한 도전과제
            let tiers: [(Tier, [Int])] = [
                (.bronze,      [10_000, 25_000, 50_000, 100_000, 250_000]),
                (.silver,      [500_000, 1_000_000, 2_000_000, 3_500_000, 5_000_000]),
                (.gold,        [8_000_000, 12_000_000, 18_000_000, 25_000_000, 35_000_000]),
                (.platinum,    [50_000_000, 70_000_000, 100_000_000, 130_000_000, 170_000_000]),
                (.diamond,     [220_000_000, 280_000_000, 350_000_000, 430_000_000, 520_000_000]),
                (.master,      [620_000_000, 750_000_000, 880_000_000, 1_000_000_000, 1_200_000_000]),
                (.grandmaster, [1_500_000_000, 1_800_000_000, 2_200_000_000, 2_700_000_000, 3_300_000_000]),
            ]

            for (tier, thresholds) in tiers {
                for (i, threshold) in thresholds.enumerated() {
                    levels.append(VanguardLevel(
                        tier: tier,
                        division: 5 - i,
                        threshold: threshold
                    ))
                }
            }

            levels.append(VanguardLevel(
                tier: .challenger,
                division: nil,
                threshold: 5_000_000_000
            ))

            return levels
        }()

        static func forTokens(_ tokens: Int) -> VanguardLevel? {
            var result: VanguardLevel?
            for level in all {
                if tokens >= level.threshold {
                    result = level
                } else {
                    break
                }
            }
            return result
        }

        static func nextLevel(after current: VanguardLevel?) -> VanguardLevel? {
            guard let current else { return all.first }
            guard let idx = all.firstIndex(of: current),
                  idx + 1 < all.count else { return nil }
            return all[idx + 1]
        }
    }

    var menuBarLabel: String {
        formatTokens(todayTokens)
    }

    private var notificationsAvailable = false
    private let notificationDelegate = NotificationDelegate()

    init() {
        setupNotifications()
        refresh()
        startTimer()
    }

    private func setupNotifications() {
        if Bundle.main.bundleIdentifier != nil {
            notificationsAvailable = true
            let center = UNUserNotificationCenter.current()
            center.delegate = notificationDelegate
            requestNotificationPermission()
        }
    }

    func refresh(force: Bool = false) {
        let db = DxaiDatabase.shared
        if force { db.invalidateClaudeQuotaCache() }
        let stats = db.todayStats()
        toolStats = stats
        todayTokens = stats.reduce(0) { $0 + $1.totalTokens }
        if let q = db.claudeQuota() { claudeQuota = q }
        if let q = db.codexQuota() { codexQuota = q }
        lastUpdated = Date()

        let newLevel = VanguardLevel.forTokens(todayTokens)
        if let level = newLevel, level != lastNotifiedLevel {
            vanguardLevel = level
            lastNotifiedLevel = level
            sendVanguardNotification(level)
        } else {
            vanguardLevel = newLevel
        }

        checkTokenMilestone()

        // Vanguard Coin 기록
        updateCoins()

        // 백그라운드에서 주간 데이터 미리 로드
        Task.detached {
            let weekly = db.weeklyStats()
            await MainActor.run { [weak self] in
                self?.weeklyStats = weekly
            }
        }
    }

    // MARK: - Vanguard Coins

    private func updateCoins() {
        let ps = DxaiPointService.shared
        ps.finalizePreviousDay()

        if let level = vanguardLevel {
            let claudeTokens = toolStats.filter { $0.tool == "claude" }.reduce(0) { $0 + $1.totalTokens }
            let codexTokens = toolStats.filter { $0.tool == "codex" }.reduce(0) { $0 + $1.totalTokens }
            ps.recordDailyBest(
                tier: level.tier.rawValue,
                division: level.division,
                claudeTokens: claudeTokens,
                codexTokens: codexTokens
            )
        }

        todayCoins = ps.todayCoins
        weeklyCoins = ps.weeklyCoins
        totalCoins = ps.totalCoins

        // 미제출 건 재시도
        ps.retryPendingSubmissions()
    }

    // MARK: - Token Milestones

    struct MilestoneInfo {
        let currentTitle: String
        let currentBody: String
        let nextTitle: String?
        let nextThreshold: Int?
        let progress: Double  // 0.0 ~ 1.0 within current→next range
    }

    var currentMilestoneInfo: MilestoneInfo {
        let milestones = Self.tokenMilestones
        let current = milestones.last(where: { todayTokens >= $0.threshold })
        let currentIdx = current.flatMap { c in milestones.firstIndex(where: { $0.threshold == c.threshold }) }
        let next = currentIdx.flatMap { i in i + 1 < milestones.count ? milestones[i + 1] : nil }

        let progress: Double
        if let current, let next {
            let range = next.threshold - current.threshold
            progress = range > 0 ? min(1.0, Double(todayTokens - current.threshold) / Double(range)) : 0
        } else if current == nil, let first = milestones.first {
            progress = min(1.0, Double(todayTokens) / Double(first.threshold))
        } else {
            progress = 1.0
        }

        return MilestoneInfo(
            currentTitle: current?.title ?? "---",
            currentBody: current?.body ?? "",
            nextTitle: next?.title,
            nextThreshold: next?.threshold,
            progress: progress
        )
    }

    func resendLastMilestone() {
        if let milestone = Self.tokenMilestones.last(where: { todayTokens >= $0.threshold }) {
            sendMilestoneNotification(milestone)
        }
    }

    private static var tokenMilestones: [(threshold: Int, title: String, body: String)] {
        L().milestones
    }

    private func checkTokenMilestone() {
        // 날짜 변경 감지 → 리셋
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        if today != milestoneDate {
            milestoneDate = today
            milestoneBaselineSet = false
            lastNotifiedMilestone = 0
        }

        // 첫 실행/새 날: 가장 최근 마일스톤 1개만 알림 + 베이스라인 설정
        if !milestoneBaselineSet {
            milestoneBaselineSet = true
            if let highest = Self.tokenMilestones.last(where: { todayTokens >= $0.threshold }) {
                lastNotifiedMilestone = highest.threshold
                sendMilestoneNotification(highest)
            }
            return
        }

        // 새로 넘은 마일스톤 모두 발사 (오름차순)
        let pending = Self.tokenMilestones.filter {
            todayTokens >= $0.threshold && $0.threshold > lastNotifiedMilestone
        }
        for milestone in pending {
            lastNotifiedMilestone = milestone.threshold
            sendMilestoneNotification(milestone)
        }
    }

    private func sendMilestoneNotification(_ milestone: (threshold: Int, title: String, body: String)) {
        let title = "\u{2694}\u{FE0F} \(milestone.title)"
        let body = milestone.body

        if notificationsAvailable {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "milestone-\(milestone.threshold)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        } else {
            sendViaOsascript(title: title, body: body)
        }
    }

    private nonisolated func sendViaOsascript(title: String, body: String) {
        let escaped = { (s: String) in s.replacingOccurrences(of: "\"", with: "\\\"") }
        let script = "display notification \"\(escaped(body))\" with title \"\(escaped(title))\" sound name \"default\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        }
        if n >= 1_000 {
            return String(format: "%.0fK", Double(n) / 1_000)
        }
        return "\(n)"
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendVanguardNotification(_ level: VanguardLevel) {
        let title = "\(level.emoji) \(level.displayName)"
        let body = level.message

        if notificationsAvailable {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "vanguard-\(level.displayName)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        } else {
            sendViaOsascript(title: title, body: body)
        }
    }

    // MARK: - Task Execution

    func runTask(title: String, command: String, needsAdmin: Bool = false) {
        // 이미 실행 중이면 패널만 다시 열기
        if isTaskRunning {
            showTaskPanel = true
            return
        }

        taskTitle = title
        taskOutput = ""
        systemStatus = nil
        scanResult = nil
        isTaskRunning = true
        isJsonTask = command.contains("--json") || command.starts(with: "status")
        showTaskPanel = true

        let dxaiPath = Self.findDxaiPath()

        Task.detached { [weak self] in
            if needsAdmin {
                let acquired = Self.acquireAdmin()
                if !acquired {
                    await MainActor.run {
                        self?.taskOutput = L().adminCancelled
                        self?.isTaskRunning = false
                    }
                    return
                }
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "\(dxaiPath) \(command)"]

            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "dumb"
            env["NO_COLOR"] = "1"
            let path = env["PATH"] ?? ""
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(path)"
            process.environment = env

            // stdin을 /dev/null로 연결 → interactive read가 즉시 EOF → 스킵
            process.standardInput = FileHandle.nullDevice

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            await MainActor.run { self?.taskProcess = process }

            do {
                try process.run()
            } catch {
                await MainActor.run {
                    self?.taskOutput = L().execFailed(error.localizedDescription)
                    self?.isTaskRunning = false
                }
                return
            }

            // 5분 타임아웃 (Swift 레벨)
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 300_000_000_000)
                if process.isRunning { process.terminate() }
            }

            let handle = outputPipe.fileHandleForReading
            let isJson = await MainActor.run { self?.isJsonTask ?? false }

            if isJson {
                // JSON 커맨드: 전체 출력을 한번에 읽기 (버퍼링 문제 방지)
                process.waitUntilExit()
                let allData = handle.readDataToEndOfFile()
                if let str = String(data: allData, encoding: .utf8) {
                    let clean = Self.stripANSI(str)
                    await MainActor.run { self?.taskOutput = clean }
                }
            } else {
                // 인터랙티브 커맨드: 스트리밍 출력
                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }
                    if let str = String(data: data, encoding: .utf8) {
                        let clean = Self.stripANSI(str)
                        await MainActor.run { self?.taskOutput += clean }
                    }
                }
                process.waitUntilExit()
            }
            timeoutTask.cancel()
            await MainActor.run {
                if let output = self?.taskOutput {
                    NSLog("[DxaiTask] output length=\(output.count), starts=\(String(output.prefix(40)))")
                    if self?.systemStatus == nil, let status = SystemStatus.parse(from: output) {
                        NSLog("[DxaiTask] → SystemStatus parsed")
                        self?.systemStatus = status
                    } else if self?.scanResult == nil, let scan = ScanResult.parse(from: output) {
                        NSLog("[DxaiTask] → ScanResult parsed")
                        self?.scanResult = scan
                    } else if self?.systemStatus == nil, let formatted = Self.formatStatusJSON(output) {
                        NSLog("[DxaiTask] → formatStatusJSON matched")
                        self?.taskOutput = formatted
                    } else {
                        NSLog("[DxaiTask] → NO parser matched")
                    }
                }
                // JSON 파싱 성공했으면 플래그 해제
                if self?.systemStatus != nil || self?.scanResult != nil {
                    self?.isJsonTask = false
                }
                if process.terminationStatus == 137 || process.terminationStatus == 143 {
                    self?.taskOutput += "\n\n\(L().timedOut)"
                }
                // JSON 태스크인데 파싱 실패한 경우 raw 출력 보여주기
                if self?.isJsonTask == true {
                    self?.isJsonTask = false
                }
                self?.isTaskRunning = false
                self?.taskProcess = nil
            }
        }
    }

    func hideTaskPanel() {
        showTaskPanel = false
    }

    func showRunningTask() {
        showTaskPanel = true
    }

    func stopTask() {
        taskProcess?.terminate()
        taskProcess = nil
        isTaskRunning = false
        isJsonTask = false
        showTaskPanel = false
        taskOutput = ""
        taskTitle = ""
        systemStatus = nil
        scanResult = nil
    }

    private nonisolated static func acquireAdmin() -> Bool {
        let tmpDir = FileManager.default.temporaryDirectory
        let askpass = tmpDir.appendingPathComponent("dxai-askpass-\(UUID().uuidString).sh")

        let script = """
        #!/bin/bash
        osascript -e 'display dialog "dxai에 관리자 권한이 필요합니다." default answer "" with hidden answer with title "dxai" with icon caution' -e 'text returned of result' 2>/dev/null
        """

        do {
            try script.write(to: askpass, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: askpass.path)
        } catch {
            return false
        }

        defer { try? FileManager.default.removeItem(at: askpass) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-A", "-v"]

        var env = ProcessInfo.processInfo.environment
        env["SUDO_ASKPASS"] = askpass.path
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private nonisolated static func formatStatusJSON(_ raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}") else { return nil }
        let jsonStr = String(raw[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              d["hardware"] != nil else {
            return nil
        }

        func gb(_ bytes: Any?) -> String {
            if let n = bytes as? Int { return String(format: "%.1f", Double(n) / 1_073_741_824) }
            if let n = bytes as? Double { return String(format: "%.1f", n / 1_073_741_824) }
            return "?"
        }

        var lines: [String] = []

        // Hardware
        let hw = d["hardware"] as? [String: Any] ?? [:]
        lines.append("\(hw["model"] ?? "") · \(hw["cpu_model"] ?? "")")
        lines.append("\(hw["total_ram"] ?? "") RAM · \(hw["disk_size"] ?? "") Disk")
        lines.append("\(hw["os_version"] ?? d["os_version"] ?? "") · Uptime \(d["uptime"] ?? "") · \(hw["refresh_rate"] ?? "")")

        // Health
        lines.append("")
        let score = d["health_score"] as? Int ?? 0
        lines.append("Health        \(score)/100 (\(d["health_score_msg"] ?? ""))")

        // CPU
        if let c = d["cpu"] as? [String: Any] {
            let usage = c["usage"] as? Double ?? 0
            let cores = c["core_count"] as? Int ?? 0
            lines.append("")
            lines.append("CPU           \(String(format: "%.1f", usage))%  (\(cores) cores)")
        }

        // Memory (values are bytes as Int)
        if let m = d["memory"] as? [String: Any] {
            let usedPct = m["used_percent"] as? Double ?? 0
            lines.append("Memory        \(gb(m["used"])) / \(gb(m["total"])) GB (\(String(format: "%.0f", usedPct))%)")
            let swapUsed = m["swap_used"] as? Int ?? 0
            if swapUsed > 0 {
                lines.append("Swap          \(gb(m["swap_used"])) / \(gb(m["swap_total"])) GB")
            }
        }

        // Disk (from hardware since disk can be null)
        lines.append("Disk          \(hw["disk_size"] ?? "?")")

        // Network (array of interfaces)
        if let nets = d["network"] as? [[String: Any]] {
            let active = nets.filter { ($0["ip"] as? String ?? "").count > 0 }
            for iface in active {
                let name = iface["name"] as? String ?? ""
                let ip = iface["ip"] as? String ?? ""
                let rx = iface["rx_rate_mbs"] as? Double ?? 0
                let tx = iface["tx_rate_mbs"] as? Double ?? 0
                lines.append("Network       \(name) (\(ip))  \u{2191}\(String(format: "%.2f", tx)) \u{2193}\(String(format: "%.2f", rx)) MB/s")
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private nonisolated static func stripANSI(_ str: String) -> String {
        str.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[a-zA-Z]",
            with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: "\u{1B}\\][^\u{07}]*\u{07}",
            with: "", options: .regularExpression
        )
        .replacingOccurrences(of: "\r", with: "")
    }

    private nonisolated static func findDxaiPath() -> String {
        // 1. 앱 번들 내 CLI 우선 (Resources/dxai)
        if let bundled = Bundle.main.path(forResource: "dxai", ofType: nil) {
            return bundled
        }
        // 2. Homebrew / 시스템 경로
        let candidates = [
            "/opt/homebrew/bin/dxai",
            "/usr/local/bin/dxai",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // 3. 개발 경로
        let devPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/work/dxai/dxai").path
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }
        return "dxai"
    }
}

// MARK: - Foreground Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
