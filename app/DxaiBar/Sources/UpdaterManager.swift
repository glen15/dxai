import Foundation
import Sparkle
import SwiftUI

final class UpdaterManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?

    @Published var canCheckForUpdates = false
    @Published var isAvailable = false

    // 수동 silent 체크용 상태. 자동 백그라운드 체크와 간섭되지 않도록 플래그로 구분.
    private var pendingSilentCheck = false
    private var onNoUpdate: (() -> Void)?

    override init() {
        super.init()
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            return
        }
        let ctrl = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        controller = ctrl
        isAvailable = true
        ctrl.updater.automaticallyChecksForUpdates = true
        ctrl.updater.automaticallyDownloadsUpdates = true
        ctrl.updater.updateCheckInterval = 3600 // 1시간마다 체크
        ctrl.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    /// 조용히 업데이트 여부 체크 → 있으면 Sparkle UI로 유저에게 확인받고, 없으면 onNoUpdate() 실행.
    /// "최신화" 버튼처럼 평소엔 앱 재시작만 하되 새 버전이 있으면 즉시 업데이트 다이얼로그를 띄우는 용도.
    func checkForUpdatesOrRun(onNoUpdate: @escaping () -> Void) {
        guard let controller = controller else {
            onNoUpdate()
            return
        }
        self.onNoUpdate = onNoUpdate
        pendingSilentCheck = true
        controller.updater.checkForUpdateInformation()
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard pendingSilentCheck else { return }
        pendingSilentCheck = false
        onNoUpdate = nil
        // 업데이트 발견 → UI 포함 체크로 유저에게 확인 다이얼로그 표시
        controller?.checkForUpdates(nil)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        guard pendingSilentCheck else { return }
        pendingSilentCheck = false
        let callback = onNoUpdate
        onNoUpdate = nil
        callback?()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        guard pendingSilentCheck else { return }
        pendingSilentCheck = false
        let callback = onNoUpdate
        onNoUpdate = nil
        // 네트워크/피드 에러 시 업데이트 체크 생략하고 재시작 계속
        callback?()
    }
}
