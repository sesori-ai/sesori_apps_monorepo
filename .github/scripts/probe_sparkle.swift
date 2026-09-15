// Compile-only qualification of Sparkle's public API. This is never linked into Sesori.
// A successful typecheck does NOT prove installer/shutdown ordering or signature rejection.
import Cocoa
import Sparkle

final class SparkleQuitProbe: NSObject, SPUUpdaterDelegate {
    private var preparedRestart: (() -> Void)?

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        preparedRestart = immediateInstallHandler
        return true
    }

    func explicitRestartAfterHelperStop() {
        preparedRestart?()
    }

    func makeController() -> SPUStandardUpdaterController {
        SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }
}
