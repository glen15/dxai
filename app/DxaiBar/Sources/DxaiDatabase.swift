import Foundation

/// dxai 실시간 토큰 파서 — .jsonl 직접 파싱 (DB 의존 제거)
final class DxaiDatabase {
    static let shared = DxaiDatabase()

    private let home = FileManager.default.homeDirectoryForCurrentUser

    // Weekly stats 캐시 — 파일 변경 없으면 재파싱 안 함
    private var weeklyCache: [DailyStats]?
    private var weeklyCacheFingerprint: String?

    struct DailyStats {
        let date: String
        let tool: String
        let totalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
        let requests: Int
    }

    // MARK: - Live .jsonl Parsing

    func todayStats() -> [DailyStats] {
        let today = Self.todayString()
        let startOfDay = Self.startOfToday()

        var results: [DailyStats] = []

        let claude = parseClaudeToday(startOfDay: startOfDay)
        if claude.totalTokens > 0 {
            results.append(DailyStats(
                date: today, tool: "claude",
                totalTokens: claude.totalTokens,
                inputTokens: claude.inputTokens,
                outputTokens: claude.outputTokens,
                cacheReadTokens: claude.cacheReadTokens,
                requests: claude.requests
            ))
        }

        let codex = parseCodexToday(startOfDay: startOfDay)
        if codex.totalTokens > 0 {
            results.append(DailyStats(
                date: today, tool: "codex",
                totalTokens: codex.totalTokens,
                inputTokens: codex.inputTokens,
                outputTokens: codex.outputTokens,
                cacheReadTokens: codex.cacheReadTokens,
                requests: codex.requests
            ))
        }

        return results
    }

    // MARK: - Claude .jsonl

    private struct TokenAccum {
        var inputTokens = 0
        var outputTokens = 0
        var cacheReadTokens = 0
        var totalTokens = 0
        var requests = 0
    }

    private func parseClaudeToday(startOfDay: Date) -> TokenAccum {
        var accum = TokenAccum()

        let claudeDir = home.appendingPathComponent(".claude/projects")
        guard let enumerator = FileManager.default.enumerator(
            at: claudeDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return accum }

        let dayStart = startOfDay.timeIntervalSince1970

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }

            // Skip files not modified today
            if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let mdate = vals.contentModificationDate,
               mdate.timeIntervalSince1970 < dayStart {
                continue
            }

            forEachLine(in: url) { lineData in
                guard let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      entry["type"] as? String == "assistant",
                      let message = entry["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any],
                      let timestamp = entry["timestamp"] as? String,
                      let dt = Self.parseISO8601(timestamp),
                      dt >= startOfDay else { return }

                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

                accum.inputTokens += input
                accum.outputTokens += output
                accum.cacheReadTokens += cacheRead
                accum.totalTokens += input + output + cacheRead
                accum.requests += 1
            }
        }

