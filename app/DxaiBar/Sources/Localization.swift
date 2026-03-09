import Foundation

/// 앱 내 모든 사용자 노출 문자열을 관리하는 로컬라이제이션 구조체.
/// 기본 언어: English. 한국어 전환 가능.
struct L {
    private let ko: Bool

    /// 비-뷰 컨텍스트 (ViewModel 등)에서 현재 언어로 생성
    init() {
        self.ko = (UserDefaults.standard.string(forKey: "appLanguage") ?? "en") == "ko"
    }

    /// 뷰에서 @AppStorage 값을 전달하여 반응형으로 사용
    init(_ lang: String) {
        self.ko = lang == "ko"
    }

    // MARK: - Header

    var refresh: String { ko ? "새로고침" : "Refresh" }

    // MARK: - About

    var aboutTitle: String { ko ? "Deus eX AI 소개" : "About Deus eX AI" }

    var aboutBody: String {
        if ko {
            return """
            AI 개발 환경을 한눈에.

            Claude, Codex 등 AI 코딩 도구의 토큰 사용량을 \
            실시간 추적하고, 쿼터 현황을 모니터링합니다.

            Quick Actions로 시스템 상태 확인, AI 환경 스캔, \
            디스크 정리, 시스템 최적화를 메뉴바에서 바로 실행.

            하루의 AI 사용량이 쌓일수록 등급이 올라갑니다. \
            오늘은 어디까지 갈 수 있을까요?
            """
        } else {
            return """
            Your AI dev environment at a glance.

            Track token usage across AI coding tools like \
            Claude and Codex in real time, and monitor quotas.

            Run system diagnostics, AI environment scans, \
            disk cleanup, and optimization right from the menu bar.

            The more you use AI, the higher your rank climbs. \
            How far can you go today?
            """
        }
    }

    var aboutVersion: String { ko ? "버전" : "Version" }
    var aboutDismiss: String { ko ? "닫기" : "Close" }

    // MARK: - Dashboard

    var tokensToday: String { ko ? "오늘 하루 이만큼 토큰 불태우는 중!" : "tokens burned today!" }
    var remaining: String { ko ? "남음" : "remaining" }
    var maxRank: String { "MAX RANK" }
    var today: String { ko ? "오늘" : "today" }

    // MARK: - Insights

    var insights: String { ko ? "Claude / Codex 주간 인사이트" : "Claude / Codex Weekly Insight" }
    var insightsTitle: String { ko ? "주간 인사이트" : "Weekly Insights" }
    var insightsDailyAvg: String { ko ? "일 평균" : "Daily Avg" }
    var insightsPeakDay: String { ko ? "최고 사용일" : "Peak Day" }
    var insightsTotalWeek: String { ko ? "주간 총합" : "Week Total" }
    var insightsToolBreakdown: String { ko ? "도구별 사용량" : "Tool Breakdown" }
    var insightsTokenTypes: String { ko ? "토큰 유형" : "Token Types" }
    var insightsInput: String { ko ? "입력" : "Input" }
    var insightsOutput: String { ko ? "출력" : "Output" }
    var insightsCache: String { ko ? "캐시" : "Cache" }
    var insightsNoData: String { ko ? "최근 14일간 데이터가 없습니다" : "No data in the last 14 days" }
    var insightsRequests: String { ko ? "요청" : "requests" }
    var insightsCacheHitRate: String { ko ? "캐시 적중" : "Cache Hit" }
    var insightsVsLastWeek: String { ko ? "전주 대비" : "vs last week" }

    func insightsBulletTotal(_ total: String, _ change: String) -> String {
        if change.isEmpty {
            return ko ? "이번 주 총 \(total) 토큰 사용"
                      : "Total \(total) tokens this week"
        }
        return ko ? "이번 주 총 \(total) 토큰 (전주 대비 \(change))"
                  : "\(total) tokens this week (\(change) vs last week)"
    }

    func insightsBulletCache(_ rate: Int) -> String {
        if rate >= 50 {
            return ko ? "캐시 적중률 \(rate)% — 컨텍스트 재사용 효율 좋음"
                      : "Cache hit rate \(rate)% — good context reuse"
        } else if rate >= 20 {
            return ko ? "캐시 적중률 \(rate)% — 컨텍스트 재사용 보통"
                      : "Cache hit rate \(rate)% — moderate context reuse"
        }
        return ko ? "캐시 적중률 \(rate)% — 새 컨텍스트 비중 높음"
                  : "Cache hit rate \(rate)% — mostly fresh context"
    }

