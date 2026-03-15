import SwiftUI

// MARK: - Model

struct ScanResult {
    let global: GlobalSetup
    let projects: [ProjectInfo]
    let activeSessions: [ActiveSession]
    let ports: [ActivePort]

    struct GlobalSetup {
        let claudeMdLines: Int
        let skills: [Skill]
        let mcpServers: [String]
        let mcpDetails: [String: MCPDetail]
        let hooks: Bool
        let commands: [String]
    }

    struct Skill {
        let name: String
        let hasSkillMd: Bool
    }

    struct MCPDetail {
        let command: String
        let type: String
    }

    struct ProjectInfo: Identifiable {
        let id: String  // name
        let name: String
        let path: String
        let signatures: [String]
        let claudeMdLines: Int?
        let agentsMdLines: Int?
        let skills: [String]
        let mcpServers: [String]
        let hasLocalMcp: Bool
        let sessionCount: Int
        let lastSessionTime: String?
        let lastSessionTopic: String?
        // Git info
        let gitRepo: String?
        let gitBranch: String?
        let gitLastCommit: String?
        let gitLastTime: String?
        let gitDirty: Bool
    }

    struct ActiveSession: Identifiable {
        let id: String  // pid as string
        let tool: String
        let pid: Int
        let cwd: String
        let cmd: String
    }

    struct ActivePort: Identifiable {
        let id: Int  // port number
        let port: Int
        let command: String
        let pid: Int
        let cwd: String
    }

