import Foundation
import SQLite3

/// SQLite 기반 로컬 저장소 — config, daily_records, pending_submissions 관리
final class DxaiStore {
    static let shared = DxaiStore()

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/dxai/points")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        dbPath = base.appendingPathComponent("dxai.db").path

        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            NSLog("[DxaiStore] DB 열기 실패: \(dbPath)")
            return
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        createTables()
        migrateFromJSON(base: base)
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS daily_records (
            date TEXT PRIMARY KEY,
            vanguard_tier TEXT NOT NULL,
            vanguard_division INTEGER,
            daily_coins INTEGER NOT NULL DEFAULT 0,
            claude_tokens INTEGER NOT NULL DEFAULT 0,
            codex_tokens INTEGER NOT NULL DEFAULT 0,
            total_coins INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS pending_submissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_uuid TEXT NOT NULL,
            nickname TEXT NOT NULL,
            date TEXT NOT NULL,
            daily_coins INTEGER NOT NULL,
            claude_tokens INTEGER NOT NULL,
            codex_tokens INTEGER NOT NULL,
            vanguard_tier TEXT NOT NULL,
            vanguard_division INTEGER,
            secret_token TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - Config CRUD

    func getConfig(_ key: String) -> String? {
        let sql = "SELECT value FROM config WHERE key = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return String(cString: sqlite3_column_text(stmt, 0))
    }

    func setConfig(_ key: String, _ value: String) {
        let sql = "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, key, -1, transient)
        sqlite3_bind_text(stmt, 2, value, -1, transient)
        sqlite3_step(stmt)
    }

    func getConfigInt(_ key: String) -> Int? {
        guard let s = getConfig(key) else { return nil }
        return Int(s)
    }

    func setConfigInt(_ key: String, _ value: Int) {
        setConfig(key, String(value))
    }

    // MARK: - Daily Records CRUD

    struct DailyRow {
        let date: String
        let vanguardTier: String
        let vanguardDivision: Int?
        let dailyCoins: Int
        let claudeTokens: Int
        let codexTokens: Int
        let totalCoins: Int
    }

    func upsertDailyRecord(_ row: DailyRow) {
        let sql = """
        INSERT OR REPLACE INTO daily_records
        (date, vanguard_tier, vanguard_division, daily_coins, claude_tokens, codex_tokens, total_coins)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, row.date, -1, transient)
        sqlite3_bind_text(stmt, 2, row.vanguardTier, -1, transient)
        if let div = row.vanguardDivision {
            sqlite3_bind_int(stmt, 3, Int32(div))
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, Int32(row.dailyCoins))
        sqlite3_bind_int64(stmt, 5, Int64(row.claudeTokens))
        sqlite3_bind_int64(stmt, 6, Int64(row.codexTokens))
        sqlite3_bind_int64(stmt, 7, Int64(row.totalCoins))
        sqlite3_step(stmt)
    }

    func getDailyRecord(date: String) -> DailyRow? {
        let sql = "SELECT * FROM daily_records WHERE date = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, date, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return rowFromStmt(stmt)
    }

    func allDailyRecords() -> [DailyRow] {
        let sql = "SELECT * FROM daily_records ORDER BY date ASC"
        return queryRows(sql)
    }

    func recentDailyRecords(limit: Int) -> [DailyRow] {
        let sql = "SELECT * FROM daily_records ORDER BY date DESC LIMIT ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        var rows: [DailyRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(rowFromStmt(stmt))
        }
        return rows.reversed()
    }

    func dailyRecordsInDates(_ dates: Set<String>) -> [DailyRow] {
        guard !dates.isEmpty else { return [] }
        let placeholders = dates.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT * FROM daily_records WHERE date IN (\(placeholders)) ORDER BY date ASC"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, date) in dates.sorted().enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), date, -1, transient)
        }
        var rows: [DailyRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(rowFromStmt(stmt))
        }
        return rows
    }

    func lastDailyRecord() -> DailyRow? {
        let sql = "SELECT * FROM daily_records ORDER BY date DESC LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return rowFromStmt(stmt)
    }

    func dailyRecordCount() -> Int {
        let sql = "SELECT COUNT(*) FROM daily_records"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    /// 오래된 레코드 정리 (최근 N일만 유지)
    func pruneOldRecords(keep: Int = 365) {
        let count = dailyRecordCount()
        guard count > keep else { return }
        let sql = "DELETE FROM daily_records WHERE date NOT IN (SELECT date FROM daily_records ORDER BY date DESC LIMIT ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_int(stmt, 1, Int32(keep))
        sqlite3_step(stmt)
    }

    private func rowFromStmt(_ stmt: OpaquePointer?) -> DailyRow {
        let division = sqlite3_column_type(stmt, 2) == SQLITE_NULL
            ? nil : Int(sqlite3_column_int(stmt, 2))
        return DailyRow(
            date: String(cString: sqlite3_column_text(stmt, 0)),
            vanguardTier: String(cString: sqlite3_column_text(stmt, 1)),
            vanguardDivision: division,
            dailyCoins: Int(sqlite3_column_int(stmt, 3)),
            claudeTokens: Int(sqlite3_column_int64(stmt, 4)),
            codexTokens: Int(sqlite3_column_int64(stmt, 5)),
            totalCoins: Int(sqlite3_column_int64(stmt, 6))
        )
    }

    private func queryRows(_ sql: String) -> [DailyRow] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        var rows: [DailyRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(rowFromStmt(stmt))
        }
        return rows
    }

    // MARK: - Pending Submissions CRUD

    struct PendingRow {
        let id: Int?
        let deviceUUID: String
        let nickname: String
        let date: String
        let dailyCoins: Int
        let claudeTokens: Int
        let codexTokens: Int
        let vanguardTier: String
        let vanguardDivision: Int?
        let secretToken: String?
    }

    func addPending(_ row: PendingRow) {
        // 같은 날짜의 기존 pending 제거
        let delSql = "DELETE FROM pending_submissions WHERE date = ? AND device_uuid = ?"
        var delStmt: OpaquePointer?
        sqlite3_prepare_v2(db, delSql, -1, &delStmt, nil)
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(delStmt, 1, row.date, -1, transient)
        sqlite3_bind_text(delStmt, 2, row.deviceUUID, -1, transient)
        sqlite3_step(delStmt)
        sqlite3_finalize(delStmt)

        let sql = """
        INSERT INTO pending_submissions
        (device_uuid, nickname, date, daily_coins, claude_tokens, codex_tokens, vanguard_tier, vanguard_division, secret_token)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, row.deviceUUID, -1, transient)
        sqlite3_bind_text(stmt, 2, row.nickname, -1, transient)
        sqlite3_bind_text(stmt, 3, row.date, -1, transient)
        sqlite3_bind_int(stmt, 4, Int32(row.dailyCoins))
        sqlite3_bind_int64(stmt, 5, Int64(row.claudeTokens))
        sqlite3_bind_int64(stmt, 6, Int64(row.codexTokens))
        sqlite3_bind_text(stmt, 7, row.vanguardTier, -1, transient)
        if let div = row.vanguardDivision {
            sqlite3_bind_int(stmt, 8, Int32(div))
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        if let token = row.secretToken {
            sqlite3_bind_text(stmt, 9, token, -1, transient)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        sqlite3_step(stmt)

        // 최대 30건 유지
        sqlite3_exec(db, """
        DELETE FROM pending_submissions WHERE id NOT IN
        (SELECT id FROM pending_submissions ORDER BY id DESC LIMIT 30)
        """, nil, nil, nil)
    }

    func allPending() -> [PendingRow] {
        let sql = "SELECT * FROM pending_submissions ORDER BY id ASC"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        var rows: [PendingRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(pendingFromStmt(stmt))
        }
        return rows
    }

    func clearPending() {
        sqlite3_exec(db, "DELETE FROM pending_submissions", nil, nil, nil)
    }

    private func pendingFromStmt(_ stmt: OpaquePointer?) -> PendingRow {
        let division = sqlite3_column_type(stmt, 8) == SQLITE_NULL
            ? nil : Int(sqlite3_column_int(stmt, 8))
        let token = sqlite3_column_type(stmt, 9) == SQLITE_NULL
            ? nil : String(cString: sqlite3_column_text(stmt, 9))
        return PendingRow(
            id: Int(sqlite3_column_int(stmt, 0)),
            deviceUUID: String(cString: sqlite3_column_text(stmt, 1)),
            nickname: String(cString: sqlite3_column_text(stmt, 2)),
            date: String(cString: sqlite3_column_text(stmt, 3)),
            dailyCoins: Int(sqlite3_column_int(stmt, 4)),
            claudeTokens: Int(sqlite3_column_int64(stmt, 5)),
            codexTokens: Int(sqlite3_column_int64(stmt, 6)),
            vanguardTier: String(cString: sqlite3_column_text(stmt, 7)),
            vanguardDivision: division,
            secretToken: token
        )
    }

    // MARK: - JSON → SQLite 마이그레이션

    private func migrateFromJSON(base: URL) {
        let configURL = base.appendingPathComponent("config.json")
        let historyURL = base.appendingPathComponent("history.json")
        let pendingURL = base.appendingPathComponent("pending.json")

        // 이미 마이그레이션 완료된 경우 스킵
        guard FileManager.default.fileExists(atPath: configURL.path)
           || FileManager.default.fileExists(atPath: historyURL.path) else { return }

        NSLog("[DxaiStore] JSON → SQLite 마이그레이션 시작")

        // config.json 마이그레이션
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(MigrationConfig.self, from: data) {
            setConfig("nickname", config.nickname)
            setConfig("opt_in", config.optIn ? "1" : "0")
            setConfig("device_uuid", config.deviceUUID)
            setConfig("last_recorded_date", config.lastRecordedDate)
            if let t = config.cachedTotalTokens { setConfigInt("cached_total_tokens", t) }
            if let r = config.cachedLiveRank { setConfigInt("cached_live_rank", r) }
        }

        // history.json 마이그레이션
        if let data = try? Data(contentsOf: historyURL),
           let records = try? JSONDecoder().decode([MigrationRecord].self, from: data) {
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
            for r in records {
                upsertDailyRecord(DailyRow(
                    date: r.date, vanguardTier: r.vanguardTier,
                    vanguardDivision: r.vanguardDivision, dailyCoins: r.dailyCoins,
                    claudeTokens: r.claudeTokens, codexTokens: r.codexTokens,
                    totalCoins: r.totalCoins
                ))
            }
            sqlite3_exec(db, "COMMIT", nil, nil, nil)
            NSLog("[DxaiStore] history \(records.count)건 마이그레이션 완료")
        }

        // pending.json 마이그레이션
        if let data = try? Data(contentsOf: pendingURL),
           let items = try? JSONDecoder().decode([MigrationPending].self, from: data) {
            for p in items {
                addPending(PendingRow(
                    id: nil, deviceUUID: p.device_uuid, nickname: p.nickname,
                    date: p.date, dailyCoins: p.daily_coins,
                    claudeTokens: p.claude_tokens, codexTokens: p.codex_tokens,
                    vanguardTier: p.vanguard_tier, vanguardDivision: p.vanguard_division,
                    secretToken: p.secret_token
                ))
            }
        }

        // 원본 JSON → .bak 으로 보존 (삭제하지 않음)
        for url in [configURL, historyURL, pendingURL] {
            let bak = url.appendingPathExtension("bak")
            try? FileManager.default.moveItem(at: url, to: bak)
        }
        NSLog("[DxaiStore] 마이그레이션 완료, JSON → .bak 보존")
    }

    // 마이그레이션용 Codable 타입
    private struct MigrationConfig: Codable {
        let nickname: String
        let optIn: Bool
        let deviceUUID: String
        let lastRecordedDate: String
        let cachedTotalTokens: Int?
        let cachedLiveRank: Int?
    }

    private struct MigrationRecord: Codable {
        let date: String
        let vanguardTier: String
        let vanguardDivision: Int?
        let dailyCoins: Int
        let claudeTokens: Int
        let codexTokens: Int
        let totalCoins: Int
    }

    private struct MigrationPending: Codable {
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
}
