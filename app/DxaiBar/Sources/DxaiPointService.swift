import Foundation

/// DXAI Point 시스템 — 일일 Pioneer Rank를 포인트로 변환, 로컬 누적 저장 + 서버 제출
final class DxaiPointService {
    static let shared = DxaiPointService()

    private let configURL: URL
    private let historyURL: URL
    private let pendingURL: URL

    private(set) var config: PointConfig
    private(set) var history: [DailyRecord]
    private var pendingQueue: [SubmissionPayload]
    private var isSubmitting = false

    // MARK: - Types

    struct PointConfig: Codable {
        var nickname: String
        var optIn: Bool
        var deviceUUID: String
        var lastRecordedDate: String  // "yyyy-MM-dd"

        static var `default`: PointConfig {
            PointConfig(
                nickname: "",
                optIn: false,
                deviceUUID: UUID().uuidString,
                lastRecordedDate: ""
            )
        }
    }

    struct DailyRecord: Codable {
        let date: String
        let pioneerTier: String
        let pioneerDivision: Int?
        let dailyPoints: Int
        let claudeTokens: Int
        let codexTokens: Int
        let totalPoints: Int  // cumulative at end of day
    }

    struct SubmissionPayload: Codable {
        let device_uuid: String
        let nickname: String
        let date: String
        let daily_points: Int
        let total_points: Int
        let claude_tokens: Int
        let codex_tokens: Int
        let pioneer_tier: String
        let pioneer_division: Int?
    }

    struct SubmissionResponse: Codable {
        let ok: Bool
        let total_points: Int?
        let total_coins: Int?
        let rank: Int?
        let error: String?
    }

    // MARK: - Point Formula

    private static let pointTable: [(tier: String, base: Int, bonus: Int)] = [
        ("Bronze",      10,   2),
        ("Silver",      25,   5),
        ("Gold",        60,  12),
        ("Platinum",   150,  30),
        ("Diamond",    350,  70),
        ("Master",     800, 160),
        ("Grandmaster",1800, 360),
    ]

    static func calculatePoints(tier: String, division: Int?) -> Int {
        if tier == "Challenger" { return 5000 }
        guard let entry = pointTable.first(where: { $0.tier == tier }),
              let div = division else { return 0 }
        return entry.base + entry.bonus * (5 - div)
    }

    // MARK: - Init

    // MARK: - Server Config

    private static let submitURL = "https://ldsqtmirplfgclzessrd.supabase.co/functions/v1/submit-daily"

