import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Longest edge (px) kept when re-encoding a pasted clipboard image, mirroring the picker.
  private static let maxImageEdge: CGFloat = 2048

  /// Retained so the channel outlives `awakeFromNib`; otherwise it is deallocated.
  private var clipboardChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 400, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerClipboardChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func registerClipboardChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "sesori/clipboard",
      binaryMessenger: controller.engine.binaryMessenger
    )
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
  /// clipboard holds no image.
  private func readClipboardImage() -> [String: Any]? {
    guard let image = NSImage(pasteboard: NSPasteboard.general) else { return nil }
    guard let data = MainFlutterWindow.jpegData(from: image, maxEdge: MainFlutterWindow.maxImageEdge) else {
      return nil
    }
    return [
      "bytes": FlutterStandardTypedData(bytes: data),
      "mimeType": "image/jpeg",
      "filename": "clipboard.jpg",
    ]
  }

  /// Downscales [image] to at most [maxEdge] *pixels* on its longest side and
  /// JPEG-encodes it. Renders into an explicit-pixel bitmap (rather than
  /// `lockFocus`, which allocates a backing store at the screen's scale factor)
  /// so the output is the true pixel size on Retina displays too.
  private static func jpegData(from image: NSImage, maxEdge: CGFloat) -> Data? {
    let pixelWidth: CGFloat
    let pixelHeight: CGFloat
    if let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
      pixelWidth = CGFloat(rep.pixelsWide)
      pixelHeight = CGFloat(rep.pixelsHigh)
    } else {
      pixelWidth = image.size.width
      pixelHeight = image.size.height
    }
    guard pixelWidth > 0, pixelHeight > 0 else { return nil }

    let longest = max(pixelWidth, pixelHeight)
    let scale = longest > maxEdge ? maxEdge / longest : 1
    let targetWidth = Int((pixelWidth * scale).rounded())
    let targetHeight = Int((pixelHeight * scale).rounded())
    guard targetWidth > 0, targetHeight > 0 else { return nil }

    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: targetWidth,
      pixelsHigh: targetHeight,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: targetWidth, height: targetHeight)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
      NSGraphicsContext.restoreGraphicsState()
      return nil
    }
    NSGraphicsContext.current = context
    image.draw(
      in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
      from: .zero,
      operation: .copy,
      fraction: 1.0
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
  }
}
