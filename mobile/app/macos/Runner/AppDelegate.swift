import Cocoa
import FlutterMacOS
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    // Register the URL scheme event handler early — before plugins are loaded
    // in MainFlutterWindow.awakeFromNib(). Without this, app_links never
    // receives custom-scheme callbacks because handleWillFinishLaunching
    // fires before plugin registration.
    AppLinks.shared.handleWillFinishLaunching(notification)
    super.applicationWillFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
