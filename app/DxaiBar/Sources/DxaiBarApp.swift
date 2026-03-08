import SwiftUI
import AppKit
import ServiceManagement

@main
struct DxaiBarApp: App {
    @StateObject private var viewModel = DxaiViewModel()

    init() {
        // 첫 실행 시 자동시작 등록
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.dxai.DxaiBar"
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        )
        if running.count > 1 {
            exit(0)
        }

        // swift run 환경 (번들 없음): 프로세스 이름으로 중복 체크
        if Bundle.main.bundleIdentifier == nil {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let all = NSWorkspace.shared.runningApplications
            let dupes = all.filter {
                $0.localizedName == "DxaiBar" && $0.processIdentifier != myPID
            }
            if !dupes.isEmpty {
                exit(0)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            DxaiMenuView(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text(viewModel.menuBarLabel)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