    static func parse(from raw: String) -> ScanResult? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}") else { return nil }
        let jsonStr = String(raw[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              d["global"] != nil else { return nil }

        let g = d["global"] as? [String: Any] ?? [:]
        let rawSkills = g["skills"] as? [[String: Any]] ?? []
        let rawMcpDetails = g["mcp_details"] as? [String: [String: Any]] ?? [:]
        let rawProjects = d["projects"] as? [[String: Any]] ?? []
        let rawSessions = d["active_sessions"] as? [[String: Any]] ?? []
        let rawPorts = d["ports"] as? [[String: Any]] ?? []

        let global = GlobalSetup(
            claudeMdLines: g["claude_md"] as? Int ?? 0,
            skills: rawSkills.map {
                Skill(name: $0["name"] as? String ?? "",
                      hasSkillMd: $0["has_skill_md"] as? Bool ?? false)
            },
            mcpServers: g["mcp_servers"] as? [String] ?? [],
            mcpDetails: rawMcpDetails.reduce(into: [:]) { result, kv in
                result[kv.key] = MCPDetail(
                    command: kv.value["command"] as? String ?? "",
                    type: kv.value["type"] as? String ?? ""
                )
            },
            hooks: g["hooks"] as? Bool ?? false,
            commands: g["commands"] as? [String] ?? []
        )

        let projects = rawProjects.map { p -> ProjectInfo in
            let last = p["last_session"] as? [String: Any]
            return ProjectInfo(
                id: p["name"] as? String ?? UUID().uuidString,
                name: p["name"] as? String ?? "",
                path: p["path"] as? String ?? "",
                signatures: p["signatures"] as? [String] ?? [],
                claudeMdLines: p["claude_md"] as? Int,
                agentsMdLines: p["agents_md"] as? Int,
                skills: (p["skills"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String },
                mcpServers: p["mcp_servers"] as? [String] ?? [],
                hasLocalMcp: p["has_local_mcp"] as? Bool ?? false,
                sessionCount: p["session_count"] as? Int ?? 0,
                lastSessionTime: last?["time"] as? String,
                lastSessionTopic: last?["topic"] as? String,
                gitRepo: p["git_repo"] as? String,
                gitBranch: p["git_branch"] as? String,
                gitLastCommit: p["git_last_commit"] as? String,
                gitLastTime: p["git_last_time"] as? String,
                gitDirty: p["git_dirty"] as? Bool ?? false
            )
        }

        let sessions = rawSessions.map { s in
            ActiveSession(
                id: "\(s["pid"] as? Int ?? 0)",
                tool: s["tool"] as? String ?? "",
                pid: s["pid"] as? Int ?? 0,
                cwd: s["cwd"] as? String ?? "",
                cmd: s["cmd"] as? String ?? ""
            )
        }

        let ports = rawPorts.map { p in
            ActivePort(
                id: p["port"] as? Int ?? 0,
                port: p["port"] as? Int ?? 0,
                command: p["command"] as? String ?? "",
                pid: p["pid"] as? Int ?? 0,
                cwd: p["cwd"] as? String ?? ""
            )
        }

        return ScanResult(
            global: global,
            projects: projects,
            activeSessions: sessions,
            ports: ports
        )
    }
}

// MARK: - View

struct ScanPanelView: View {
    let scan: ScanResult
    @AppStorage("appLanguage") private var lang = "en"
    @Environment(\.colorScheme) private var scheme
    private var l: L { L(lang) }
    private var colors: DxaiColors { DxaiColors(scheme: scheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                summaryHeader.padding(.bottom, 12)
                Divider()
                globalSection.padding(.vertical, 10)

                if !scan.activeSessions.isEmpty {
                    Divider()
                    activeSessionsSection.padding(.vertical, 10)
                }

                if !scan.projects.isEmpty {
                    Divider()
                    projectsSection.padding(.vertical, 10)
                }

                if !scan.ports.isEmpty {
                    Divider()
                    portsSection.padding(.vertical, 10)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(colors.bgChip))
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.purple)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(l.aiEnvironment)
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 10) {
                    summaryChip(icon: "star.fill",
                                text: l.skillChip(scan.global.skills.count),
                                color: colors.accent)
                    summaryChip(icon: "server.rack",
                                text: l.mcpChip(scan.global.mcpServers.count),
                                color: .blue)
                    summaryChip(icon: "folder.fill",
                                text: l.projectChip(scan.projects.count),
                                color: .green)
                }

                HStack(spacing: 10) {
                    summaryChip(icon: "terminal",
                                text: l.sessionChip(scan.activeSessions.count),
                                color: .orange)
                    summaryChip(icon: "network",
                                text: l.portChip(scan.ports.count),
                                color: .cyan)
                    if scan.global.hooks {
                        summaryChip(icon: "link", text: "Hook", color: .purple)
                    }
                }
            }
            Spacer()
        }
    }

    private func summaryChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12))
        .foregroundColor(color)
    }

    // MARK: - Global Setup

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.globalSetup)

            // CLAUDE.md
            if scan.global.claudeMdLines > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.purple.opacity(colors.textCaption))
                        .frame(width: 16)
                    Text("CLAUDE.md")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                    Text(l.globalDirectives)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(colors.textSub))
                    Spacer()
                    Text(l.nLines(scan.global.claudeMdLines))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            // Skills
            if !scan.global.skills.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(colors.accent)
                            .frame(width: 16)
                        Text(l.skills)
                            .font(.system(size: 13, weight: .medium))
                        Text(l.slashExtensions)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(colors.textSub))
                        Spacer()
                        Text(l.nItems(scan.global.skills.count))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    skillTags(scan.global.skills)
                }
            }

            // MCP Servers
            if !scan.global.mcpServers.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text(l.mcpServers)
                            .font(.system(size: 13, weight: .medium))
                        Text(l.externalTools)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(colors.textSub))
                        Spacer()
                        Text(l.nItems(scan.global.mcpServers.count))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    mcpTags(scan.global.mcpServers)
                }
            }

            // Commands
            if !scan.global.commands.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "command")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .frame(width: 16)
                        Text(l.customCommands)
                            .font(.system(size: 13, weight: .medium))
                        Text(l.automationCmds)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(colors.textSub))
                        Spacer()
                        Text(l.nItems(scan.global.commands.count))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    commandTags(scan.global.commands)
                }
            }
        }
    }

    // MARK: - Tags

    private func skillTags(_ skills: [ScanResult.Skill]) -> some View {
        FlowLayout(spacing: 5) {
            ForEach(skills, id: \.name) { skill in
                HStack(spacing: 3) {
                    if skill.hasSkillMd {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                    }
                    Text(skill.name)
                }
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(colors.accent.opacity(colors.bgSubtle))
                .foregroundColor(colors.accentText)
                .cornerRadius(4)
            }
        }
        .padding(.leading, 24)
    }

    private func mcpTags(_ servers: [String]) -> some View {
        FlowLayout(spacing: 5) {
            ForEach(servers, id: \.self) { server in
                Text(server)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(colors.bgSubtle))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.leading, 24)
    }

    private func commandTags(_ commands: [String]) -> some View {
        FlowLayout(spacing: 5) {
            ForEach(commands, id: \.self) { cmd in
                Text("/\(cmd)")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(colors.bgSubtle))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
        }
        .padding(.leading, 24)
    }

    // MARK: - Active Sessions

    private var activeSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l.activeSessions)

            ForEach(scan.activeSessions) { session in
                HStack(spacing: 8) {
                    Text(session.tool.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(sessionColor(session.tool).opacity(colors.bgCard))
                        .foregroundColor(sessionColor(session.tool))
                        .cornerRadius(4)

                    Text(projectName(session.cwd))
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    Text("PID \(session.pid)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary.opacity(colors.textSub))
                }
            }
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l.aiProjects(scan.projects.count))

            ForEach(scan.projects.prefix(10)) { project in
                VStack(alignment: .leading, spacing: 4) {
                    // Row 1: name + repo
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green.opacity(0.7))
                            .frame(width: 14)

                        Text(project.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        if let repo = project.gitRepo {
                            Text(repo)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary.opacity(colors.textSub))
                                .lineLimit(1)
                        }
                    }

                    // Row 2: last commit
                    if let commit = project.gitLastCommit {
                        HStack(spacing: 6) {
                            Text(project.gitLastTime ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(colors.textMuted))
                                .frame(minWidth: 50, alignment: .leading)

                            Text(commit)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(colors.textDim))
                                .lineLimit(1)
                        }
                        .padding(.leading, 20)
                    }

                    // Row 3: 설정파일 + AI badges
                    let badges = projectBadges(project)
                    if !badges.isEmpty {
                        HStack(spacing: 5) {
                            Text(l.configLabel)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(colors.textMuted))
                            ForEach(badges, id: \.text) { badge in
                                HStack(spacing: 3) {
                                    Image(systemName: badge.icon)
                                        .font(.system(size: 9))
                                    Text(badge.text)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(badge.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(badge.color.opacity(colors.bgSubtle))
                                .cornerRadius(3)
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.vertical, 2)
            }

            if scan.projects.count > 10 {
                Text(l.moreProjects(scan.projects.count - 10))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(colors.textMuted))
                    .padding(.leading, 20)
            }
        }
    }

    private struct Badge {
        let icon: String
        let text: String
        let color: Color
    }

    private func projectBadges(_ project: ScanResult.ProjectInfo) -> [Badge] {
        var badges: [Badge] = []

        if let lines = project.claudeMdLines {
            badges.append(Badge(
                icon: "bolt.fill",
                text: "Claude \(l.nLines(lines))",
                color: Color(red: 0.85, green: 0.47, blue: 0.34)
            ))
        }

        if let lines = project.agentsMdLines {
            badges.append(Badge(
                icon: "chevron.left.forwardslash.chevron.right",
                text: "Codex \(l.nLines(lines))",
                color: Color(red: 0.06, green: 0.64, blue: 0.50)
            ))
        }

        if project.hasLocalMcp {
            badges.append(Badge(
                icon: "server.rack",
                text: "MCP \(l.nItems(project.mcpServers.count))",
                color: .blue
            ))
        }

        if !project.skills.isEmpty {
            badges.append(Badge(
                icon: "star.fill",
                text: "\(l.skills) \(l.nItems(project.skills.count))",
                color: colors.accent
            ))
        }

        return badges
    }

    // MARK: - Ports

    private var portsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(l.openPorts)

            ForEach(scan.ports) { port in
                HStack(spacing: 8) {
                    Text(":\(port.port)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .frame(width: 52, alignment: .leading)

                    Text(port.command)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .frame(maxWidth: 80, alignment: .leading)

                    Text(projectName(port.cwd))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary.opacity(colors.textDim))
                        .lineLimit(1)

                    Spacer()

                    Text("PID \(port.pid)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary.opacity(colors.textMuted))
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary.opacity(colors.textDim))
    }

    private func sessionColor(_ tool: String) -> Color {
        switch tool.lowercased() {
        case "claude": return Color(red: 0.85, green: 0.47, blue: 0.34)
        case "codex":  return Color(red: 0.06, green: 0.64, blue: 0.50)
        default:       return .secondary
        }
    }

    private func projectName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

}

// MARK: - FlowLayout (simple wrapping layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
