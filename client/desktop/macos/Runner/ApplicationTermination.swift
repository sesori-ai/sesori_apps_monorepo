import Cocoa
import FlutterMacOS

/// Routes every system quit request (Cmd+Q, the Dock, logout, an updater) to
/// Dart, which stops the bridge helper before it answers on
/// `sesori/termination` with `terminate` or `cancelTermination`.
final class ApplicationTermination {
  static let shared = ApplicationTermination()

  private var channel: FlutterMethodChannel?
  private var terminationApproved = false
  private var replyPending = false
  private var quitRunning = false

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sesori/termination", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "terminate":
        result(nil)
        self.terminationApproved = true
        if self.replyPending {
          self.replyPending = false
          NSApp.reply(toApplicationShouldTerminate: true)
        } else {
          NSApp.terminate(nil)
        }
      case "cancelTermination":
        result(nil)
        self.quitRunning = false
        if self.replyPending {
          self.replyPending = false
          NSApp.reply(toApplicationShouldTerminate: false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// Marks a quit that native code started (a Sparkle relaunch), so the quit
  /// request it causes is declined here; Dart terminates once it is done.
  func beginQuit() {
    quitRunning = true
  }

  func shouldTerminate() -> NSApplication.TerminateReply {
    if terminationApproved {
      return .terminateNow
    }
    guard let channel else {
      return .terminateNow
    }
    // A quit is already running (a second Cmd+Q, Sparkle's relaunch request);
    // it terminates on its own, so this request is declined at once.
    if replyPending || quitRunning {
      return .terminateCancel
    }
    replyPending = true
    quitRunning = true
    channel.invokeMethod("quitRequested", arguments: nil) { [weak self] result in
      // Dart is not listening yet (still starting), so quit as before.
      guard let self, (result as AnyObject?) === FlutterMethodNotImplemented, self.replyPending else { return }
      self.replyPending = false
      self.terminationApproved = true
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