    private init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/dxai/points")
        configURL = base.appendingPathComponent("config.json")
        historyURL = base.appendingPathComponent("history.json")
        pendingURL = base.appendingPathComponent("pending.json")

        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        config = Self.load(configURL) ?? .default
        history = Self.load(historyURL) ?? []
        pendingQueue = Self.load(pendingURL) ?? []
    }

    // MARK: - Public API

    var totalPoints: Int {
        history.last?.totalPoints ?? 0
    }

    var todayPoints: Int {
        let today = Self.todayString()
        return history.last(where: { $0.date == today })?.dailyPoints ?? 0
    }

    var weeklyPoints: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let dates = Set((0...6).map { fmt.string(from: cal.date(byAdding: .day, value: -$0, to: today)!) })
        return history.filter { dates.contains($0.date) }.reduce(0) { $0 + $1.dailyPoints }
    }

    var recentHistory: [DailyRecord] {
        Array(history.suffix(30))
    }

    /// refresh() 시 호출 — 오늘의 Pioneer Rank + 토큰 기록
    func recordDailyBest(tier: String, division: Int?, claudeTokens: Int, codexTokens: Int) {
        let today = Self.todayString()
        let points = Self.calculatePoints(tier: tier, division: division)
        var changed = false

        if let idx = history.firstIndex(where: { $0.date == today }) {
            let existing = history[idx]
            let newPoints = max(points, existing.dailyPoints)
            let newTier = points >= existing.dailyPoints ? tier : existing.pioneerTier
            let newDiv = points >= existing.dailyPoints ? division : existing.pioneerDivision
            let tokensChanged = claudeTokens != existing.claudeTokens || codexTokens != existing.codexTokens
            guard points > existing.dailyPoints || tokensChanged else { return }
            let cumulative = totalPointsExcluding(today) + newPoints
            history[idx] = DailyRecord(
                date: today,
                pioneerTier: newTier,
                pioneerDivision: newDiv,
                dailyPoints: newPoints,
                claudeTokens: claudeTokens,
                codexTokens: codexTokens,
                totalPoints: cumulative
            )
            changed = true
        } else {
            let cumulative = totalPoints + points
            history.append(DailyRecord(
                date: today,
                pioneerTier: tier,
                pioneerDivision: division,
                dailyPoints: points,
                claudeTokens: claudeTokens,
                codexTokens: codexTokens,
                totalPoints: cumulative
            ))
            changed = true
        }

        guard changed else { return }
        config.lastRecordedDate = today
        save()

        if config.optIn && !config.nickname.isEmpty {
            submitToServer(date: today)
        }
    }

    /// 날짜 변경 감지 — 전날 데이터 확정
    func finalizePreviousDay() {
        let today = Self.todayString()
        guard config.lastRecordedDate != today,
              !config.lastRecordedDate.isEmpty else { return }
        // 전날 기록이 이미 있으면 별도 처리 불필요 — recordDailyBest가 관리
        config.lastRecordedDate = today
        save()
    }

    // MARK: - Config Mutation

    func updateNickname(_ name: String) {
        config.nickname = name
        saveConfig()
    }

    func updateOptIn(_ value: Bool) {
        config.optIn = value
        saveConfig()
    }

    // MARK: - Submission Data Preview

    func submissionPreview(claudeTokens: Int, codexTokens: Int) -> String {
        let today = Self.todayString()
        let record = history.last(where: { $0.date == today })
        let pts = record?.dailyPoints ?? 0
        return """
        {
          "nickname": "\(config.nickname)",
          "date": "\(today)",
          "daily_points": \(pts),
          "total_points": \(totalPoints),
          "claude_tokens": \(claudeTokens),
          "codex_tokens": \(codexTokens)
        }
        """
    }

    // MARK: - Private

    private func totalPointsExcluding(_ date: String) -> Int {
        history.filter { $0.date != date }.last?.totalPoints
            ?? (history.count > 1 ? history[history.count - 2].totalPoints : 0)
    }

    private func save() {
        saveConfig()
        saveHistory()
    }

    private func saveConfig() {
        Self.write(config, to: configURL)
    }

    private func saveHistory() {
        // 최근 365일만 유지
        if history.count > 365 {
            history = Array(history.suffix(365))
        }
        Self.write(history, to: historyURL)
    }

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: Date())
    }

    // MARK: - Server Submission

    /// 오늘 기록을 서버에 제출 (fire-and-forget)
    private func submitToServer(date: String) {
        guard let record = history.last(where: { $0.date == date }) else { return }

        let payload = SubmissionPayload(
            device_uuid: config.deviceUUID,
            nickname: config.nickname,
            date: date,
            daily_points: record.dailyPoints,
            total_points: record.totalPoints,
            claude_tokens: record.claudeTokens,
            codex_tokens: record.codexTokens,
            pioneer_tier: record.pioneerTier,
            pioneer_division: record.pioneerDivision
        )

        sendPayload(payload)
    }

    /// pending queue에 있는 미제출 건도 같이 처리
    func retryPendingSubmissions() {
        guard config.optIn, !pendingQueue.isEmpty, !isSubmitting else { return }
        let batch = pendingQueue
        pendingQueue.removeAll()
        savePending()
        for payload in batch {
            sendPayload(payload)
        }
    }

    private func sendPayload(_ payload: SubmissionPayload) {
        guard let url = URL(string: Self.submitURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let encoder = JSONEncoder()
        guard let body = try? encoder.encode(payload) else { return }
        request.httpBody = body

        isSubmitting = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.isSubmitting = false }

            // 네트워크 실패 → pending queue에 추가
            if error != nil {
                self?.enqueuePending(payload)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                self?.enqueuePending(payload)
                return
            }

            // 서버 에러 (5xx) → 재시도 대상
            if httpResponse.statusCode >= 500 {
                self?.enqueuePending(payload)
                return
            }

            // 4xx (닉네임 중복, 유효성 실패 등) → 재시도 안 함, 로그만
            if httpResponse.statusCode >= 400 {
                if let resp = try? JSONDecoder().decode(SubmissionResponse.self, from: data) {
                    NSLog("[DxaiPoint] Submit rejected: \(resp.error ?? "unknown")")
                }
                return
            }

            // 성공
            if let resp = try? JSONDecoder().decode(SubmissionResponse.self, from: data) {
                NSLog("[DxaiPoint] Submitted: rank=\(resp.rank ?? 0), total=\(resp.total_points ?? 0)")
            }
        }.resume()
    }

    private func enqueuePending(_ payload: SubmissionPayload) {
        // 같은 날짜의 기존 pending 제거 (최신 것만 유지)
        pendingQueue.removeAll { $0.date == payload.date && $0.device_uuid == payload.device_uuid }
        pendingQueue.append(payload)
        // 최대 30건 유지
        if pendingQueue.count > 30 {
            pendingQueue = Array(pendingQueue.suffix(30))
        }
        savePending()
    }

    private func savePending() {
        Self.write(pendingQueue, to: pendingURL)
    }

    // MARK: - Persistence Helpers

    private static func load<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
