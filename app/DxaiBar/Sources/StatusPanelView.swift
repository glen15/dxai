import SwiftUI

// MARK: - Model

struct SystemStatus {
    let model: String
    let cpuModel: String
    let totalRAM: String
    let diskSize: String
    let osVersion: String
    let refreshRate: String
    let uptime: String
    let processCount: Int

    let healthScore: Int
    let healthMessage: String

    let cpuUsage: Double
    let coreCount: Int
    let pCoreCount: Int
    let eCoreCount: Int
    let perCore: [Double]

    let memUsed: Int64
    let memTotal: Int64
    let memPercent: Double
    let swapUsed: Int64
    let swapTotal: Int64

    let diskUsed: Int64
    let diskTotal: Int64
    let diskPercent: Double

    let batteryPercent: Int
    let batteryStatus: String
    let batteryCycles: Int

    let cpuTemp: Double
    let systemPower: Double

    let networks: [NetworkInterface]
    let topProcesses: [TopProcess]

    struct NetworkInterface: Identifiable {
        let id: String
        let name: String
        let ip: String
        let rxRate: Double
        let txRate: Double
    }

    struct TopProcess {
        let name: String
        let cpu: Double
        let memory: Double
    }

    static func parse(from raw: String) -> SystemStatus? {
        // Find JSON object in output (shell login may prepend text)
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}") else { return nil }
        let jsonStr = String(raw[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              d["health_score"] != nil else {
            return nil
        }

        let hw = d["hardware"] as? [String: Any] ?? [:]
        let cpu = d["cpu"] as? [String: Any] ?? [:]
        let mem = d["memory"] as? [String: Any] ?? [:]
        let disks = d["disks"] as? [[String: Any]] ?? []
        let batteries = d["batteries"] as? [[String: Any]] ?? []
        let thermal = d["thermal"] as? [String: Any] ?? [:]
        let nets = d["network"] as? [[String: Any]] ?? []
        let procs = d["top_processes"] as? [[String: Any]] ?? []

        let disk = disks.first ?? [:]
        let bat = batteries.first

        return SystemStatus(
            model: hw["model"] as? String ?? "Mac",
            cpuModel: hw["cpu_model"] as? String ?? "",
            totalRAM: hw["total_ram"] as? String ?? "",
            diskSize: hw["disk_size"] as? String ?? "",
            osVersion: hw["os_version"] as? String ?? "",
            refreshRate: hw["refresh_rate"] as? String ?? "",
            uptime: d["uptime"] as? String ?? "",
            processCount: d["procs"] as? Int ?? 0,
            healthScore: d["health_score"] as? Int ?? 0,
            healthMessage: d["health_score_msg"] as? String ?? "",
            cpuUsage: cpu["usage"] as? Double ?? 0,
            coreCount: cpu["core_count"] as? Int ?? 0,
            pCoreCount: cpu["p_core_count"] as? Int ?? 0,
            eCoreCount: cpu["e_core_count"] as? Int ?? 0,
            perCore: cpu["per_core"] as? [Double] ?? [],
            memUsed: int64(mem["used"]),
            memTotal: int64(mem["total"]),
            memPercent: mem["used_percent"] as? Double ?? 0,
            swapUsed: int64(mem["swap_used"]),
            swapTotal: int64(mem["swap_total"]),
            diskUsed: int64(disk["used"]),
            diskTotal: int64(disk["total"]),
            diskPercent: disk["used_percent"] as? Double ?? 0,
            batteryPercent: bat?["percent"] as? Int ?? -1,
            batteryStatus: bat?["status"] as? String ?? "",
            batteryCycles: bat?["cycle_count"] as? Int ?? 0,
            cpuTemp: thermal["cpu_temp"] as? Double ?? 0,
            systemPower: thermal["system_power"] as? Double ?? 0,
            networks: nets.compactMap { n in
                let ip = n["ip"] as? String ?? ""
                guard !ip.isEmpty else { return nil }
                return NetworkInterface(
                    id: n["name"] as? String ?? UUID().uuidString,
                    name: n["name"] as? String ?? "",
                    ip: ip,
                    rxRate: n["rx_rate_mbs"] as? Double ?? 0,
                    txRate: n["tx_rate_mbs"] as? Double ?? 0
                )
            },
            topProcesses: procs.prefix(5).map { p in
                TopProcess(
                    name: p["name"] as? String ?? "",
                    cpu: p["cpu"] as? Double ?? 0,
                    memory: p["memory"] as? Double ?? 0
                )
            }
        )
    }

    private static func int64(_ value: Any?) -> Int64 {
        if let n = value as? Int { return Int64(n) }
        if let n = value as? Int64 { return n }
        if let n = value as? Double { return Int64(n) }
        return 0
    }
}

// MARK: - View

struct StatusPanelView: View {
    let status: SystemStatus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection.padding(.bottom, 12)
                Divider()
                metricsSection.padding(.vertical, 12)

