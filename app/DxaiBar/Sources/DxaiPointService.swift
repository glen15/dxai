import Foundation

/// DXAI Point 시스템 — 일일 Pioneer Rank를 포인트로 변환, 로컬 누적 저장
final class DxaiPointService {
    static let shared = DxaiPointService()

    private let configURL: URL
    private let historyURL: URL

    private(set) var config: PointConfig
    private(set) var history: [DailyRecord]

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

    private init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/dxai/points")
        configURL = base.appendingPathComponent("config.json")
        historyURL = base.appendingPathComponent("history.json")

        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        config = Self.load(configURL) ?? .default
        history = Self.load(historyURL) ?? []
    }

    // MARK: - Public API

    var totalPoints: Int {
        history.last?.totalPoints ?? 0
    }

    var todayPoints: Int {
        let today = Self.todayString()
        return history.last(where: { $0.date == today })?.dailyPoints ?? 0
    }

    var recentHistory: [DailyRecord] {
        Array(history.suffix(30))
    }

    /// refresh() 시 호출 — 오늘의 최고 Pioneer Rank 기록
    func recordDailyBest(tier: String, division: Int?, claudeTokens: Int, codexTokens: Int) {
        let today = Self.todayString()
        let points = Self.calculatePoints(tier: tier, division: division)

        if let idx = history.firstIndex(where: { $0.date == today }) {
            let existing = history[idx]
            // 더 높은 포인트일 때만 갱신
            guard points > existing.dailyPoints else { return }
            let cumulative = (totalPointsExcluding(today)) + points
            history[idx] = DailyRecord(
                date: today,
                pioneerTier: tier,
                pioneerDivision: division,
                dailyPoints: points,
                claudeTokens: claudeTokens,
                codexTokens: codexTokens,
                totalPoints: cumulative
            )
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
        }

        config.lastRecordedDate = today
        save()
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
