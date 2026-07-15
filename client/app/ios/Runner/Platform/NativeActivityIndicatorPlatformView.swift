import Flutter
import UIKit

final class NativeActivityIndicatorPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
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
    return NativeActivityIndicatorPlatformView(
      frame: frame,
      color: Self.color(fromARGB: color.int64Value)
    )
  }

  private static func color(fromARGB value: Int64) -> UIColor {
    let argb = UInt32(truncatingIfNeeded: value)
    return UIColor(
      red: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}

final class NativeActivityIndicatorPlatformView: UIView, FlutterPlatformView {
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
    guard diameter > 0 else { return }
    let scale = min(bounds.width, bounds.height) / diameter
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
