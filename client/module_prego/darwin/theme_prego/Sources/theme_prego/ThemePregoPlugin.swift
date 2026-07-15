import Foundation

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import AppKit
  import FlutterMacOS
#else
  #error("Unsupported Darwin platform")
#endif

public final class ThemePregoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeActivityIndicatorPlatformViewFactory(),
      withId: NativeActivityIndicatorPlatformViewFactory.viewType
    )
  }
}

private final class NativeActivityIndicatorPlatformViewFactory: NSObject,
  FlutterPlatformViewFactory
{
  static let viewType = "sesori/native-activity-indicator"

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  #if os(iOS)
    func create(
      withFrame frame: CGRect,
      viewIdentifier viewId: Int64,
      arguments args: Any?
    ) -> FlutterPlatformView {
      guard let color = args as? NSNumber else {
        preconditionFailure("Invalid native activity indicator creation arguments")
      }
      return NativeActivityIndicatorPlatformView(
        frame: frame,
        color: Self.nativeColor(fromARGB: color.int64Value)
      )
    }

    private static func nativeColor(fromARGB value: Int64) -> UIColor {
      let components = colorComponents(fromARGB: value)
      return UIColor(
        red: components.red,
        green: components.green,
        blue: components.blue,
        alpha: components.alpha
      )
    }
  #elseif os(macOS)
    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      guard let color = args as? NSNumber else {
        preconditionFailure("Invalid native activity indicator creation arguments")
      }
      return NativeActivityIndicatorPlatformView(
        frame: .zero,
        color: Self.nativeColor(fromARGB: color.int64Value)
      )
    }

    private static func nativeColor(fromARGB value: Int64) -> NSColor {
      let components = colorComponents(fromARGB: value)
      return NSColor(
        srgbRed: components.red,
        green: components.green,
        blue: components.blue,
        alpha: components.alpha
      )
    }
  #endif

  private static func colorComponents(fromARGB value: Int64) -> ColorComponents {
    let argb = UInt32(truncatingIfNeeded: value)
    return ColorComponents(
      red: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}

private struct ColorComponents {
  let red: CGFloat
  let green: CGFloat
  let blue: CGFloat
  let alpha: CGFloat
}

#if os(iOS)
  private final class NativeActivityIndicatorPlatformView: UIView, FlutterPlatformView {
    private let indicator = UIActivityIndicatorView(style: .medium)

    init(frame: CGRect, color: UIColor) {
      super.init(frame: frame)

      isAccessibilityElement = false
      accessibilityElementsHidden = true
      indicator.color = color
      indicator.hidesWhenStopped = false
      indicator.translatesAutoresizingMaskIntoConstraints = false
      addSubview(indicator)
      NSLayoutConstraint.activate([
        indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
        indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
      ])

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(reduceMotionStatusDidChange),
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
      updateAnimationState()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NotificationCenter.default.removeObserver(
        self,
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
    }

    func view() -> UIView {
      self
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      let diameter = indicator.intrinsicContentSize.width
      let minDimension = min(bounds.width, bounds.height)
      guard diameter > 0, minDimension > 0 else { return }
      let scale = minDimension / diameter
      indicator.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      updateAnimationState()
    }

    @objc private func reduceMotionStatusDidChange() {
      updateAnimationState()
    }

    private func updateAnimationState() {
      if window != nil && !UIAccessibility.isReduceMotionEnabled {
        indicator.startAnimating()
      } else {
        indicator.stopAnimating()
      }
    }
  }
#elseif os(macOS)
  private final class NativeActivityIndicatorPlatformView: NSProgressIndicator {
    private let indicatorColor: NSColor

    init(frame: NSRect, color: NSColor) {
      indicatorColor = color
      super.init(frame: frame)

      isIndeterminate = true
      style = .spinning
      controlSize = .small
      isDisplayedWhenStopped = true
      setAccessibilityElement(false)

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(reduceMotionStatusDidChange),
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
      updateAnimationState()
    }

    // AppKit has no spinner tint API; draw-pass compositing avoids layer filters
    // that distort Flutter platform-view geometry.
    override func draw(_ dirtyRect: NSRect) {
      super.draw(dirtyRect)
      indicatorColor.setFill()
      dirtyRect.fill(using: .sourceAtop)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NotificationCenter.default.removeObserver(
        self,
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateAnimationState()
    }

    @objc private func reduceMotionStatusDidChange() {
      updateAnimationState()
    }

    private func updateAnimationState() {
      if window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        startAnimation(nil)
      } else {
        stopAnimation(nil)
      }
    }
  }
#endif
