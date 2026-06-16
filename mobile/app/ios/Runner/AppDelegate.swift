import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Longest edge (px) kept when re-encoding a pasted clipboard image. Mirrors
  /// the gallery/camera picker so the base64 payload sent over the relay stays small.
  private static let maxImageEdge: CGFloat = 2048

  /// Retained so the channel outlives this method; otherwise it is deallocated.
  private var clipboardChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerClipboardChannel(engineBridge)
  }

  private func registerClipboardChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SesoriClipboard") else { return }
    let channel = FlutterMethodChannel(name: "sesori/clipboard", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "readImage":
        result(self?.readClipboardImage())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    clipboardChannel = channel
  }

  /// Returns the clipboard image re-encoded as downscaled JPEG, or `nil` when the
  /// clipboard holds no image. Reading `hasImages` does not trigger the iOS paste
  /// banner; only reading the actual image content does (which we do solely when
  /// an image is present), matching the user's intent to paste.
  private func readClipboardImage() -> [String: Any]? {
    let pasteboard = UIPasteboard.general
    guard pasteboard.hasImages, let image = pasteboard.image else { return nil }
    let resized = AppDelegate.downscaled(image, maxEdge: AppDelegate.maxImageEdge)
    guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
    return [
      "bytes": FlutterStandardTypedData(bytes: data),
      "mimeType": "image/jpeg",
      "filename": "clipboard.jpg",
    ]
  }

  private static func downscaled(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
    let size = image.size
    let longest = max(size.width, size.height)
    guard longest > maxEdge, longest > 0 else { return image }
    let scale = maxEdge / longest
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: newSize))
    }
  }
}
