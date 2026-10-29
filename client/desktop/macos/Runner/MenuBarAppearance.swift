import Cocoa
import FlutterMacOS

/// Streams whether the menu bar behind Sesori's status item is dark over
/// `sesori/menu_bar_appearance`, so Dart can show a white or black tray mark.
///
/// The menu bar can be dark while the system is in light mode (it follows the
/// wallpaper), so this observes the status button's own appearance. Dart
/// passes the `NSStatusItem` address nativeapi's `TrayIcon.nativeObject` gives.
final class MenuBarAppearance: NSObject, FlutterStreamHandler {
  static let shared = MenuBarAppearance()

  private var channel: FlutterEventChannel?
  private var observation: NSKeyValueObservation?
  private var readScheduled = false
  private var reportedDark: Bool?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterEventChannel(name: "sesori/menu_bar_appearance", binaryMessenger: messenger)
    channel.setStreamHandler(self)
    self.channel = channel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard let address = arguments as? Int, let pointer = UnsafeRawPointer(bitPattern: address) else {
      return FlutterError(code: "invalid_status_item", message: "Expected an NSStatusItem address", details: nil)
    }
    let statusItem = Unmanaged<NSStatusItem>.fromOpaque(pointer).takeUnretainedValue()
    guard let button = statusItem.button else {
      return FlutterError(code: "invalid_status_item", message: "The status item has no button", details: nil)
    }
    reportedDark = nil
    // AppKit flips the button's appearance back and forth while it draws, so
    // each burst of changes is read once, after it settles.
    observation = button.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] button, _ in
      guard let self, !self.readScheduled else { return }
      self.readScheduled = true
      DispatchQueue.main.async { [weak self, weak button] in
        guard let self else { return }
        self.readScheduled = false
        guard let button, self.observation != nil else { return }
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if isDark != self.reportedDark {
          self.reportedDark = isDark
          events(isDark)
        }
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    observation?.invalidate()
    observation = nil
    return nil
  }
}
