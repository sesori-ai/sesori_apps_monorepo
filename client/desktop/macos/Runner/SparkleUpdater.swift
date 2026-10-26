import Cocoa
import FlutterMacOS
import Sparkle

/// Sparkle behind `sesori/sparkle`. Dart supplies the feed and the automatic
/// check toggle; downloads stay silent (`SUAutomaticallyUpdate`) and a
/// downloaded update installs when the app quits, or at once with a relaunch
/// through `installAndRelaunch`.
final class SparkleUpdater: NSObject, SPUUpdaterDelegate {
  static let shared = SparkleUpdater()

  private var channel: FlutterMethodChannel?
  private var updater: SPUUpdater?
  private var feedURL: String?
  private var installNow: (() -> Void)?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sesori/sparkle", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    self.channel = channel
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "start":
      guard let feedURL = arguments?["feedUrl"] as? String,
            let automaticChecks = arguments?["automaticChecks"] as? Bool else {
        result(FlutterError(code: "invalid-arguments", message: "start needs feedUrl and automaticChecks", details: nil))
        return
      }
      start(feedURL: feedURL, automaticChecks: automaticChecks, result: result)
    case "setAutomaticChecks":
      guard let enabled = arguments?["enabled"] as? Bool else {
        result(FlutterError(code: "invalid-arguments", message: "setAutomaticChecks needs enabled", details: nil))
        return
      }
      updater?.automaticallyChecksForUpdates = enabled
      result(nil)
    case "checkNow":
      updater?.checkForUpdatesInBackground()
      result(nil)
    case "installAndRelaunch":
      guard let installNow else {
        result(FlutterError(code: "no-update", message: "No downloaded update to install", details: nil))
        return
      }
      // Sparkle asks the app to quit; Dart terminates once its exit work is done.
      ApplicationTermination.shared.beginQuit()
      installNow()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(feedURL: String, automaticChecks: Bool, result: FlutterResult) {
    self.feedURL = feedURL
    let bundle = Bundle.main
    let updater = SPUUpdater(
      hostBundle: bundle,
      applicationBundle: bundle,
      userDriver: SPUStandardUserDriver(hostBundle: bundle, delegate: nil),
      delegate: self
    )
    updater.automaticallyChecksForUpdates = automaticChecks
    do {
      try updater.start()
      self.updater = updater
      result(nil)
    } catch {
      result(FlutterError(code: "start-failed", message: error.localizedDescription, details: "\(error)"))
    }
  }

  func feedURLString(for updater: SPUUpdater) -> String? {
    return feedURL
  }

  func updater(
    _ updater: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    installNow = immediateInstallHandler
    channel?.invokeMethod("updateDownloaded", arguments: item.displayVersionString)
    return true
  }
}