                if !status.networks.isEmpty {
                    Divider()
                    networkSection.padding(.vertical, 10)
                }

                if !status.topProcesses.isEmpty {
                    Divider()
                    processesSection.padding(.vertical, 10)
                }

                Divider()
                footerSection.padding(.top, 8)
            }
            .padding(14)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(healthColor.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(status.healthScore) / 100)
                    .stroke(healthColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(status.healthScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(healthColor)
                    Text(status.healthMessage)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(status.model)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(status.cpuModel) \u{00B7} \(status.osVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    chip(icon: "memorychip", text: status.totalRAM)
                    chip(icon: "internaldrive", text: status.diskSize)
                    if status.cpuTemp > 0 {
                        chip(icon: "thermometer.medium",
                             text: String(format: "%.0f\u{00B0}C", status.cpuTemp))
                    }
                    if status.systemPower > 0 {
                        chip(icon: "bolt.fill",
                             text: String(format: "%.0fW", status.systemPower))
                    }
                }
            }
            Spacer()
        }
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary.opacity(0.7))
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                metricRow(label: "CPU", pct: status.cpuUsage,
                          detail: "\(status.coreCount) cores", color: .blue)
                if !status.perCore.isEmpty { perCoreChart }
            }

            metricRow(label: "MEM", pct: status.memPercent,
                      detail: "\(formatGB(status.memUsed))/\(formatGB(status.memTotal))",
                      color: memoryColor)

            if status.swapUsed > 1_073_741_824 {
                metricRow(label: "SWAP",
                          pct: status.swapTotal > 0
                              ? Double(status.swapUsed) / Double(status.swapTotal) * 100 : 0,
                          detail: "\(formatGB(status.swapUsed))/\(formatGB(status.swapTotal))",
                          color: .orange)
            }

            if status.diskTotal > 0 {
                metricRow(label: "DISK", pct: status.diskPercent,
                          detail: "\(formatGB(status.diskUsed))/\(formatGB(status.diskTotal))",
                          color: .orange)
            }

            if status.batteryPercent >= 0 {
                metricRow(label: "BAT", pct: Double(status.batteryPercent),
                          detail: batteryStatusText, color: batteryColor)
            }
        }
    }

    private var perCoreChart: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 40)

            HStack(spacing: 0) {
                if status.pCoreCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<status.pCoreCount, id: \.self) { i in
                            coreBar(i < status.perCore.count ? status.perCore[i] : 0,
                                    width: 8, color: .blue)
                        }
                    }
                    if status.eCoreCount > 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 1, height: 18)
                            .padding(.horizontal, 4)
                    }
                }

                if status.eCoreCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<status.eCoreCount, id: \.self) { i in
                            let idx = status.pCoreCount + i
                            coreBar(idx < status.perCore.count ? status.perCore[idx] : 0,
                                    width: 6, color: .teal)
                        }
                    }
                }

                if status.pCoreCount == 0 && status.eCoreCount == 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<status.perCore.count, id: \.self) { i in
                            coreBar(status.perCore[i], width: 7, color: .blue)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if status.pCoreCount > 0 {
                        HStack(spacing: 2) {
                            Circle().fill(Color.blue.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text("P")
                        }
                    }
                    if status.eCoreCount > 0 {
                        HStack(spacing: 2) {
                            Circle().fill(Color.teal.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text("E")
                        }
                    }
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            }
        }
    }

    private func coreBar(_ usage: Double, width: CGFloat, color: Color) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color.opacity(0.3 + 0.7 * min(usage, 100) / 100))
                .frame(width: width,
                       height: max(2, 20 * CGFloat(min(usage, 100)) / 100))
        }
        .frame(height: 22)
    }

    private func metricRow(label: String, pct: Double,
                           detail: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 32, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(pct > 0 ? 2 : 0,
                                          geo.size.width * CGFloat(min(pct, 100)) / 100))
                }
            }
            .frame(height: 8)

            Text(String(format: "%.0f%%", pct))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(pct >= 80 ? .red : color)
                .frame(width: 32, alignment: .trailing)

            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 100, alignment: .trailing)
        }
    }

    // MARK: - Network

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NETWORK")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))

            ForEach(status.networks) { net in
                HStack(spacing: 0) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                        .foregroundColor(.blue.opacity(0.7))
                        .frame(width: 16)
                    Text(net.name)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(width: 34, alignment: .leading)
                    Text(net.ip)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 12) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                            Text(formatRate(net.txRate))
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.blue)
                            Text(formatRate(net.rxRate))
                        }
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Top Processes

    private var processesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOP PROCESSES")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))

            let maxCPU = max(status.topProcesses.map(\.cpu).max() ?? 1, 1)

            ForEach(Array(status.topProcesses.enumerated()), id: \.offset) { _, proc in
                HStack(spacing: 8) {
                    Text(proc.name)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .frame(width: 100, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(
                                colors: [.purple.opacity(0.4), .purple.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, geo.size.width * CGFloat(proc.cpu / maxCPU)))
                    }
                    .frame(height: 6)
                    Text(String(format: "%.1f%%", proc.cpu))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text("Up \(status.uptime)")
            }
            Text("\u{00B7}").foregroundColor(.secondary.opacity(0.3))
            HStack(spacing: 4) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 9))
                Text("\(status.processCount) procs")
            }
            if !status.refreshRate.isEmpty {
                Text("\u{00B7}").foregroundColor(.secondary.opacity(0.3))
                Text(status.refreshRate)
            }
            Spacer()
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary.opacity(0.5))
    }

    // MARK: - Helpers

    private var healthColor: Color {
        if status.healthScore >= 80 { return .green }
        if status.healthScore >= 50 { return .yellow }
        if status.healthScore >= 30 { return .orange }
        return .red
    }

    private var memoryColor: Color {
        if status.memPercent >= 85 { return .red }
        if status.memPercent >= 70 { return .yellow }
        return .green
    }

    private var batteryColor: Color {
        if status.batteryPercent >= 50 { return .green }
        if status.batteryPercent >= 20 { return .yellow }
        return .red
    }

    private var batteryStatusText: String {
        var parts: [String] = []
        switch status.batteryStatus.lowercased() {
        case "charged":     parts.append("충전완료")
        case "charging":    parts.append("충전중")
        case "discharging": parts.append("사용중")
        default:            parts.append(status.batteryStatus)
        }
        if status.batteryCycles > 0 {
            parts.append("\(status.batteryCycles)cy")
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func formatGB(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 100 { return String(format: "%.0f", gb) }
        return String(format: "%.1f", gb)
    }

    private func formatRate(_ mbps: Double) -> String {
        if mbps >= 1 { return String(format: "%.1f MB/s", mbps) }
        if mbps >= 0.01 { return String(format: "%.0f KB/s", mbps * 1024) }
        return "0 KB/s"
    }
}
