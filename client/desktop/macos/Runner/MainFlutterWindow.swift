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

    // The sidebar panel runs to the window's top edge (the Dart side hides the
    // title bar). An empty unified toolbar makes AppKit itself set the traffic
    // lights lower and further in, onto that panel; window_manager cannot move them.
    let toolbar = NSToolbar()
    self.toolbar = toolbar
    self.toolbarStyle = .unified
    self.titlebarSeparatorStyle = .none
    // In full screen AppKit hides the lights and draws the toolbar as an opaque
    // bar over the content's top, so it steps aside until the window is back.
    let center = NotificationCenter.default
    center.addObserver(forName: NSWindow.willEnterFullScreenNotification, object: self, queue: .main) { _ in
      toolbar.isVisible = false
    }
    center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main) { _ in
      toolbar.isVisible = true
    }

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