    func insightsBulletPeak(_ day: String, _ tokens: String) -> String {
        ko ? "\(day)에 \(tokens) 토큰 집중 사용"
           : "Peak on \(day) with \(tokens) tokens"
    }

    // MARK: - Usage Bars

    var session5h: String { ko ? "세션 (5h)" : "Session (5h)" }
    var weekly7d: String { ko ? "주간 (7d)" : "Weekly (7d)" }
    func used(_ pct: Int) -> String { "\(pct)% \(ko ? "사용" : "used")" }
    var resetSoon: String { ko ? "곧" : "soon" }

    // MARK: - Empty State

    var noDataYet: String { ko ? "아직 오늘의 데이터가 없습니다" : "No data for today yet" }
    var autoCollect: String {
        ko ? "Claude 또는 Codex를 사용하면 자동 수집됩니다"
            : "Data is collected automatically when using Claude or Codex"
    }

    // MARK: - Task Panel

    var back: String { ko ? "돌아가기" : "Back" }
    var running: String { ko ? "실행 중" : "Running" }
    var runningDots: String { ko ? "실행 중..." : "Running..." }
    var stop: String { ko ? "중지" : "Stop" }
    var done: String { ko ? "완료" : "Done" }
    var close: String { ko ? "닫기" : "Close" }
    var waiting: String { ko ? "대기" : "Wait" }
    var start: String { "Start" }

    // MARK: - Quick Actions

    var systemStatus: String { ko ? "시스템 상태" : "System Status" }
    var systemStatusDesc: String { ko ? "CPU·메모리·디스크 모니터링" : "CPU · Memory · Disk monitoring" }
    var aiScan: String { ko ? "AI 환경 스캔" : "AI Env Scan" }
    var aiScanDesc: String { ko ? "AI MCP, Skill 현황 진단" : "AI MCP, Skill diagnosis" }
    var diskCleanup: String { ko ? "디스크 정리" : "Disk Cleanup" }
    var diskCleanupDesc: String { ko ? "캐시·로그·임시파일 정리" : "Cache · Log · Temp file cleanup" }
    var systemOptimize: String { ko ? "시스템 최적화" : "System Optimize" }
    var systemOptimizeDesc: String { ko ? "메모리·DNS·네트워크 튜닝" : "Memory · DNS · Network tuning" }

    // MARK: - Footer

    var autoStart: String { ko ? "자동시작" : "Auto Start" }
    var quit: String { ko ? "종료" : "Quit" }
    var testAlert: String { ko ? "알림 테스트" : "Test Alert" }

