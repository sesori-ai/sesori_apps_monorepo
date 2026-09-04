import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterProject = FlutterDartProject()
    // Pass the native process arguments through explicitly so LaunchAgent
    // startup reaches Dart with --hidden on macOS as it does on other hosts.
    flutterProject.dartEntrypointArguments = Array(CommandLine.arguments.dropFirst())
    let flutterViewController = FlutterViewController(project: flutterProject)
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacOsLegacyKeychainPlugin.register(binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  // MainMenu.xib orders the Flutter window before Dart can restore persisted
  // bounds. Hide that first native ordering for every launch; window_manager's
  // configured guard applies this only once, so FlutterWindowHost can perform
  // the first visible show after restoration (or remain hidden for --hidden).
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
