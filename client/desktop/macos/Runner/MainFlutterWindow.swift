import Cocoa
import FlutterMacOS

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
}
