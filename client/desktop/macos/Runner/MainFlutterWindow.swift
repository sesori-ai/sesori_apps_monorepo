import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  private static let hiddenLaunchArgument = "--hidden"

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

  // MainMenu.xib orders the Flutter window before Dart can apply its hidden
  // startup policy. Use window_manager's native first-order hook so a
  // LaunchAgent startup never flashes the window; normal launches retain the
  // existing visible behavior and are shown by FlutterWindowHost.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    if CommandLine.arguments.dropFirst().contains(Self.hiddenLaunchArgument) {
      hiddenWindowAtLaunch()
    }
  }
}
