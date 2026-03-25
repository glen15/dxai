import Foundation

/// Vanguard Coin 시스템 — 일일 Vanguard Rank를 코인으로 변환, SQLite 저장 + 서버 제출
final class DxaiPointService {
    static let shared = DxaiPointService()

    private let store = DxaiStore.shared
    private var isSubmitting = false

    // MARK: - Types

    struct SubmissionPayload: Codable {
        let device_uuid: String
        let nickname: String
        let date: String
        let daily_coins: Int
        let claude_tokens: Int
        let codex_tokens: Int
        let vanguard_tier: String
        let vanguard_division: Int?
        let secret_token: String?
    }

    struct SubmissionResponse: Codable {
        let ok: Bool
        let total_coins: Int?
        let total_tokens: Int?
        let rank: Int?
        let live_rank: Int?
        let secret_token: String?
        let error: String?
    }

    // MARK: - Coin Formula

    private static let coinTable: [(tier: String, base: Int, bonus: Int)] = [
        ("Bronze",      10,   2),
        ("Silver",      25,   5),
        ("Gold",        60,  12),
        ("Platinum",   150,  30),
        ("Diamond",    350,  70),
        ("Master",     800, 160),
        ("Grandmaster",1800, 360),
    ]

    static func calculateCoins(tier: String, division: Int?) -> Int {
        if tier == "Challenger" { return 5000 }
        guard let entry = coinTable.first(where: { $0.tier == tier }),
              let div = division else { return 0 }
        return entry.base + entry.bonus * (5 - div)
    }

    // MARK: - Server Config

    private static let submitURL = "https://ldsqtmirplfgclzessrd.supabase.co/functions/v1/submit-daily"
    private static let leaderboardURL = "https://ldsqtmirplfgclzessrd.supabase.co/functions/v1/leaderboard"
    private static let submitAPIKey: String = Bundle.main.infoDictionary?["SubmitAPIKey"] as? String ?? ""

    private init() {
        serverTotalTokens = store.getConfigInt("cached_total_tokens") ?? 0
        serverLiveRank = store.getConfigInt("cached_live_rank") ?? 0
    }

    // MARK: - Config Accessors

    var nickname: String {
        store.getConfig("nickname") ?? ""
    }

    var optIn: Bool {
        store.getConfig("opt_in") != "0"
    }

    var deviceUUID: String {
        if let uuid = store.getConfig("device_uuid") { return uuid }
        let uuid = UUID().uuidString
        store.setConfig("device_uuid", uuid)
        return uuid
    }

    var lastRecordedDate: String {
        store.getConfig("last_recorded_date") ?? ""
    }

    // MARK: - Public API

    private(set) var serverTotalTokens: Int = 0 {
        didSet {
            guard serverTotalTokens != oldValue else { return }
            store.setConfigInt("cached_total_tokens", serverTotalTokens)
        }
    }

    private(set) var serverLiveRank: Int = 0 {
        didSet {
            guard serverLiveRank != oldValue else { return }
            store.setConfigInt("cached_live_rank", serverLiveRank)
        }
    }

    var totalCoins: Int {
        store.lastDailyRecord()?.totalCoins ?? 0
    }

    var todayCoins: Int {
        store.getDailyRecord(date: Self.todayString())?.dailyCoins ?? 0
    }

    var weeklyCoins: Int {
        let dates = Self.thisWeekDates()
        return store.dailyRecordsInDates(dates).reduce(0) { $0 + $1.dailyCoins }
    }

    static func thisWeekDates() -> Set<String> {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return Set((0...6).compactMap {
            let d = cal.date(byAdding: .day, value: $0, to: monday)!
            return d <= today ? fmt.string(from: d) : nil
        })
    }

    var history: [DxaiStore.DailyRow] {
        store.allDailyRecords()
    }

    var recentHistory: [DxaiStore.DailyRow] {
        store.recentDailyRecords(limit: 30)
    }

    // MARK: - Record Daily Best

