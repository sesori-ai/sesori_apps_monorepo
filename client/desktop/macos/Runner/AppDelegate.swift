import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // The tray owns the app lifecycle after the window is closed. The Flutter
  // window adapter decides whether a close hides the window or performs a
  // coordinated Quit, so macOS must not terminate merely because no window is
  // currently visible.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
