import Foundation
import Sparkle
import SwiftUI

final class UpdaterManager: ObservableObject {
    private var controller: SPUStandardUpdaterController?

    @Published var canCheckForUpdates = false
    @Published var isAvailable = false

    init() {
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            return
        }
        let ctrl = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
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

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }
}