    func recordDailyBest(tier: String, division: Int?, claudeTokens: Int, codexTokens: Int) {
        let today = Self.todayString()
        let points = Self.calculateCoins(tier: tier, division: division)

        if let existing = store.getDailyRecord(date: today) {
            let tokensChanged = claudeTokens != existing.claudeTokens || codexTokens != existing.codexTokens
            guard points > existing.dailyCoins || tokensChanged else { return }
            let newPoints = max(points, existing.dailyCoins)
            let newTier = points >= existing.dailyCoins ? tier : existing.vanguardTier
            let newDiv = points >= existing.dailyCoins ? division : existing.vanguardDivision
            let cumulative = totalCoinsExcluding(today) + newPoints
            store.upsertDailyRecord(DxaiStore.DailyRow(
                date: today, vanguardTier: newTier, vanguardDivision: newDiv,
                dailyCoins: newPoints, claudeTokens: claudeTokens,
                codexTokens: codexTokens, totalCoins: cumulative
            ))
        } else {
            let cumulative = totalCoins + points
            store.upsertDailyRecord(DxaiStore.DailyRow(
                date: today, vanguardTier: tier, vanguardDivision: division,
                dailyCoins: points, claudeTokens: claudeTokens,
                codexTokens: codexTokens, totalCoins: cumulative
            ))
        }

        store.setConfig("last_recorded_date", today)
        store.pruneOldRecords()

        if optIn && !nickname.isEmpty {
            submitToServer(date: today)
        }
    }

    func finalizePreviousDay() {
        let today = Self.todayString()
        guard lastRecordedDate != today, !lastRecordedDate.isEmpty else { return }
        store.setConfig("last_recorded_date", today)
    }

    // MARK: - Config Mutation

    enum NicknameResult {
        case available
        case taken
        case error(String)
    }