    func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return ko ? "방금 업데이트" : "Just updated" }
        if seconds < 3600 {
            let m = seconds / 60
            return ko ? "\(m)분 전" : "\(m)m ago"
        }
        let h = seconds / 3600
        return ko ? "\(h)시간 전" : "\(h)h ago"
    }

    // MARK: - Error / Status

    var adminCancelled: String { ko ? "관리자 인증이 취소되었습니다." : "Admin authentication was cancelled." }
    func execFailed(_ err: String) -> String { ko ? "실행 실패: \(err)" : "Execution failed: \(err)" }
    var timedOut: String { ko ? "(시간 초과로 자동 종료되었습니다)" : "(Auto-terminated due to timeout)" }

    // MARK: - Scan Panel

    var aiEnvironment: String { ko ? "AI 환경 현황" : "AI Environment" }
    func skillChip(_ n: Int) -> String { ko ? "스킬 \(n)" : "Skills \(n)" }
    func mcpChip(_ n: Int) -> String { "MCP \(n)" }
    func projectChip(_ n: Int) -> String { ko ? "프로젝트 \(n)" : "Projects \(n)" }
    func sessionChip(_ n: Int) -> String { ko ? "세션 \(n)" : "Sessions \(n)" }
    func portChip(_ n: Int) -> String { ko ? "포트 \(n)" : "Ports \(n)" }

    var globalSetup: String { ko ? "글로벌 설정" : "Global Setup" }
    var globalDirectives: String { ko ? "글로벌 지침" : "Global directives" }
    var skills: String { ko ? "스킬" : "Skills" }
    var slashExtensions: String { ko ? "슬래시 커맨드 확장" : "Slash command extensions" }
    var mcpServers: String { ko ? "MCP 서버" : "MCP Servers" }
    var externalTools: String { ko ? "외부 도구 연결" : "External tool connections" }
    var customCommands: String { ko ? "커스텀 커맨드" : "Custom Commands" }
    var automationCmds: String { ko ? "자동화 명령" : "Automation commands" }
    func nItems(_ n: Int) -> String { ko ? "\(n)개" : "\(n)" }
    func nLines(_ n: Int) -> String { ko ? "\(n)줄" : "\(n) lines" }

    var activeSessions: String { ko ? "실행 중인 AI 세션" : "Active AI Sessions" }
    func aiProjects(_ n: Int) -> String { ko ? "AI 연동 프로젝트 (\(n)개)" : "AI Projects (\(n))" }
    var openPorts: String { ko ? "열린 포트 (개발 서버)" : "Open Ports (Dev Servers)" }
    var configLabel: String { ko ? "설정파일 :" : "Config :" }
    func moreProjects(_ n: Int) -> String { ko ? "... 외 \(n)개 프로젝트" : "... and \(n) more" }

    // MARK: - Impact Number Format

    func formatImpact(_ n: Int) -> String {
        if ko {
            let eok = n / 100_000_000
            let man = (n % 100_000_000) / 10_000
            if eok > 0 && man > 0 { return "\(eok)억 \(man)만" }
            if eok > 0 { return "\(eok)억" }
            if man > 0 { return "\(man)만" }
            return "\(n)"
        } else {
            if n >= 1_000_000_000 {
                let s = String(format: "%.1f", Double(n) / 1_000_000_000)
                return "\(s.hasSuffix(".0") ? String(s.dropLast(2)) : s) billion"
            }
            if n >= 1_000_000 {
                let s = String(format: "%.1f", Double(n) / 1_000_000)
                return "\(s.hasSuffix(".0") ? String(s.dropLast(2)) : s) million"
            }
            if n >= 1_000 {
                let s = String(format: "%.1f", Double(n) / 1_000)
                return "\(s.hasSuffix(".0") ? String(s.dropLast(2)) : s)K"
            }
            return "\(n)"
        }
    }

    // MARK: - Points & Settings

    var pointsToday: String { ko ? "오늘" : "today" }
    var pointsTotal: String { ko ? "누적" : "total" }
    var pointsLabel: String { "pt" }

    var leaderboard: String { ko ? "리더보드" : "Leaderboard" }

    var settingsTitle: String { ko ? "설정" : "Settings" }
    var settingsNickname: String { ko ? "닉네임" : "Nickname" }
    var settingsNicknamePlaceholder: String { ko ? "영문/숫자/밑줄 2-16자" : "2-16 chars, a-z 0-9 _" }
    var settingsNicknameValidation: String { ko ? "영문, 숫자, 밑줄만 허용 (2-16자)" : "Only a-z, 0-9, underscore (2-16 chars)" }
    var settingsOptIn: String { ko ? "랭킹 참여" : "Join Ranking" }
    var settingsOptInDesc: String {
        ko ? "익명화된 포인트 데이터를 리더보드에 제출합니다"
           : "Submit anonymized point data to the leaderboard"
    }
    var settingsDataPreview: String { ko ? "제출 데이터 미리보기" : "Data Preview" }
    var settingsNotCollected: String { ko ? "수집하지 않는 것" : "Not Collected" }
    var settingsNotCollectedItems: [String] {
        if ko {
            return ["프로젝트명, 파일 경로", "프롬프트, 대화 내용", "API 키, 환경변수"]
        } else {
            return ["Project names, file paths", "Prompts, conversations", "API keys, env variables"]
        }
    }

    // MARK: - Pioneer Level Messages (tier + division)

    func pioneerMessage(_ tier: String, division: Int?) -> String {
        let key = division.map { "\(tier).\($0)" } ?? tier
        if ko {
            switch key {
            // Bronze — 첫 시작, 호기심
            case "Bronze.5": return "AI와의 첫 대화, 시작이 반입니다"
            case "Bronze.4": return "호기심이 이끄는 대로"
            case "Bronze.3": return "AI가 당신을 기억하기 시작합니다"
            case "Bronze.2": return "AI 없던 시절이 가물가물..."
            case "Bronze.1": return "Bronze 졸업이 코앞입니다"
            // Silver — 익숙해짐, 성장
            case "Silver.5": return "AI 활용에 익숙해지고 있군요"
            case "Silver.4": return "토큰 밀리어네어의 탄생!"
            case "Silver.3": return "이제 AI 없이는 좀 불편하죠?"
            case "Silver.2": return "이쯤 되면 AI가 동료입니다"
            case "Silver.1": return "Silver 마스터리 달성 직전!"
            // Gold — 파이오니어, 본격
            case "Gold.5":   return "AI 시대의 파이오니어"
            case "Gold.4":   return "Context Window가 당신을 환영합니다"
            case "Gold.3":   return "슬슬 API가 긴장하기 시작합니다"
            case "Gold.2":   return "AI와의 시너지가 폭발하고 있어요"
            case "Gold.1":   return "Gold의 끝이 보입니다... 그 너머엔?"
            // Platinum — 합일, 강렬
            case "Platinum.5": return "AI와 하나가 되어가고 있습니다"
            case "Platinum.4": return "Rate Limit이 슬슬 당신을 주시합니다"
            case "Platinum.3": return "1억 토큰! 멈출 수가 없다"
            case "Platinum.2": return "Anthropic 서버실에 당신의 이름이..."
            case "Platinum.1": return "Platinum 정상이 코앞입니다"
            // Diamond — 네이티브, 전설적
            case "Diamond.5": return "진정한 AI 네이티브의 영역"
            case "Diamond.4": return "당신의 토큰이 GDP에 잡힐 수도..."
            case "Diamond.3": return "AI가 당신을 학습하고 있을지도?"
            case "Diamond.2": return "데이터센터에서 경보가 울립니다"
            case "Diamond.1": return "Diamond의 빛이 점점 강렬해집니다"
            // Master — 경지, 초월
            case "Master.5": return "AI 마스터의 경지에 진입"
            case "Master.4": return "Ctrl+C? 그게 뭐죠?"
            case "Master.3": return "Sam Altman이 당신을 주목합니다"
            case "Master.2": return "10억 토큰! 인류의 한계를 시험 중"
            case "Master.1": return "Master의 끝... 전설이 시작됩니다"
            // Grandmaster — 전설, 초월
            case "Grandmaster.5": return "전설의 영역에 진입"
            case "Grandmaster.4": return "Dario Amodei가 직접 연락할 수도..."
            case "Grandmaster.3": return "항복은 없다. 오직 전진뿐"
            case "Grandmaster.2": return "당신이 곧 벤치마크입니다"
            case "Grandmaster.1": return "AGI까지 얼마 남지 않았습니다"
            // Challenger
            case "Challenger": return "당신이 곧 AI 시대입니다"
            default: return ""
            }
        } else {
            switch key {
            case "Bronze.5": return "First chat with AI — every journey starts here"
            case "Bronze.4": return "Curiosity leads the way"
            case "Bronze.3": return "AI is starting to remember you"
            case "Bronze.2": return "Can barely remember life before AI..."
            case "Bronze.1": return "Ready to graduate from Bronze"
            case "Silver.5": return "Getting comfortable with AI"
            case "Silver.4": return "Token millionaire is born!"
            case "Silver.3": return "Life without AI? Uncomfortable now, right?"
            case "Silver.2": return "At this point, AI is your colleague"
            case "Silver.1": return "Silver mastery almost complete!"
            case "Gold.5":   return "Pioneer of the AI era"
            case "Gold.4":   return "Context Window welcomes you"
            case "Gold.3":   return "The API is getting nervous"
            case "Gold.2":   return "AI synergy is off the charts"
            case "Gold.1":   return "End of Gold... what lies beyond?"
            case "Platinum.5": return "Becoming one with AI"
            case "Platinum.4": return "Rate Limit is watching you closely"
            case "Platinum.3": return "100M tokens! Can't stop won't stop"
            case "Platinum.2": return "Your name echoes in Anthropic's server room"
            case "Platinum.1": return "Almost at the Platinum summit"
            case "Diamond.5": return "True AI native territory"
            case "Diamond.4": return "Your tokens might show up in GDP..."
            case "Diamond.3": return "AI might be learning from you now"
            case "Diamond.2": return "Alarms going off at the datacenter"
            case "Diamond.1": return "Diamond's brilliance intensifies"
            case "Master.5": return "Entering AI Master realm"
            case "Master.4": return "Ctrl+C? What's that?"
            case "Master.3": return "Sam Altman has noticed you"
            case "Master.2": return "1B tokens! Testing the limits of humanity"
            case "Master.1": return "End of Master... legend begins"
            case "Grandmaster.5": return "Entering legendary territory"
            case "Grandmaster.4": return "Dario Amodei might reach out personally..."
            case "Grandmaster.3": return "No surrender. Only forward"
            case "Grandmaster.2": return "You ARE the benchmark"
            case "Grandmaster.1": return "AGI is within reach"
            case "Challenger": return "You ARE the AI era"
            default: return ""
            }
        }
    }

    // MARK: - Token Milestones

    var milestones: [(threshold: Int, title: String, body: String)] {
        if ko {
            return [
                (500_000,      "Hello, World!",              "50만 토큰 돌파! 워밍업 완료"),
                (1_000_000,    "토큰 밀리어네어!",             "100만 토큰! API가 비명을 지릅니다"),
                (1_500_000,    "프롬프트 장인!",               "150만 토큰! 거침없는 프롬프트"),
                (2_000_000,    "Rate Limit 단골!",           "200만 토큰! 도저히 막을수 없습니다"),
                (2_500_000,    "Context 마스터!",             "250만 토큰! Claude가 당신을 기억합니다"),
                (3_000_000,    "API 과금 주의보!",             "300만 토큰! 멈출 수가 없다"),
                (5_000_000,    "GPU 온도 상승!",              "500만 토큰! Rate Limit이 두려워합니다"),
                (7_000_000,    "데이터센터 경보!",              "700만 토큰! Anthropic 서버실에 경보 발령"),
                (10_000_000,   "Transformer 과부하!",         "1000만 토큰! 당신의 토큰이 GDP에 잡힙니다"),
                (15_000_000,   "학습 데이터 편입!",             "1500만 토큰! AI가 당신을 학습하고 있습니다"),
                (20_000_000,   "Sam Altman 알림!",            "2000만 토큰! Context Window가 경의를 표합니다"),
                (30_000_000,   "Dario Amodei 호출!",          "3000만 토큰! 항복은 없다. Ctrl+C도 없다"),
                (50_000_000,   "AI 특이점 접근!",              "5000만 토큰! VICTORY! GG WP"),
                (100_000_000,  "Anthropic 계약 제의!",         "1억 토큰! 이정도면 Anthropic 직원 아닌가요?"),
                (200_000_000,  "OpenAI 계약 제의!",            "2억 토큰! OpenAI / Anthropic 양대 진영의 러브콜!"),
                (500_000_000,  "AGI 달성!",                   "5억 토큰! 당신이 곧 AGI입니다"),
            ]
        } else {
            return [
                (500_000,      "Hello, World!",              "500K tokens! Warm-up complete"),
                (1_000_000,    "Token Millionaire!",          "1M tokens! The API is screaming"),
                (1_500_000,    "Prompt Artisan!",             "1.5M tokens! Unstoppable prompting"),
                (2_000_000,    "Rate Limit Regular!",         "2M tokens! Absolutely unstoppable"),
                (2_500_000,    "Context Master!",             "2.5M tokens! Claude remembers you"),
                (3_000_000,    "API Billing Alert!",          "3M tokens! Can't stop won't stop"),
                (5_000_000,    "GPU Overheating!",            "5M tokens! Rate Limit fears you"),
                (7_000_000,    "Datacenter Alert!",           "7M tokens! Alert in Anthropic's server room"),
                (10_000_000,   "Transformer Overload!",       "10M tokens! Your tokens show up in GDP"),
                (15_000_000,   "Training Data Material!",     "15M tokens! AI is learning from you"),
                (20_000_000,   "Sam Altman Notified!",        "20M tokens! Context Window bows to you"),
                (30_000_000,   "Dario Amodei Paged!",         "30M tokens! No surrender. No Ctrl+C"),
                (50_000_000,   "Approaching Singularity!",    "50M tokens! VICTORY! GG WP"),
                (100_000_000,  "Anthropic Job Offer!",        "100M tokens! Aren't you an Anthropic employee?"),
                (200_000_000,  "OpenAI Job Offer!",           "200M tokens! Both OpenAI & Anthropic want you!"),
                (500_000_000,  "AGI Achieved!",               "500M tokens! You ARE the AGI"),
            ]
        }
    }
}