        return accum
    }

    // MARK: - Codex .jsonl

    private func parseCodexToday(startOfDay: Date) -> TokenAccum {
        var accum = TokenAccum()

        let sessionsDir = home.appendingPathComponent(".codex/sessions")
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return accum }

        let dayStart = startOfDay.timeIntervalSince1970

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }

            if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let mdate = vals.contentModificationDate,
               mdate.timeIntervalSince1970 < dayStart {
                continue
            }

            var prevTotals: [String: Int]?

            forEachLine(in: url) { lineData in
                guard let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      entry["type"] as? String == "event_msg",
                      let payload = entry["payload"] as? [String: Any],
                      payload["type"] as? String == "token_count",
                      let info = payload["info"] as? [String: Any],
                      let totalUsage = info["total_token_usage"] as? [String: Any] else { return }

                let cur = [
                    "input":  totalUsage["input_tokens"] as? Int ?? 0,
                    "cached": totalUsage["cached_input_tokens"] as? Int ?? 0,
                    "output": totalUsage["output_tokens"] as? Int ?? 0,
                    "total":  totalUsage["total_tokens"] as? Int ?? 0,
                ]

                let delta: [String: Int]
                if let prev = prevTotals {
                    delta = [
                        "input":  max(0, cur["input"]!  - prev["input"]!),
                        "cached": max(0, cur["cached"]! - prev["cached"]!),
                        "output": max(0, cur["output"]! - prev["output"]!),
                        "total":  max(0, cur["total"]!  - prev["total"]!),
                    ]
                } else {
                    let last = info["last_token_usage"] as? [String: Any] ?? [:]
                    delta = [
                        "input":  last["input_tokens"] as? Int ?? 0,
                        "cached": last["cached_input_tokens"] as? Int ?? 0,
                        "output": last["output_tokens"] as? Int ?? 0,
                        "total":  last["total_tokens"] as? Int ?? 0,
                    ]
                }

                prevTotals = cur

                guard delta["total"]! > 0,
                      let timestamp = entry["timestamp"] as? String,
                      let dt = Self.parseISO8601(timestamp),
                      dt >= startOfDay else { return }

                accum.inputTokens += delta["input"]!
                accum.cacheReadTokens += delta["cached"]!
                accum.outputTokens += delta["output"]!
                accum.totalTokens += delta["total"]!
                accum.requests += 1
            }
        }

        return accum
    }

    // MARK: - Weekly Stats (7 days)

    func weeklyStats() -> [DailyStats] {
        let startDate = Self.startOfDay(daysAgo: 13)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let endDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!

        // 파일 변경 감지 — jsonl 파일 수 + 최신 수정 시간으로 핑거프린트
        let fingerprint = jsonlFingerprint()
        if let cached = weeklyCache, weeklyCacheFingerprint == fingerprint {
            return cached
        }

        let claudeByDate = parseClaude(from: startDate, to: endDate)
        let codexByDate = parseCodex(from: startDate, to: endDate)

        var results: [DailyStats] = []
        for daysAgo in (0...13).reversed() {
            let dayDate = Self.startOfDay(daysAgo: daysAgo)
            let dateKey = Self.dateString(dayDate)

            let c = claudeByDate[dateKey] ?? TokenAccum()
            results.append(DailyStats(
                date: dateKey, tool: "claude",
                totalTokens: c.totalTokens, inputTokens: c.inputTokens,
                outputTokens: c.outputTokens, cacheReadTokens: c.cacheReadTokens,
                requests: c.requests
            ))

            let x = codexByDate[dateKey] ?? TokenAccum()
            results.append(DailyStats(
                date: dateKey, tool: "codex",
                totalTokens: x.totalTokens, inputTokens: x.inputTokens,
                outputTokens: x.outputTokens, cacheReadTokens: x.cacheReadTokens,
                requests: x.requests
            ))
        }

        weeklyCache = results
        weeklyCacheFingerprint = fingerprint
        return results
    }

    /// jsonl 파일들의 수 + 최신 수정시간으로 변경 여부 판단
    private func jsonlFingerprint() -> String {
        var count = 0
        var latestMod: TimeInterval = 0

        let dirs = [
            home.appendingPathComponent(".claude/projects"),
            home.appendingPathComponent(".codex/sessions"),
        ]
        for dir in dirs {
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "jsonl" else { continue }
                count += 1
                if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                   let mdate = vals.contentModificationDate {
                    latestMod = max(latestMod, mdate.timeIntervalSince1970)
                }
            }
        }
        return "\(count)-\(latestMod)"
    }

    private func parseClaude(from startDate: Date, to endDate: Date) -> [String: TokenAccum] {
        var accum: [String: TokenAccum] = [:]
        let claudeDir = home.appendingPathComponent(".claude/projects")
        guard let enumerator = FileManager.default.enumerator(
            at: claudeDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return accum }

        let rangeStart = startDate.timeIntervalSince1970
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let mdate = vals.contentModificationDate,
               mdate.timeIntervalSince1970 < rangeStart { continue }

            forEachLine(in: url) { lineData in
                guard let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      entry["type"] as? String == "assistant",
                      let message = entry["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any],
                      let timestamp = entry["timestamp"] as? String,
                      let dt = Self.parseISO8601(timestamp),
                      dt >= startDate, dt < endDate else { return }

                let dateKey = Self.dateString(dt)
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

                var bucket = accum[dateKey] ?? TokenAccum()
                bucket.inputTokens += input
                bucket.outputTokens += output
                bucket.cacheReadTokens += cacheRead
                bucket.totalTokens += input + output + cacheRead
                bucket.requests += 1
                accum[dateKey] = bucket
            }
        }
        return accum
    }

    private func parseCodex(from startDate: Date, to endDate: Date) -> [String: TokenAccum] {
        var accum: [String: TokenAccum] = [:]
        let sessionsDir = home.appendingPathComponent(".codex/sessions")
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return accum }

        let rangeStart = startDate.timeIntervalSince1970
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let mdate = vals.contentModificationDate,
               mdate.timeIntervalSince1970 < rangeStart { continue }

            var prevTotals: [String: Int]?
            forEachLine(in: url) { lineData in
                guard let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      entry["type"] as? String == "event_msg",
                      let payload = entry["payload"] as? [String: Any],
                      payload["type"] as? String == "token_count",
                      let info = payload["info"] as? [String: Any],
                      let totalUsage = info["total_token_usage"] as? [String: Any] else { return }

                let cur = [
                    "input":  totalUsage["input_tokens"] as? Int ?? 0,
                    "cached": totalUsage["cached_input_tokens"] as? Int ?? 0,
                    "output": totalUsage["output_tokens"] as? Int ?? 0,
                    "total":  totalUsage["total_tokens"] as? Int ?? 0,
                ]
                let delta: [String: Int]
                if let prev = prevTotals {
                    delta = [
                        "input":  max(0, cur["input"]!  - prev["input"]!),
                        "cached": max(0, cur["cached"]! - prev["cached"]!),
                        "output": max(0, cur["output"]! - prev["output"]!),
                        "total":  max(0, cur["total"]!  - prev["total"]!),
                    ]
                } else {
                    let last = info["last_token_usage"] as? [String: Any] ?? [:]
                    delta = [
                        "input":  last["input_tokens"] as? Int ?? 0,
                        "cached": last["cached_input_tokens"] as? Int ?? 0,
                        "output": last["output_tokens"] as? Int ?? 0,
                        "total":  last["total_tokens"] as? Int ?? 0,
                    ]
                }
                prevTotals = cur

                guard delta["total"]! > 0,
                      let timestamp = entry["timestamp"] as? String,
                      let dt = Self.parseISO8601(timestamp),
                      dt >= startDate, dt < endDate else { return }

                let dateKey = Self.dateString(dt)
                var bucket = accum[dateKey] ?? TokenAccum()
                bucket.inputTokens += delta["input"]!
                bucket.cacheReadTokens += delta["cached"]!
                bucket.outputTokens += delta["output"]!
                bucket.totalTokens += delta["total"]!
                bucket.requests += 1
                accum[dateKey] = bucket
            }
        }
        return accum
    }

    // MARK: - Line-by-line Reader

    private func forEachLine(in url: URL, _ handler: (Data) -> Void) {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? fh.close() }

        let newline = Data([0x0A])
        var leftover = Data()

        while autoreleasepool(invoking: {
            let chunk = fh.readData(ofLength: 65536)
            if chunk.isEmpty { return false }

            leftover.append(chunk)

            while let range = leftover.range(of: newline) {
                let line = leftover.subdata(in: leftover.startIndex..<range.lowerBound)
                leftover = leftover.subdata(in: range.upperBound..<leftover.endIndex)
                if !line.isEmpty { handler(line) }
            }
            return true
        }) {}

        if !leftover.isEmpty { handler(leftover) }
    }

    // MARK: - Helpers

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: Date())
    }

    private static func startOfToday() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.startOfDay(for: Date())
    }

    private static func startOfDay(daysAgo: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -daysAgo, to: today)!
    }

    private static func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: date)
    }

    private static func parseISO8601(_ str: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }

    // MARK: - Quota

    struct QuotaInfo {
        let plan: String
        let fiveHour: Int?       // 0~100
        let sevenDay: Int?       // 0~100
        let fiveHourReset: Date?
        let sevenDayReset: Date?
    }

    // Claude quota: Keychain → Anthropic API 직접 호출 (hud 플러그인 우회)
    private var claudeQuotaCache: (data: QuotaInfo, timestamp: Date)?

    func invalidateClaudeQuotaCache() {
        claudeQuotaCache = nil
    }

    func claudeQuota() -> QuotaInfo? {
        // 인메모리 캐시 유효 (5분 — API rate limit 방지)
        if let cache = claudeQuotaCache,
           Date().timeIntervalSince(cache.timestamp) < 300 {
            return cache.data
        }
        // API 직접 호출 시도
        if let creds = readClaudeCredentials(),
           let info = fetchClaudeUsage(accessToken: creds.token, plan: creds.plan) {
            claudeQuotaCache = (data: info, timestamp: Date())
            return info
        }
        // Fallback: hud 플러그인 캐시 파일
        return readClaudeHudCache()
    }

    private func readClaudeHudCache() -> QuotaInfo? {
        let path = home.appendingPathComponent(
            ".claude/plugins/claude-hud/.usage-cache.json"
        ).path
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ts = json["timestamp"] as? Double,
              Date().timeIntervalSince1970 - (ts / 1000) < 3600,
              let inner = json["data"] as? [String: Any] else { return nil }
        let apiUnavailable = inner["apiUnavailable"] as? Bool ?? false
        let fh = inner["fiveHour"] as? Int
        let sd = inner["sevenDay"] as? Int
        if apiUnavailable && fh == nil && sd == nil { return nil }
        return QuotaInfo(
            plan: inner["planName"] as? String ?? "?",
            fiveHour: fh, sevenDay: sd,
            fiveHourReset: (inner["fiveHourResetAt"] as? String).flatMap(Self.parseISO8601),
            sevenDayReset: (inner["sevenDayResetAt"] as? String).flatMap(Self.parseISO8601)
        )
    }

    private func readClaudeCredentials() -> (token: String, plan: String)? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { return nil }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String else { return nil }
        // 만료 체크
        if let expiresAt = oauth["expiresAt"] as? Double,
           expiresAt <= Date().timeIntervalSince1970 * 1000 { return nil }
        let sub = (oauth["subscriptionType"] as? String ?? "").lowercased()
        let plan: String
        if sub.contains("max") { plan = "Max" }
        else if sub.contains("pro") { plan = "Pro" }
        else if sub.contains("team") { plan = "Team" }
        else { plan = "Pro" }
        return (token: accessToken, plan: plan)
    }

    private func fetchClaudeUsage(accessToken: String, plan: String) -> QuotaInfo? {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        var result: QuotaInfo?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { sem.signal() }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            let fiveHour = json["five_hour"] as? [String: Any]
            let sevenDay = json["seven_day"] as? [String: Any]

            let fh = (fiveHour?["utilization"] as? Double).map { Int(max(0, min(100, $0.rounded()))) }
            let sd = (sevenDay?["utilization"] as? Double).map { Int(max(0, min(100, $0.rounded()))) }
            let fhReset = (fiveHour?["resets_at"] as? String).flatMap(Self.parseISO8601)
            let sdReset = (sevenDay?["resets_at"] as? String).flatMap(Self.parseISO8601)

            result = QuotaInfo(
                plan: plan,
                fiveHour: fh, sevenDay: sd,
                fiveHourReset: fhReset, sevenDayReset: sdReset
            )
        }.resume()
        sem.wait()
        return result
    }

    func codexQuota() -> QuotaInfo? {
        let sessionsDir = home.appendingPathComponent(".codex/sessions")
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        // Collect .jsonl files sorted by modification date (newest first)
        var files: [(URL, Date)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let mdate = vals.contentModificationDate {
                files.append((url, mdate))
            }
        }
        files.sort { $0.1 > $1.1 }

        // Find the last rate_limits entry
        for (url, _) in files {
            guard let fh = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? fh.close() }

            // Read last 64KB (rate_limits is near end of file)
            let size = fh.seekToEndOfFile()
            let seekTo = size > 65536 ? size - 65536 : 0
            fh.seek(toFileOffset: seekTo)
            guard let content = String(data: fh.readDataToEndOfFile(), encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: "\n").reversed()
            for line in lines {
                guard !line.isEmpty,
                      let data = line.data(using: .utf8),
                      let entry = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      entry["type"] as? String == "event_msg",
                      let payload = entry["payload"] as? [String: Any],
                      payload["type"] as? String == "token_count",
                      let rate = payload["rate_limits"] as? [String: Any],
                      rate["limit_id"] as? String == "codex" else { continue }

                let primary = rate["primary"] as? [String: Any] ?? [:]
                let secondary = rate["secondary"] as? [String: Any] ?? [:]

                let plan = (rate["plan_type"] as? String ?? "?").capitalized

                return QuotaInfo(
                    plan: plan,
                    fiveHour: primary["used_percent"] as? Int,
                    sevenDay: secondary["used_percent"] as? Int,
                    fiveHourReset: (primary["resets_at"] as? Double).map {
                        Date(timeIntervalSince1970: $0)
                    },
                    sevenDayReset: (secondary["resets_at"] as? Double).map {
                        Date(timeIntervalSince1970: $0)
                    }
                )
            }
        }
        return nil
    }
}