    func checkNickname(_ name: String, completion: @escaping (NicknameResult) -> Void) {
        let urlStr = Self.leaderboardURL + "?check_nickname=\(name)&device_uuid=\(deviceUUID)"
        guard let checkURL = URL(string: urlStr) else {
            completion(.error("Invalid URL"))
            return
        }

        var request = URLRequest(url: checkURL)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            if error != nil {
                completion(.error("Network error"))
                return
            }
            guard let data = data,
                  let json = try? JSONDecoder().decode([String: AnyCodable].self, from: data),
                  let available = json["available"]?.boolValue else {
                completion(.available)
                return
            }
            completion(available ? .available : .taken)
        }.resume()
    }

    private struct AnyCodable: Decodable {
        let value: Any
        var boolValue: Bool? { value as? Bool }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let b = try? container.decode(Bool.self) { value = b }
            else if let i = try? container.decode(Int.self) { value = i }
            else if let s = try? container.decode(String.self) { value = s }
            else { value = try container.decode(String.self) }
        }
    }

    func updateNickname(_ name: String) {
        store.setConfig("nickname", name)
        submitCurrentIfReady()
    }

    func updateOptIn(_ value: Bool) {
        store.setConfig("opt_in", value ? "1" : "0")
        if value { submitCurrentIfReady() }
    }

    private func submitCurrentIfReady() {
        let today = Self.todayString()
        guard optIn, !nickname.isEmpty,
              store.getDailyRecord(date: today) != nil else { return }
        submitToServer(date: today)
    }

    // MARK: - Private

    private func totalCoinsExcluding(_ date: String) -> Int {
        let all = store.allDailyRecords()
        return all.last(where: { $0.date != date })?.totalCoins ?? 0
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt
    }()

    private static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    // MARK: - Server Submission

    private func submitToServer(date: String) {
        guard let record = store.getDailyRecord(date: date) else { return }

        let payload = SubmissionPayload(
            device_uuid: deviceUUID,
            nickname: nickname,
            date: date,
            daily_coins: record.dailyCoins,
            claude_tokens: record.claudeTokens,
            codex_tokens: record.codexTokens,
            vanguard_tier: record.vanguardTier,
            vanguard_division: record.vanguardDivision,
            secret_token: Self.loadSecretToken()
        )

        sendPayload(payload)
    }

    func retryPendingSubmissions() {
        guard optIn, !isSubmitting else { return }
        let pending = store.allPending()
        guard !pending.isEmpty else { return }
        store.clearPending()
        for p in pending {
            let payload = SubmissionPayload(
                device_uuid: p.deviceUUID, nickname: p.nickname,
                date: p.date, daily_coins: p.dailyCoins,
                claude_tokens: p.claudeTokens, codex_tokens: p.codexTokens,
                vanguard_tier: p.vanguardTier, vanguard_division: p.vanguardDivision,
                secret_token: p.secretToken
            )
            sendPayload(payload)
        }
    }

    func backfillHistory() {
        guard optIn, !nickname.isEmpty, !isSubmitting else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let cutoffStr = Self.dateFormatter.string(from: cutoff)
        let records = store.allDailyRecords().filter { $0.date >= cutoffStr }
        guard !records.isEmpty else { return }
        NSLog("[DxaiPoint] Backfill: \(records.count)건 제출 시작")
        for record in records {
            let payload = SubmissionPayload(
                device_uuid: deviceUUID, nickname: nickname,
                date: record.date, daily_coins: record.dailyCoins,
                claude_tokens: record.claudeTokens, codex_tokens: record.codexTokens,
                vanguard_tier: record.vanguardTier, vanguard_division: record.vanguardDivision,
                secret_token: Self.loadSecretToken()
            )
            sendPayload(payload)
        }
    }

    private func sendPayload(_ payload: SubmissionPayload) {
        guard let url = URL(string: Self.submitURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !Self.submitAPIKey.isEmpty {
            request.setValue(Self.submitAPIKey, forHTTPHeaderField: "X-API-Key")
        }
        request.timeoutInterval = 15

        let encoder = JSONEncoder()
        guard let body = try? encoder.encode(payload) else { return }
        request.httpBody = body

        isSubmitting = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.isSubmitting = false }

            if error != nil {
                self?.enqueuePending(payload)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                self?.enqueuePending(payload)
                return
            }

            if httpResponse.statusCode >= 500 {
                self?.enqueuePending(payload)
                return
            }

            if httpResponse.statusCode >= 400 {
                if let resp = try? JSONDecoder().decode(SubmissionResponse.self, from: data) {
                    NSLog("[DxaiPoint] Submit rejected: \(resp.error ?? "unknown")")
                }
                return
            }

            if let resp = try? JSONDecoder().decode(SubmissionResponse.self, from: data) {
                if let tokens = resp.total_tokens {
                    self?.serverTotalTokens = tokens
                }
                if let liveRank = resp.live_rank {
                    self?.serverLiveRank = liveRank
                }
                if let token = resp.secret_token {
                    Self.saveSecretToken(token)
                }
                NSLog("[DxaiPoint] Submitted: rank=\(resp.rank ?? 0), live_rank=\(resp.live_rank ?? 0), coins=\(resp.total_coins ?? 0), tokens=\(resp.total_tokens ?? 0)")
            }
        }.resume()
    }

    private func enqueuePending(_ payload: SubmissionPayload) {
        store.addPending(DxaiStore.PendingRow(
            id: nil, deviceUUID: payload.device_uuid, nickname: payload.nickname,
            date: payload.date, dailyCoins: payload.daily_coins,
            claudeTokens: payload.claude_tokens, codexTokens: payload.codex_tokens,
            vanguardTier: payload.vanguard_tier, vanguardDivision: payload.vanguard_division,
            secretToken: payload.secret_token
        ))
    }

    // MARK: - Keychain (Secret Token)

    private static let keychainService = "com.dxai.vanguard"
    private static let keychainAccount = "secret_token"

    static func saveSecretToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func loadSecretToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
