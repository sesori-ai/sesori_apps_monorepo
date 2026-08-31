import Foundation

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import AppKit
  import CoreImage
  import FlutterMacOS
#endif

public final class ThemePregoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeActivityIndicatorPlatformViewFactory(),
      withId: NativeActivityIndicatorPlatformViewFactory.viewType
    )
  }
}

private struct ColorComponents {
  let red: CGFloat
  let green: CGFloat
  let blue: CGFloat
  let alpha: CGFloat

  init(fromARGB value: Int64) {
    let argb = UInt32(truncatingIfNeeded: value)
    red = CGFloat((argb >> 16) & 0xff) / 255
    green = CGFloat((argb >> 8) & 0xff) / 255
    blue = CGFloat(argb & 0xff) / 255
    alpha = CGFloat((argb >> 24) & 0xff) / 255
  }
}

#if os(iOS)

  private final class NativeActivityIndicatorPlatformViewFactory: NSObject,
    FlutterPlatformViewFactory
  {
    static let viewType = "sesori/native-activity-indicator"

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
      FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
      withFrame frame: CGRect,
      viewIdentifier viewId: Int64,
      arguments args: Any?
    ) -> FlutterPlatformView {
      guard let color = args as? NSNumber else {
        preconditionFailure("Invalid native activity indicator creation arguments")
      }
      let components = ColorComponents(fromARGB: color.int64Value)
      return NativeActivityIndicatorPlatformView(
        frame: frame,
        color: UIColor(
          red: components.red,
          green: components.green,
          blue: components.blue,
          alpha: components.alpha
        )
      )
    }
  }

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

  private final class NativeActivityIndicatorPlatformViewFactory: NSObject,
    FlutterPlatformViewFactory
  {
    static let viewType = "sesori/native-activity-indicator"

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
      FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      guard let color = args as? NSNumber else {
        preconditionFailure("Invalid native activity indicator creation arguments")
      }
      let components = ColorComponents(fromARGB: color.int64Value)
      return NativeActivityIndicatorView(
        color: NSColor(
          red: components.red,
          green: components.green,
          blue: components.blue,
          alpha: components.alpha
        )
      )
    }
  }

  private final class NativeActivityIndicatorView: NSView {
    private let indicator = NSProgressIndicator()

    init(color: NSColor) {
      super.init(frame: .zero)

      // The Flutter wrapper owns the loading-spinner semantics; hide both the
      // container and the native indicator from VoiceOver.
      setAccessibilityElement(false)
      indicator.setAccessibilityElement(false)
      indicator.style = .spinning
      indicator.isIndeterminate = true
      indicator.isDisplayedWhenStopped = true
      indicator.translatesAutoresizingMaskIntoConstraints = false
      // Content filters only apply to a layer-backed view.
      indicator.wantsLayer = true
      // NSProgressIndicator has no tint API; a monochrome content filter
      // recolours the spinner to the requested colour.
      if let filter = CIFilter(name: "CIColorMonochrome"), let ciColor = CIColor(color: color) {
        filter.setValue(ciColor, forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        indicator.contentFilters = [filter]
      }
      addSubview(indicator)
      NSLayoutConstraint.activate([
        indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
        indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
      ])

      NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(accessibilityDisplayOptionsDidChange),
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
      updateAnimationState()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NSWorkspace.shared.notificationCenter.removeObserver(
        self,
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
    }

    override func layout() {
      super.layout()
      let minDimension = min(bounds.width, bounds.height)
      guard minDimension > 0 else { return }
      // A spinning NSProgressIndicator draws at its control size rather than
      // its frame; pick the largest size that fits so small consumers (16px
      // inline rows and buttons) neither clip nor overflow.
      let fitting: NSControl.ControlSize =
        minDimension >= 32 ? .regular : minDimension >= 16 ? .small : .mini
      if indicator.controlSize != fitting {
        indicator.controlSize = fitting
      }
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateAnimationState()
    }

    @objc private func accessibilityDisplayOptionsDidChange() {
      updateAnimationState()
    }

    private func updateAnimationState() {
      if window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        indicator.startAnimation(nil)
      } else {
        indicator.stopAnimation(nil)
      }
    }
  }

#endif
