import Cocoa
import FlutterMacOS
import Sparkle

/// Sparkle behind `sesori/sparkle`. Dart supplies the feed and the automatic
/// check toggle; downloads stay silent (`SUAutomaticallyUpdate`) and a
/// downloaded update installs when the app quits, or at once with a relaunch
/// through `installAndRelaunch`. The app menu gets "Check for Updates…", which
/// reports its result in an alert window and becomes "Restart to Update" once
/// an update has downloaded; restarting goes back to Dart, which owns every exit.
final class SparkleUpdater: NSObject, SPUUpdaterDelegate, NSMenuItemValidation {
  static let shared = SparkleUpdater()

  private enum CheckOutcome {
    case upToDate
    case downloaded(SUAppcastItem)
    case failed(Error)
  }

  private var channel: FlutterMethodChannel?
  private var updater: SPUUpdater?
  private var feedURL: String?
  private var showsBuildNumber = false
  private var downloadedItem: SUAppcastItem?
  private var installNow: (() -> Void)?
  private var checkCompletions: [(CheckOutcome) -> Void] = []
  private var menuItem: NSMenuItem?
  private var menuCheckRunning = false

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
            let automaticChecks = arguments?["automaticChecks"] as? Bool,
            let showsBuildNumber = arguments?["showsBuildNumber"] as? Bool else {
        result(FlutterError(code: "invalid-arguments", message: "start needs feedUrl, automaticChecks and showsBuildNumber", details: nil))
        return
      }
      self.showsBuildNumber = showsBuildNumber
      start(feedURL: feedURL, automaticChecks: automaticChecks, result: result)
    case "setAutomaticChecks":
      guard let enabled = arguments?["enabled"] as? Bool else {
        result(FlutterError(code: "invalid-arguments", message: "setAutomaticChecks needs enabled", details: nil))
        return
      }
      updater?.automaticallyChecksForUpdates = enabled
      result(nil)
    case "checkNow":
      check { outcome in
        switch outcome {
        case .upToDate, .downloaded:
          result(nil)
        case .failed(let error):
          result(FlutterError(code: "check-failed", message: error.localizedDescription, details: "\(error)"))
        }
      }
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
      installMenuItem()
      result(nil)
    } catch {
      result(FlutterError(code: "start-failed", message: error.localizedDescription, details: "\(error)"))
    }
  }

  /// Runs one background check, or joins the update cycle already running,
  /// and reports how it ended. A downloaded update keeps Sparkle's session
  /// open until it installs, so checks after it report that update at once.
  private func check(completion: @escaping (CheckOutcome) -> Void) {
    guard let updater else {
      completion(.failed(NSError(domain: "com.sesori.desktop.updates", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "The updater has not started.",
      ])))
      return
    }
    if let downloadedItem {
      completion(.downloaded(downloadedItem))
      return
    }
    checkCompletions.append(completion)
    if !updater.sessionInProgress {
      updater.checkForUpdatesInBackground()
    }
  }

  private func installMenuItem() {
    // The first main-menu item is the app menu; the new item goes right under "About Sesori".
    guard menuItem == nil, let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
    let item = NSMenuItem(title: "Check for Updates…", action: #selector(menuItemSelected), keyEquivalent: "")
    item.target = self
    appMenu.insertItem(item, at: min(1, appMenu.numberOfItems))
    menuItem = item
  }

  @objc private func menuItemSelected() {
    if downloadedItem != nil {
      channel?.invokeMethod("restartRequested", arguments: nil)
      return
    }
    menuCheckRunning = true
    check { [weak self] outcome in
      self?.menuCheckRunning = false
      self?.showResult(outcome: outcome)
    }
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    return menuItem !== self.menuItem || !menuCheckRunning
  }

  /// The menu closes before the check ends, so its result gets its own window.
  private func showResult(outcome: CheckOutcome) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    switch outcome {
    case .upToDate:
      let info = Bundle.main.infoDictionary
      let version = versionLabel(
        version: info?["CFBundleShortVersionString"] as? String ?? "",
        build: info?["CFBundleVersion"] as? String ?? ""
      )
      alert.messageText = "You're up to date"
      alert.informativeText = "Sesori \(version) is the newest version."
      alert.runModal()
    case .downloaded(let item):
      alert.messageText = "An update is ready"
      alert.informativeText = "Sesori \(versionLabel(version: item.displayVersionString, build: item.versionString)) has downloaded. It installs the next time Sesori restarts."
      alert.addButton(withTitle: "Restart Now")
      alert.addButton(withTitle: "Later")
      if alert.runModal() == .alertFirstButtonReturn {
        channel?.invokeMethod("restartRequested", arguments: nil)
      }
    case .failed(let error):
      alert.alertStyle = .warning
      alert.messageText = "Couldn't check for updates"
      alert.informativeText = error.localizedDescription
      alert.runModal()
    }
  }

  /// Internal builds share the product version, so only they name the build.
  private func versionLabel(version: String, build: String) -> String {
    return showsBuildNumber ? "\(version) (build \(build))" : version
  }

  func feedURLString(for updater: SPUUpdater) -> String? {
    return feedURL
  }

  func updater(
    _ updater: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    downloadedItem = item
    installNow = immediateInstallHandler
    menuItem?.title = "Restart to Update"
    channel?.invokeMethod("updateDownloaded", arguments: [
      "version": item.displayVersionString,
      "build": item.versionString,
    ])
    // Returning true keeps the update cycle open, so it never reaches
    // didFinishUpdateCycleFor; the waiting checks end here.
    completeChecks(outcome: .downloaded(item))
    return true
  }

  func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
    if let error = error as NSError?,
       !(error.domain == SUSparkleErrorDomain && error.code == Int(SUError.noUpdateError.rawValue)) {
      completeChecks(outcome: .failed(error))
    } else {
      completeChecks(outcome: .upToDate)
    }
  }

  private func completeChecks(outcome: CheckOutcome) {
    let completions = checkCompletions
    checkCompletions = []
    completions.forEach { $0(outcome) }
  }
}
